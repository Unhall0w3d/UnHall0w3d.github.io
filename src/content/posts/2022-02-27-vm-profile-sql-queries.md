---
title: "Voice Mail Profile SQL Queries"
layout: single
classes: wide
date: 2022-02-27T20:30:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - SQL
  - Cisco
  - Unified Communications
tags:
  - Cisco
  - Cisco Unity Connection
  - Reports
  - Unified Communications
  - Database
  - Unity Connection
---

## Another Audit Using SQL

This one's been on the backburner for a bit considering the audit where my queries were developed was fulfilled in late 2011... but hey, better late than never, right? <!--more--> And without further delay let's talk about the audit and what I came up with to get the data I needed. I'm going to be using a post format that I started out using for posts related to SQL queries that breaks it down a bit more, hope it's no trouble.

### Some Background

This all stemmed from a review of Call Detail Records from the cluster in question to determine why we had an abnormal level of calls terminating with cause does NOT "16" (Normal Call Clearing). I was provided a sample of CDRs, appx. 2000 calls from a 1 hour time period where the ORIGIN or DESTINATION "Termination Cause Code" was NOT "16". Many of these ended in a Temp Fail (41) style cause value, but this wasn't always the case. The majority of the bad calls had a common denominator - one or more "Call Forward" options was enabled on a DN (Directory Number) that had an invalid Voice Mail Profile (e.g. "No Voicemail", "< None >"). This is the focus of the queries I wrote up, as the other bad cause codes were handled on a more one-by-one basis due to the nature of those issues.

### What Is Our Mission

To pull a report of all DNs that have AT LEAST one "Call Forward" option enabled while simulatneously having a "Voice Mail Profile" set to "< None >" or "No Voicemail". This will enable us by identifying misconfigured DNs as it relates to Call Forward attempts to invalid Voice Mail Profiles, and also identifying DNs relying on System Default ("< None >") configurations.

## Let's Talk About Preparation

To prepare for the big query that'll get all the data I need, I have to write out some smaller queries. These are mostly probing and finding where data I may need is, and how I can go about relating the data together.

### Identifying the PKID for Voicemail Profiles

Here's where we start. As with many queries we need to start pulling in some key data -- namely PKIDs (Primary Key ID) and FKIDs (Foreign Key ID). The PKIDs can be used as persistent unique identifiers for attribute groupings in our queries, and the FKIDs can help relate data in one table to data held in another.

To verify the PKID for the No Voicemail profile, we run the below query; we are looking or all data within the voicemessagingprofile table.

```text
run sql select * from voicemessagingprofile
```

Fun fact: The "PKID" in this output relates to the foreign key listed for fkvoicemessagingprofile in the numplan table. We'll need this for later.

```text
run sql select * from voicemessagingprofile

pkid name description fkvoicemessagingpilot voicemailboxmask isdefault resettoggle tkreset versionstamp
==================================== ================== =============================== ==================================== ================ ========= =========== ======= ===============================================
00000000-1111-0000-0000-000000000000 NoVoiceMail No Voice Mail 00000000-1111-0000-0000-000000000000 NULL f f 2 0000000000-c7a6c673-7479-46b0-839e-014d3d093963
```

From this query we are able to identify that the "NoVoicemail" Voicemail Profile has the PKID of "00000000-1111-0000-0000-000000000000". We can use this identifier later when seeing which DNs use this Voice Mail Profile. Interestingly, the PKID of this "default" (pre-made, cannot be deleted) Voice Mail Profile is identical across deployments/environments ranging from Cisco Unity Connection 7.x through to 12.x. I have not yet tested this in version 14, but I suspect it to be the case there as well.

