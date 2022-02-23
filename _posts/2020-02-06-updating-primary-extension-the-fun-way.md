---
title: "Updating Primary Extensions The Fun Way"
layout: single
date: 2020-02-06T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Unified Communications
  - Cisco
  - SQL
tags:
  - Cisco Callmanager
  - Cisco
  - Cisco UC
  - Call Manager
  - Database
  - Unified Communications
  - Informix
  - SQL
---

## How to Update Primary Extensions the Fun Way

Today's post covers a workaround-turned-update-method for the 'Primary Extension' field in CUCM's End User Page. We were asked to build out a new DN and assign it to the user and although all the pre-work was done, when trying to modify the Primary Extension entry to the new DN, we received an error. The error we hit is shown below.

<!--more-->

<span class="image fit"><img src="{{ "/assets/images/primaryextensionerror1.png" | absolute_url }}" alt="The error that pops up on a single user in CCM End User page." /></span>

This error generated for any kind of change on just this one user account. Whether you modified their primary extension, self service user id, home cluster -- even if you just clicked save -- it would produce this error. Ultimately while troubleshooting THAT issue, we found that the Name Dialing entry on the end user page did not match the user's LastFirst, so there was a mismatch. CUCM didn't like that. We blanked out the Name Dialing entry, saved (SUCCESSFULLY!), and it autopopulated a new, updated, proper LastFirst entry, which fixed our issue trying to edit this end user.

But while looking into workarounds or ways we could fix the Primary Extension configuration through SQL, or AXL (we went with straight CLI based SQL), we stumbled upon an interesting method to accomplish the task of updating the Primary or IPCC extensions on the End User's configuration.

I want to give a huge shout out to my colleagues Mark and Aric, thanks to the hour (or so) we spent on a WebEx together working through this, for Mark's existing SQL and CCM informix DB structure, query syntax knowledge, and more. You both are always very helpful!

Now on to the good stuff!

## Information Gathering 1 - UserID & DNorPattern

SQL Query to dump users with Primary Extension assigned; this only returns instances where the "Primary Extension" has been assigned, if not, return nothing. This can be used to identify if the given userid has a configured Primary Extension or not.

```text
run sql select e.userid, n.dnorpattern from enduser as e, numplan as n, endusernumplanmap as eunpm where (e.pkid = eunpm.fkenduser and eunpm.fknumplan = n.pkid and tkdnusage=1)
```

## Query Output 1

```text
userid dnorpattern
====== =============
kperry +19195785379
```

## Information Gathering 2 - PKID for UserID

```text
run sql select pkid, userid from enduser where userid='kperry'
```

## Query Output 2

```text
pkid userid
==================================== ======
feaea3f1-9d92-d943-bba9-d4d6a160309a kperry
```

## Information Gathering 3 - PKID for DNorPattern

```text
run sql select pkid, dnorpattern from numplan where dnorpattern='47001'
```

## Query Output 3

```text
pkid dnorpattern
==================================== ===========
90542988-16e0-04e8-eb46-0873ce6cade0 47001
```

## Information Gathering 4 - endusernumplanmap dump

```text
run sql select * from endusernumplanmap
```

## Query Output 4

```text
pkid fkenduser fknumplan tkdnusage sortorder
==================================== ==================================== ==================================== ========= =========
4e8c8673-fe16-4184-9605-290650905709 feaea3f1-9d92-d943-bba9-d4d6a160309a 90542988-16e0-04e8-eb46-0873ce6cade0 1 NULL
```

Now that I've dumped out some data, I'm ready to start using it to peform updates through the database.

## Update attempt 1 - Failed

```text
run sql update endusernumplanmap set fknumplan='90542988-16e0-04e8-eb46-0873ce6cade0' where pkid='4e8c8673-fe16-4184-9605-290650905709'
```

After reviewing the [CUCM Data Dictionary](https://www.cisco.com/c/dam/en/us/td/docs/voice_ip_comm/cucm/datadict/10_0_1/datadictionary_1001.pdf) - as pointed out by Mark - the endusernumplanmap table attribute fknumplan, on validation (Update), can not be changed.

## Update attempt 2 - Success - Solution 1

Because we can't update, we will need to delete the existing pkid/mapping, and create a new one. This could be performed by changing the Primary Extension to in the GUI, but since we're in SQL we decided to do it via SQL.

1. Perform deletion against pkid for Primary Extension on specified user;

```text
run sql delete from endusernumplanmap where pkid='4e8c8673-fe16-4184-9605-290650905709'

rows 1
```

```text
run sql select * from endusernumplanmap

No records
```

2. Add a new row with fkenduser,fknumplan,tkdnusage values, add those values. Unique pkid is generated.

```text
run sql insert into endusernumplanmap(fkenduser,fknumplan,tkdnusage) values ('feaea3f1-9d92-d943-bba9-d4d6a160309a','90542988-16e0-04e8-eb46-0873ce6cade0',1)
```

```text
run sql select * from endusernumplanmap

pkid fkenduser fknumplan tkdnusage sortorder
==================================== ==================================== ==================================== ========= =========
9d98d5fd-e468-409e-b04a-4198a485e28d feaea3f1-9d92-d943-bba9-d4d6a160309a 90542988-16e0-04e8-eb46-0873ce6cade0 1 NULL
```

## Solution 2

Another method to do this, without having performed the discovery ahead of time (especially in instances of one-offs or expediency) we can perform the below query, which includes subqueries to grab the pkids for the end user, and dnorpattern from the relevant tables. This requires the following:

1. The DN we desire to have listed as a Primary Extension must be on a device Controlled by the End User profile, and is known.
2. The UserID we desire to modify is known.
3. The current Primary Extension is configured as <None>, if not, run the discovery queries provided above and perform a deletion against the proper pkid within endusernumplanmap.

```text
run sql insert into endusernumplanmap(fknumplan,fkenduser,tkdnusage) values((select pkid from numplan where dnorpattern = '47001'),(select pkid from enduser where userid = 'kperry'),1)
```

Refreshing the End User page in CUCM for the user, in this case, kperry, should now show an updated Primary Extension configured as we specified in SQL. This can also be repeated for IPCC extensions, however, we need to modify the tkdnusage attribute to "2", rather than "1".

This was a fun exercise in understanding where the proper foreign keys are pulled from and correlated, what we can update, and can't, and how to get around that when possible. I hope this has been informative, and encourage you to follow the @ThoughtsNoc Twitter page for post announcements, to suggest future posts or discuss UC topics!
