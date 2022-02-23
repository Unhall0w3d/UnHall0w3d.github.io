---
title: "Bulk Accept and Relay Config Update SQL"
layout: single
date: 2020-01-27T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Unified Communications
  - Cisco
  - SQL
tags:
  - Cisco Unity Connection
  - Cisco
  - Cisco Unity
  - Cisco UC
  - Database
  - Unified Communications
  - Informix
  - SQL
---
## Update

I've been refreshed by my colleague Mark on the importance of querying for the tables I need, the db structure, and understanding table naming (tbl_globaluser [editable] vs vw_globaluser [viewable]). After a bit of digging, I was able to make the SMTP Proxy Address change work without requiring BAT at all.  I've also included additional command syntax and screenshots.

<!--more-->

<span class="image fit"><img src="{{ "/assets/images/acceptandrelay1.png" | absolute_url }}" alt="Keep Calm and Bulk Update On." /></span>

## Lets Get Started

Cisco... we need to talk. You do a really great job when it comes to providing documentation for Cisco Unified Communication Manager. One-off troubleshooting documents for a variety of issues, operational, administrative, and configuration oriented documentation... heck, we even have the [SQL Data Dictionary](https://developer.cisco.com/docs/axl/#!12-5-cucm-data-dictionary) for the informix DB that CUCM uses. You've done well here. But as we traverse the environment into the land of Unity Connection, you've kind of dropped the ball. 

Cisco does not provide a data dictionary for the Cisco Unity database. In fact, you can't even use the same initial commands to navigate around SQL. In CUCM, we'd use "run sql select X from Y where Z like A", for example. Nope. In CUC we need to "run cuc dbquery unitydirdb.....". That's fine. We can change syntax fairly easily between devices/technologies and it's not much to complain about. What IS worth complaining about is not knowing what data exists within what tables in the database, which are read/write and which are read-only. It would just make things so much easier.

## Updating Message Actions > Accept and Relay SMTP Address

Issue your select command against the desired attribute.

```text
run cuc dbquery unitydirdb select relayaddress from tbl_MessageHandler where relayaddress like '%@yourdomain.com'
```

This returned about 1599 mail addresses, most of which were proper, but some of which were %FirstName%.%LastName%@yourdomain.com. Weird usage of wildcards, I thought, but it did have the addresses we needed to update.

We can visually inspect the Message Actions settings for individual users to confirm the addresses exist there.

## Issue your replace command to update the desired attribute

```text
run cuc dbquery unitydirdb update tbl_MessageHandler set relayaddress=replace(relayaddress,'@yourdomain.com','@yournewdomain.com') where relayaddress like '%@yourdomain.com'
```

We tested in lab, watched the address update in the GUI under the voicemail user options. Cool. This'll work, right? Right. We run it on the target production system. 1599 records updated. Sweet.

## Rerun your initial command to ensure the desired attribute was changed

```text
run cuc dbquery unitydirdb select relayaddress from tbl_MessageHandler where relayaddress like '%@yourdomain.com'
```

This returns no records. Awesome! So as far as the SQL query can see the desired relay addresses were updated. At this point the client mentions 'Some users have an SMTP Proxy address of '%@voice.mail', and that isn't needed. Can we remove them using the same method? Yes. Yes we can.

For this we would need to move on over to the tbl_smtpproxyaddress table in the unitydirdb database. This is where it got tricky, as without knowing what tables are read vs which are read-write, we can end up in a frustrating situation.This required a small lesson in understanding the naming scheme of various tables. vw_globaluser is a viewable, but not editable table. tbl_globaluser is an editable table. "vw" can be looked at as 'viewable', and thus why I could not edit on past attempts.

## Issue query to identify SMTP Proxy Addresses that exist under the given domain.

```text
run cuc dbquery unitydirdb select smtpaddress from tbl_smtpproxyaddress where smtpaddress like '%@testdomai.com'
```

```text
smtpaddress
-----------------------
ken.perry@testdomai.com
```

```text
run cuc dbquery unitydirdb select * from tbl_smtpproxyaddress where smtpaddress like '%@testdomai.com'
```

```text
objectid                              smtpaddress              object_contactobjectid  object_distributionlistobjectid  object_globaluserobjectid             object_personalgroupobjectid
------------------------------------  -----------------------  ----------------------  -------------------------------  ------------------------------------  ----------------------------
c9c90e5b-657c-4294-a1ed-2dccaa6af70b  ken.perry@testdomai.com  null                    null                             ebdc174a-71c6-435e-8bb2-2960396f14a5  null
```

So there. We create our query to pull a user alias and smtp address and correlate them where the address has testdomai.com in it.We simply need to query either directly for the address we want to change within the tbl_smtpproxyaddress table, or, query everything within the row where that address exists. Cool, we got it. Let's just, you know, use a similar command to update that entry. Easy peasy.

## Issue an update to the smtpaddress field

```text
run cuc dbquery unitydirdb update tbl_smtpproxyaddress set smtpaddress=replace(smtpaddress,'@testdomai.com','@othertestdomai.com') where smtpaddress like '%@testdomai.com'

Rows: 1
```

## Verify the update succeeded

```text
run cuc dbquery unitydirdb select * from tbl_smtpproxyaddress where smtpaddress like '%@testdomai.com'

No records found
```

Boom. Look at that. That's beautiful.

```text
run cuc dbquery unitydirdb select * from tbl_smtpproxyaddress where smtpaddress like '%@othertestdomai.com'
```

```text
objectid                              smtpaddress                   object_contactobjectid  object_distributionlistobjectid  object_globaluserobjectid             object_personalgroupobjectid
------------------------------------  ----------------------------  ----------------------  -------------------------------  ------------------------------------  ----------------------------
c9c90e5b-657c-4294-a1ed-2dccaa6af70b  ken.perry@othertestdomai.com  null                    null                             ebdc174a-71c6-435e-8bb2-2960396f14a5  null
```

And for good measure, we check the GUI

## Pre Change

<span class="image fit"><img src="{{ "/assets/images/acceptandrelay4.png" | absolute_url }}" alt="Pre-Change SMTP Proxy Address Presentation." /></span>

## Post Change

<span class="image fit"><img src="{{ "/assets/images/acceptandrelay3.png" | absolute_url }}" alt="Post-Change SMTP Proxy Address Presentation." /></span>

And that's it! In this instance we edit only a single user, but this can be applied across all entries that match the given domain we want to replace. SO MUCH FASTER than the alternative methods, especially if needing to be done on-the-fly and you don't want to spend a day and a half editing a csv file.

In regards to the availability of the Data Dictionary for CUC, based on some searching and with the help of [Cisco's Support Forums](https://community.cisco.com/t5/audio-and-video-endpoints/cuc-data-dictionary/td-p/3473305) they seems to suggest the data dictionary can be found in XML format bundled with [Cisco Unity Tool's CUDLI](http://www.ciscounitytools.com/Applications/CxN/CUDLI/CUDLI.html).

I just want to say, this is not user friendly whatsoever. The XML files included are, in a sense, readable and searchable... but it's no where near a convenient format. Cisco deserves props for the CUCM Data Dictionary they provide, just wish they'd do the same for IM&P/CUC.

Now, doing this in BAT isn't a fun prospect either. If you've got a ton of users in Unity, you're going to have to sit and wait for BAT to export every user to a file just so you can see the CSV structure. Or, you can see the structure on this post (or likely elsewhere online if you poke around enough). And here's what we get.

## To Export CSV to Update User Attributes [Tools > Bulk Administration Tool]

<span class="image fit"><img src="{{ "/assets/images/acceptandrelay2.png" | absolute_url }}" alt="The Export to CSV page on Cisco Unity." /></span>

*Note: This will parse all users while exporting and can take some time. It does not allow you to filter which user or subset of users.*

## CSV Structure for Cisco Unity "Users with Mailbox"

There is difficulty viewing the below csv structure, even in code bracket, due to the way the website displays the data. My apologies!

```text
Alias,Address,AltFirstNames,AltLastNames,BillingId,Building,City,Country,Department,DisplayName,EmailAddress,MailName,EmployeeId,EnhancedSecurityAlias,FirstName,Initials,Language,LastName,Manager,PostalCode,State,TimeZone,Title,CosDisplayName,Extension,ClientMatterCode,TransferType,TransferRings,TransferExtension,TransferAction,RnaAction,StandardTransferType,StandardTransferRings,StandardTransferExtension,StandardTransferAction,StandardRnaAction,ClosedTransferType,ClosedTransferRings,ClosedTransferExtension,ClosedTransferAction,ClosedRnaAction,MWIExtension,MWIMediaSwitchDisplayName,MaxMsgLen,playPostGreetingRecording,postGreetingRecordingDisplayName,ForcedAuthorizationCode,ListInDirectory,CreateSmtpProxyFromCorp,MediaSwitchDisplayName,PhoneNumber_HomePhone,Active_HomePhone,DisplayName_HomePhone,PhoneNumber_WorkPhone,Active_WorkPhone,DisplayName_WorkPhone,PhoneNumber_MobilePhone,Active_MobilePhone,DisplayName_MobilePhone,PhoneNumber_Pager,AfterDialDigits_Pager,Active_Pager,DisplayName_Pager,PhoneNumber_TextPager1,SmtpAddress_TextPager1,Active_TextPager1,DisplayName_TextPager1,SmtpAddress_HTML,Active_HTML,DisplayName_HTML,templateName_HTML,callback_HTML,disableMobPCA_HTML,disableTemplatePCA_HTML,allowVmAsAttachment_HTML,Extension_Alt1,Extension_Alt1_Partition,Extension_Alt2,Extension_Alt2_Partition,Extension_Alt3,Extension_Alt3_Partition,Extension_Alt4,Extension_Alt4_Partition,Extension_Alt5,Extension_Alt5_Partition,Extension_Alt6,Extension_Alt6_Partition,Extension_Alt7,Extension_Alt7_Partition,Extension_Alt8,Extension_Alt8_Partition,Extension_Alt9,Extension_Alt9_Partition,CcmId,EmailAction,VoicemailAction,FaxAction,DeliveryReceiptAction,RelayAddress,SmtpProxyAddresses,LdapCcmUserId,CorporatePhoneNumber,CrossServerTransferExtension
```

## CSV Structure for Updating User in CUC for User With Mailbox

```text
kperry,,,,,,,US,OPR - Oprtns : Service Engineering,Ken Perry,Ken.Perry@domain1.com,kperry,,,Ken,,1033,Perry,bman,,,35,"IPT Network Engineer",Voice Mail User COS,9999,,0,4,9999,1,1,0,4,9999,1,1,0,4,9999,1,1,9999,SYR-CUCM,300,0,,,1,1,SYR-CUCM,,,Home Phone,,,Work Phone,,,Mobile Phone,,,,Pager,,,,SMTP,,,HTML,,,0,0,0,,,,,,,,,,,,,,,,,,,,1,1,1,1,kenperry@testdomain.com,"kperry@unity01.domain2.com,ken.perry@domain2.com,kperry@unity.domain2.com,ken.perry@domain1.com",kperry,XXX-XXX-XXXX,
```

There we go. Not as easy as an SQL query, not as efficient either when it comes to multiple users. We'd have to get into some data manipulation using Linux CLI tools, Notepad++, Sublime or others to try to speed up the modification of multiple users, but not bad at all. What we would do is modify the attributes within the italicized portions above (which are within quotes, as they are all SmtpProxyAddresses), and then import the BAT file.

I hope this has been informative. It's been a bit humbling for me, as most of the SQL work I've performed on CUC/CUCM has not run into much issue until now. But, in the face of this momentary failure the best thing we can do is strive to learn more, lab more, and ultimately overcome it next time!

...And we absolutely did. A little time away from the issue and some expert advise from my amazing colleague Mark and it's solved! If you enjoy my blog posts please follow the blog, sign up for the mailing list, find me on LinkedIn or Twitter (@ThoughtsNOC)!
