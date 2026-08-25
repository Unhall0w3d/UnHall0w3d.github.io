---
title: "Finding Active Phone Extensions And Voice Mail Profiles Using CUCM SQL"
date: 2026-08-25T19:30:00-04:00
categories:
  - Unified Communications
  - Cisco
  - SQL
tags:
  - Cisco Unified Communications Manager
  - Cisco UC
  - CUCM
  - Informix
  - SQL
  - Directory Number
  - Voice Mail Profile
description: "Use one read-only CUCM SQL query to inventory directory numbers assigned to phone-class devices, including their partitions and Voice Mail Profiles."
---

## When The Directory Number List Stops Matching Reality

Sooner or later, every phone system develops a little sediment.

People leave. Offices move. Conference rooms get renamed. Phones are repurposed. A directory number that belonged to one person quietly becomes a shared line, a common-area phone, or something nobody wants to claim without checking three inventories and asking around.

The immediate request was straightforward: produce a snapshot of the extensions currently assigned to phones in Cisco Unified Communications Manager, then use that list to true-up user, phone, and room assignments. From there, we could identify stale ownership, find users who were no longer with the organization, and decide what actually needed to be cleaned up.<!--more-->

Opening every phone in CUCM Administration would technically answer the question. It would also be a terrible way to spend the afternoon.

So, naturally, we query the database.

## What Is Our Mission?

Return every Directory Number mapped to a phone-class device, along with:

- the CUCM device name;
- the device description;
- the extension;
- the extension's partition; and
- the configured Voice Mail Profile.

I am using **active** in a very specific configuration sense here: the Directory Number is assigned to at least one phone-class device in CUCM.

That does **not** prove the device is currently registered, that somebody still uses it, or that its description matches its actual owner. Those are separate questions. This query gives us the configured starting point needed to investigate them.

The query is read-only. It identifies configuration for review; it does not delete a user, remove a line, or change a Voice Mail Profile.

## Relevant Data, Attributes, And Tables

### Attributes

```text
device d
--------
d.pkid
d.name
d.description
d.tkclass

devicenumplanmap dnpm
---------------------
dnpm.fkdevice
dnpm.fknumplan

numplan n
---------
n.pkid
n.dnorpattern
n.fkroutepartition
n.fkvoicemessagingprofile
n.tkpatternusage

routepartition rp
-----------------
rp.pkid
rp.name

voicemessagingprofile vmp
-------------------------
vmp.pkid
vmp.name
```

From `device`, we return the configured device name and description. The device `pkid` does not appear in the report, but it gives `devicenumplanmap` the key it needs to relate the phone to its assigned lines.

`devicenumplanmap` is the bridge between the device and the Directory Number. If a DN is not mapped to a device through this table, it does not appear in this report. That relationship is what makes the query useful for an assigned-extension snapshot instead of another general dial-plan dump.

`numplan` supplies the Directory Number through `dnorpattern`, along with the foreign keys for its partition and Voice Mail Profile. We also use `tkpatternusage` to limit the result to Directory Number records rather than returning every kind of pattern CUCM stores in the same table.

The `routepartition` and `voicemessagingprofile` tables turn those foreign keys into names that are useful to a person reading the report.

### Tables

```text
device
The configured CUCM device, including physical phones, supported soft clients,
and other objects stored in the phone device class.

devicenumplanmap
The mapping between a CUCM device and each Directory Number assigned to it.

numplan
Directory Numbers and other dial-plan patterns. The query filters this to DNs.

routepartition
The partition assigned to the Directory Number.

voicemessagingprofile
The Voice Mail Profile assigned to the Directory Number.
```

## The Query

Run the following command from the CUCM Publisher CLI:

```text
run sql select d.name as DeviceName,d.description as DeviceDescription,n.dnorpattern as Extension,rp.name as Partition,vmp.name as VoiceMailProfile from device d inner join devicenumplanmap dnpm on dnpm.fkdevice=d.pkid inner join numplan n on n.pkid=dnpm.fknumplan left join routepartition rp on rp.pkid=n.fkroutepartition left join voicemessagingprofile vmp on vmp.pkid=n.fkvoicemessagingprofile where d.tkclass=1 and n.tkpatternusage=2 order by n.dnorpattern,d.name
```

There are a few important choices packed into that one line.

The two `inner join` statements require a real device-to-line mapping. A standalone DN that is not assigned to one of the selected devices will not be returned.

The partition and Voice Mail Profile use `left join` instead. That keeps the Directory Number in the report even when either foreign key is empty. In practical terms, a DN with no assigned Voice Mail Profile still appears with `NULL` instead of disappearing from the inventory.

The two filters keep the scope under control:

```sql
d.tkclass=1
n.tkpatternusage=2
```

`d.tkclass=1` limits the device side to CUCM's phone class. `n.tkpatternusage=2` limits the pattern side to Directory Numbers. The final `order by` puts shared occurrences of the same extension together and sorts them by device name.