For good measure we want to grab the PKID for the "< None >" Voice Mail Profile. I decided to go about it a little differently and instead grabbed a DN I knew had the VMP assigned. What I really needed to see is, from the numplan table (which contains the data on DNs, CSS's, Forwarding, etc.), the Foreign Key "fkvoicemessagingprofile" for DN "dnorpattern" 52066.

The query looks like this:

```text
run sql select dnorpattern, fkvoicemessagingprofile from numplan where dnorpattern='52066'

dnorpattern fkvoicemessagingprofile
=========== =======================
52066 NULL
```

What we're looking for is this return of "NULL". We'll save that for later.

### Who Is Using The Voice Mail Profiles

The second major step here is to get some valid returns when looking for DNs using either the "NULL" or "00000000-1111-0000-0000-000000000000" Voice Mail Profile PKID/FKIDs. Once we get that working we can move on to qualifiers or filtering. The data we need for this is in the "numplan" and "voicemessagingprofile" tables, and we'll need to relate the "fkvoicemessagingprofile" Foreign Key to the "pkid" PKID in the "voicemessagingprofile" Table. Simple, right? The two queries below are identical with the exception of the "fkvoicemessagingprofile" that we match against.

Checking for DNs using "< None >" VMP:

```text
run sql select np.dnorpattern as dn, np.description, vmp.name as vmprofile , vmp.description as vmdescription from numplan as np inner join voicemessagingprofile as vmp on np.fkvoicemessagingprofile=vmp.pkid where fkvoicemessagingprofile is NULL

dn description vmprofile vmdescription
== =========== ========= =============
52067 Jerry Smith - 52067 NULL NULL
```

Checking for DNs using "NoVoiceMail" VMP:

```text
run sql select np.dnorpattern as dn, np.description, vmp.name as vmprofile , vmp.description as vmdescription from numplan as np inner join voicemessagingprofile as vmp on np.fkvoicemessagingprofile=vmp.pkid where fkvoicemessagingprofile='00000000-1111-0000-0000-000000000000'

dn description vmprofile vmdescription
===== ============================================ =========== =============
52063 Morty Smith - 52063 NoVoiceMail No Voice Mail
52064 Rick Sanchez - 52064 NoVoiceMail No Voice Mail
52065 Bird Person - 52065 NoVoiceMail No Voice Mail
```

Great, we're making progress. Now we need to start adding in some qualifiers for the query, as we only want to know which DNs have these Voice Mail Profiles assigned *when a call forward option is enabled*.

### On Discovery

I'll leave this portion a little short, because talking about it would be boring. Suffice it to say that, the way that I figured out what the attributes were called (as they related to the call forwarding options) was by issuing a "run sql select * from numplan where dnorpattern="XXXXX"", where XXXXX was a known DN. I copied this data out to Notepad++ and reviewed the attributes and the data it had to confirm the names for every call forward type. They will appear in the final query. For each Call Forward option we will see either a 'f' (not enabled) or 't' (enabled).

## Let's Get To It Then

As with many of the queries I run, I like to define the attributes I am pulling from the Informix DB to be easier to understand and so that the data can be conveyed to a client, architect, whoever without much/any modification or manipulation of the output. Look, I get paid to get the data, not to make it look pretty (he said sarcastically).

### Tables

- numplan as np
- voicemessagingprofile as vmp

### Attributes

- np.dnorpattern as dn -- Directory Number/Extension
- np.description -- Directory Number/Extension's Description
- np.cfbvoicemailenabled as CFBusyExt -- Call Forward Busy External
- np.cfbintvoicemailenabled as CFBusyInt -- Call Forward Busy Internal
- np.cfnavoicemailenabled as CFNoAnExt --  Call Forward No Answer External
- np.cfnaintvoicemailenabled as CFNoAnInt -- Call Forward No Answer Internal
- np.pffvoicemailenabled as CFNoCovExt -- Call Forward No Coverage External
- np.pffintvoicemailenabled as CFNoCovInt -- Call Forward No Coverage Internal
- np.cfdfvoicemailenabled as CFCTIFail -- Call Forward CTI Failure
- np.cfurvoicemailenabled as CFUnRegExt -- Call Forward Unregistered External
- np.cfurintvoicemailenabled as CFUnRegInt -- Call Forward Unregistered Internal
- vmp.name as VMProfile -- Voice Mail Profile's Name
- vmp.description as VMDescription -- Voice Mail Profile's Description

### Conditions/Qualifiers/Filters

Relate the foreign key "fkvoicemessagingprofile" in "numplan" table to "pkid" in "voicemessagingprofile" table.

- inner join voicemessagingprofile as vmp on np.fkvoicemessagingprofile=vmp.pkid

We only want to pull the data where the Voice Mail Profile is "< None >" or "NoVoiceMail".

- where (fkvoicemessagingprofile is NULL or fkvoicemessagingprofile = '00000000-1111-0000-0000-000000000000')

Trim the output further by only giving data back if AT LEAST one Call Forward option is enabled.

- and (np.cfnavoicemailenabled = 't' or np.cfbvoicemailenabled = 't' or np.cfbintvoicemailenabled = 't' or np.cfnavoicemailenabled = 't' or np.cfnaintvoicemailenabled = 't' or np.pffvoicemailenabled = 't' or np.pffintvoicemailenabled = 't' or np.cfdfvoicemailenabled = 't' or np.cfurvoicemailenabled = 't' or np.cfurintvoicemailenabled = 't')

## I'm Here For The Queries

For my purpose, I don't need to return data for which call forward option is enabled, I only need it as a qualifier for the query. If you want to pull that data too, add in the appropriate attributes you want to pull after the "select" portion and prior to the "inner join" portion.

### How Many Rows Are We Returning

Before I go and run this query I should see how many rows are going to be returned. Do note that this is a sanitized mock-up, depending on your environment and how you have things configured you could have many, many more.

```text
run sql select count(dnorpattern) from numplan as np where (np.fkvoicemessagingprofile='00000000-1111-0000-0000-000000000000' or np.fkvoicemessagingprofile is NULL) and (np.cfnavoicemailenabled = 't' or np.cfbvoicemailenabled = 't' or np.cfbintvoicemailenabled = 't' or np.cfnavoicemailenabled = 't' or np.cfnaintvoicemailenabled = 't' or np.pffvoicemailenabled = 't' or np.pffintvoicemailenabled = 't' or np.cfdfvoicemailenabled = 't' or np.cfurvoicemailenabled = 't' or np.cfurintvoicemailenabled = 't')

(count)
=======
4
```

### Full Send

Now that we know we're only getting 4 returns, we can run the big query. Again, there were *many* hits when ran for the actual audit. Let's give this query a shot.

```text
run sql select np.dnorpattern as dn, np.description, np.cfbvoicemailenabled as CFBusyExt, np.cfbintvoicemailenabled as CFBusyInt, np.cfnavoicemailenabled as CFNoAnExt, np.cfnaintvoicemailenabled as CFNoAnInt, np.pffvoicemailenabled as CFNoCovExt, np.pffintvoicemailenabled as CFNoCovInt, np.cfdfvoicemailenabled as CFCTIFail, np.cfurvoicemailenabled as CFUnRegExt, np.cfurintvoicemailenabled as CFUnRegInt, vmp.name as VMProfile, vmp.description as VMDescription from numplan as np inner join voicemessagingprofile as vmp on np.fkvoicemessagingprofile=vmp.pkid where (np.fkvoicemessagingprofile = '00000000-1111-0000-0000-000000000000' or np.fkvoicemessagingprofile) and (np.cfnavoicemailenabled = 't' or np.cfbvoicemailenabled = 't' or np.cfbintvoicemailenabled = 't' or np.cfnavoicemailenabled = 't' or np.cfnaintvoicemailenabled = 't' or np.pffvoicemailenabled = 't' or np.pffintvoicemailenabled = 't' or np.cfdfvoicemailenabled = 't' or np.cfurvoicemailenabled = 't' or np.cfurintvoicemailenabled = 't')

dn description vmprofile vmdescription
===== ============================================ =========== =============
52063 Morty Smith - 52559 NoVoiceMail No Voice Mail
52064 Rick Sanchez - 52085 NoVoiceMail No Voice Mail
52065 Bird Person - 52065 NoVoiceMail No Voice Mail
52067 Jerry Smith - 52067 NULL NULL
```

Awesome. We've now identified the DNs in the environment that are configured with inconsistent Voicemail/Call Forward configurations and can clean them up!

## We're Here... Now What

The data you get from this query can lead you to cleaning up the configuration and either moving DNs off the system default (if you're the kind of person to dislike default configurations), disabling Call Forward options for users configured with No VoiceMail, or modifying the Voice Mail Profile to the proper one for users that need to keep call forwarding enabled.

Ultimately this audit allowed us to not only update the inconsistent configs, it served as the basis for a project to migrate users away from the "< None >" Voice Mail Profile as there was in fact a desire to not use defaulted configurations.

I hope this is helpful for you, even if it's just an extra report to pull and act on when your environment and workload is quiet, and light. Check out my prior posts for additional useful SQL queries and reports, check out the NOC Thoughts socials and join our Discord!