That last point matters. There is no `distinct` in the query because one Directory Number can be assigned to several phones. For this audit, seeing every device-line relationship is the useful behavior.

## Example Output

The production result was considerably longer. The sample below is trimmed to five returned entries, and the device identifiers, names, and extensions have been fictionalized.

```text
devicename      devicedescription  extension  partition    voicemailprofile
=============== ================== =========  ============ =================
SEP000000000001 Teal'c             5001       Internal-PT  NULL
SEP000000000002 Daniel Jackson     5002       Internal-PT  NULL
SEP000000000003 Samantha Carter    5003       Internal-PT  NULL
SEP000000000004 Jack O'Neill       5004       Internal-PT  NULL
SEP000000000005 General Hammond    5005       Internal-PT  NULL
```

This gives us a clean snapshot for review: five device-line assignments, their configured ownership labels, partitions, and Voice Mail Profile state.

In this example, every returned line shows `NULL` for `voicemailprofile`. That does not automatically mean the line is broken. It means there is no matching named Voice Mail Profile on the DN for this join to return. Whether that is intentional depends on the device and its purpose.

## What Device Types Can Appear?

Because the filter is based on CUCM's phone device class—not a `SEP`, `CSF`, or other name prefix—the report is not limited to physical desk phones.

Depending on what is configured in the environment, it can return:

- physical IP phones, commonly named with a `SEP` prefix;
- Cisco IP Communicator devices, whether they use a `CIPC`-style name, an `IPCCFLAST` convention, or another manually configured device name;
- Jabber or soft-client devices such as `CSF`, `BOT`, and `TCT`;
- legacy `CUCI`-style client devices; and
- CTI Ports stored as phone-class devices when they have a mapped Directory Number.

Two naming distinctions are worth making.

`IPCC` can appear in two different contexts. CUCM has an End User IPCC extension field, but some environments also use names such as `IPCCFLAST` for manually configured Cisco IP Communicator devices. This query does not care which naming convention was chosen. If the IP Communicator is stored as a phone-class device and has a mapped Directory Number, it is included.

The legacy soft-client prefix intended here is `CUCI`, not `CUIC`. `CUIC` ordinarily refers to Cisco Unified Intelligence Center.

CTI Route Points are also different from CTI Ports. A CTI Route Point belongs to a different CUCM device class, so `d.tkclass=1` excludes it. If the goal is to inventory Route Points too, that should be a deliberate expansion of the query rather than an assumption that every object beginning with `CTI` is already included.

## Where This Overlaps With Earlier Queries

This is not the first time I have pulled on the threads connecting phones, Directory Numbers, and voicemail configuration.

The older [Dial Plan Dump Using SQL](/2019/07/21/dial-plan-dump-using-sql.html) starts from `numplan` and is intended to expose a much broader view of CUCM's configured patterns. That is useful when the mission is understanding the dial plan. This query is narrower: it requires a device-to-DN mapping and deliberately returns one row per assigned phone line.

[Finding Orphaned Devices And Device Profiles](/2019/11/06/finding-orphaned-devices-and-device-profiles.html) also uses `device` and the phone-class filter, but asks a different ownership question. It looks for phones and device profiles without an End User association through `enduserdevicemap`. The query in this post does not inspect End User associations and does not include device profiles; it inventories the lines configured on phone-class devices so that ownership can be compared against another source.

Finally, [Voice Mail Profile SQL Queries](/2022/02/27/vm-profile-sql-queries.html) also relates `numplan` to `voicemessagingprofile`. That post is aimed at finding inconsistent call-forward and voicemail configurations. Here, the Voice Mail Profile is supporting inventory data. We are returning it beside every assigned DN, not filtering for a particular voicemail or call-forward condition.

Similar tables, different missions.

## Turning The Snapshot Into Cleanup Work

The returned list is the beginning of the audit, not permission to start deleting things.

I would compare it against the current user roster, room and common-area inventory, phone ownership records, and whatever source the organization treats as authoritative. Shared lines should be expected to appear more than once. CTI Ports, application-controlled devices, emergency phones, and common-area devices should be identified before anybody decides that a missing person's name makes the configuration disposable.

When something does need to change, I would make the correction through the supported CUCM Administration or provisioning workflow, then run the query again and retain the updated result as the new snapshot.

For a larger cleanup effort, two exports are useful:

1. the untouched pre-change snapshot; and
2. the post-change verification snapshot.

That gives us evidence of what CUCM contained before the work, what we intended to correct, and what the environment reported afterward.

## One Query, Fewer Assumptions

The query does not tell us whether the person in the description still works there. It does not prove the phone is registered, and it does not decide whether a `NULL` Voice Mail Profile is correct.

What it does is replace a vague question—*which extensions are actually on phones?*—with a concrete list of configured device-line relationships.

That is enough to stop guessing and start the true-up with something CUCM itself can defend.
