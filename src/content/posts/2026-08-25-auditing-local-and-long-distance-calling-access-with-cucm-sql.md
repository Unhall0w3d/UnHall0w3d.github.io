---
title: "Auditing Local And Long-Distance Calling Access With CUCM SQL"
date: 2026-08-25T20:30:00-04:00
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
  - Calling Search Space
  - Route Pattern
  - Forced Authorization Code
description: "Use read-only CUCM SQL queries to audit configured phone reachability to local and long-distance route-pattern partitions, including FAC requirements."
---

## A Calling Search Space Name Is Not An Answer

Calling permissions tend to make perfect sense when they are first built. Then phones move, lines are shared, exceptions are added, and a Calling Search Space with a reassuring name slowly stops being a reliable description of what it can actually reach.

That was the problem behind this set of queries. We needed to identify which CUCM phone devices had configured access to local dialing, long distance requiring a Forced Authorization Code, and long distance without one. More importantly, we needed to answer that question from the partitions actually contained in the Device and Line Calling Search Spaces—not from what somebody named those CSSs years ago.<!--more-->

Opening phones one at a time would show the assigned CSS names. Opening each CSS would show its partitions. Repeating that across the environment would eventually produce an answer, provided nobody lost their place or their will to live.

So, naturally, we query the database.

## What Is Our Mission?

For each phone and its primary line appearance, return:

- the device name and description;
- the extension;
- the Device Calling Search Space;
- the Line Calling Search Space;
- the route pattern and partition being tested; and
- the authorization level required by that route pattern.

We will run the reachability query against three deliberately defined targets:

1. long distance through `LD-FAC-PT`, where the route pattern requires a Forced Authorization Code;
2. long distance through `LongDistance-PT`, where the route pattern does not require a FAC; and
3. local dialing through `Local-PT`.

We will also inventory the configured FACs and their authorization levels, then look at the variation that audits every line appearance instead of Line 1 only.

These are read-only configuration queries. They do not place a call, prove a phone is registered, or perform CUCM's complete digit-analysis process. They answer a narrower and still useful question: **does either configured CSS contain the partition holding this exact route pattern?**

## Relevant Data, Attributes, And Tables

### Attributes

```text
device d
--------
d.pkid
d.name
d.description
d.tkclass
d.fkcallingsearchspace

devicenumplanmap dnpm
---------------------
dnpm.fkdevice
dnpm.fknumplan
dnpm.numplanindex

numplan ln
----------
ln.pkid
ln.dnorpattern
ln.fkcallingsearchspace_sharedlineappear

callingsearchspace dcss / lcss
---------------------------------
dcss.pkid
dcss.name
lcss.pkid
lcss.name

callingsearchspacemember csm / csm2
-----------------------------------
csm.fkcallingsearchspace
csm.fkroutepartition
csm2.fkcallingsearchspace
csm2.fkroutepartition

numplan rp
----------
rp.dnorpattern
rp.fkroutepartition
rp.tkpatternusage
rp.authorizationlevelrequired

routepartition rppt
-------------------
rppt.pkid
rppt.name

facinfo
-------
name
code
authorizationlevel
```

`device` gives us the phone and its Device CSS. `devicenumplanmap` relates that phone to a Directory Number and, through `numplanindex`, lets us decide whether to inspect only the first line appearance or every line configured on the device.

The first `numplan` alias, `ln`, represents the Directory Number assigned to the phone. It gives us the extension and the Line CSS. The second alias, `rp`, represents the exact route pattern whose reachability we are testing. CUCM stores several pattern types in `numplan`, so `rp.tkpatternusage=5` keeps this side of the query focused on route patterns.

`callingsearchspace` turns the CSS foreign keys into readable names. The more important table for this audit is `callingsearchspacemember`: it tells us which route partitions are actually members of each CSS.

Finally, `routepartition` identifies the target partition, while `facinfo` gives us a separate inventory of Forced Authorization Codes and their authorization levels.

## How The Reachability Test Works

The heart of each query is the pair of `exists` tests:

```sql
(d.fkcallingsearchspace is not null and exists (...))
or
(ln.fkcallingsearchspace_sharedlineappear is not null and exists (...))
```

The first checks whether the route pattern's partition is a member of the Device CSS. The second performs the same check against the Line CSS. If either condition is true, the device-line combination is returned.

That is why these queries do not have to infer anything from a CSS name. A CSS called `Local-Only-CSS` might contain more than local partitions. A CSS called `Standard-User-CSS` tells us almost nothing without its membership. The query follows the foreign keys and asks CUCM what is actually there.

There are still boundaries around the answer. Partition order, overlapping patterns, transformations, time schedules, route-plan design, and the digits a user actually enters can all affect a real call. These queries do not replace Dialed Number Analyzer or a controlled call test. They provide an environment-wide configuration audit that tells us which device-line combinations deserve the next look.

## Query 1: Long Distance Requiring A FAC

Run the following command from the CUCM Publisher CLI:

```text
run sql select d.name as Device,d.description as Description,ln.dnorpattern as Extension,dcss.name as DeviceCSS,lcss.name as LineCSS,rp.dnorpattern as RoutePattern,rppt.name as RoutePatternPT,rp.authorizationlevelrequired as AuthorizationLevel from device d inner join devicenumplanmap dnpm on dnpm.fkdevice=d.pkid and dnpm.numplanindex=1 inner join numplan ln on ln.pkid=dnpm.fknumplan left outer join callingsearchspace dcss on dcss.pkid=d.fkcallingsearchspace left outer join callingsearchspace lcss on lcss.pkid=ln.fkcallingsearchspace_sharedlineappear inner join numplan rp on rp.dnorpattern='8.1[2-9]XXXXXXXXX' and rp.tkpatternusage=5 inner join routepartition rppt on rppt.pkid=rp.fkroutepartition and rppt.name='LD-FAC-PT' where d.tkclass=1 and ((d.fkcallingsearchspace is not null and exists (select csm.pkid from callingsearchspacemember csm where csm.fkcallingsearchspace=d.fkcallingsearchspace and csm.fkroutepartition=rp.fkroutepartition)) or (ln.fkcallingsearchspace_sharedlineappear is not null and exists (select csm2.pkid from callingsearchspacemember csm2 where csm2.fkcallingsearchspace=ln.fkcallingsearchspace_sharedlineappear and csm2.fkroutepartition=rp.fkroutepartition))) order by d.name
```

The example below is trimmed to five entries. Device identifiers, descriptions, extensions, and CSS names are fictionalized.

```text
device          description    extension devicecss              linecss                routepattern       routepatternpt authorizationlevel
=============== ============== ========= ====================== ====================== ================== ============== ==================
ATA000000000001 Bruce Wayne    3101      Gotham-Device-CSS      JusticeLeague-Line-CSS 8.1[2-9]XXXXXXXXX LD-FAC-PT      100
ATA000000000002 Clark Kent     3102      Metropolis-Device-CSS  JusticeLeague-Line-CSS 8.1[2-9]XXXXXXXXX LD-FAC-PT      100
ATA000000000003 Diana Prince   3103      Themyscira-Device-CSS  JusticeLeague-Line-CSS 8.1[2-9]XXXXXXXXX LD-FAC-PT      100
ATA000000000004 Barry Allen    3104      CentralCity-Device-CSS JusticeLeague-Line-CSS 8.1[2-9]XXXXXXXXX LD-FAC-PT      100
ATA000000000005 John Stewart   3105      CoastCity-Device-CSS   JusticeLeague-Line-CSS 8.1[2-9]XXXXXXXXX LD-FAC-PT      100
```

Every row has configured reachability to `LD-FAC-PT` through at least one of its two CSSs. The route pattern requires authorization level `100`, so merely reaching the partition is not the end of the story. A caller must also supply a valid FAC whose authorization level is sufficient for the route pattern.

## Query 2: Which FACs Can Satisfy That Requirement?

```text
run sql select name as FACName,code as FACCode,authorizationlevel as AuthorizationLevel from facinfo order by authorizationlevel,name
```

The source contained two configured entries, so this sample contains two fictional entries rather than inventing three more to fill the page. The names and codes below are not production values.

```text
facname         faccode authorizationlevel
=============== ======= ==================
Hall of Justice 9002    100
Watchtower      9001    100
```

For the route pattern in the first query, the FAC authorization level must meet or exceed `100`. A lower-level code may exist in `facinfo`, but it will not authorize that route pattern.

FAC codes should be handled as access-control information, not decorative report data. I would not publish, email broadly, or leave a production export sitting in a general-purpose project folder. The fictional values here preserve the shape of the result without disclosing usable codes.

## Query 3: Long Distance Without A FAC

The structure is intentionally the same. We change the target partition from `LD-FAC-PT` to `LongDistance-PT` and inspect the matching route pattern's authorization level.

```text
run sql select d.name as Device,d.description as Description,ln.dnorpattern as Extension,dcss.name as DeviceCSS,lcss.name as LineCSS,rp.dnorpattern as RoutePattern,rppt.name as RoutePatternPT,rp.authorizationlevelrequired as AuthorizationLevel from device d inner join devicenumplanmap dnpm on dnpm.fkdevice=d.pkid and dnpm.numplanindex=1 inner join numplan ln on ln.pkid=dnpm.fknumplan left outer join callingsearchspace dcss on dcss.pkid=d.fkcallingsearchspace left outer join callingsearchspace lcss on lcss.pkid=ln.fkcallingsearchspace_sharedlineappear inner join numplan rp on rp.dnorpattern='8.1[2-9]XXXXXXXXX' and rp.tkpatternusage=5 inner join routepartition rppt on rppt.pkid=rp.fkroutepartition and rppt.name='LongDistance-PT' where d.tkclass=1 and ((d.fkcallingsearchspace is not null and exists (select csm.pkid from callingsearchspacemember csm where csm.fkcallingsearchspace=d.fkcallingsearchspace and csm.fkroutepartition=rp.fkroutepartition)) or (ln.fkcallingsearchspace_sharedlineappear is not null and exists (select csm2.pkid from callingsearchspacemember csm2 where csm2.fkcallingsearchspace=ln.fkcallingsearchspace_sharedlineappear and csm2.fkroutepartition=rp.fkroutepartition))) order by d.name
```

```text
device          description    extension devicecss              linecss                routepattern       routepatternpt  authorizationlevel
=============== ============== ========= ====================== ====================== ================== =============== ==================
ATA000000000001 Bruce Wayne    3101      Gotham-Device-CSS      JusticeLeague-Line-CSS 8.1[2-9]XXXXXXXXX LongDistance-PT 0
ATA000000000002 Clark Kent     3102      Metropolis-Device-CSS  JusticeLeague-Line-CSS 8.1[2-9]XXXXXXXXX LongDistance-PT 0
ATA000000000003 Diana Prince   3103      Themyscira-Device-CSS  JusticeLeague-Line-CSS 8.1[2-9]XXXXXXXXX LongDistance-PT 0
ATA000000000004 Barry Allen    3104      CentralCity-Device-CSS JusticeLeague-Line-CSS 8.1[2-9]XXXXXXXXX LongDistance-PT 0
ATA000000000005 John Stewart   3105      CoastCity-Device-CSS   JusticeLeague-Line-CSS 8.1[2-9]XXXXXXXXX LongDistance-PT 0
```

The important comparison is not that these rows exist in isolation. It is whether the same device-line population also appeared in the FAC-required result.

In this sample, it did. That means the devices can reach both a FAC-controlled and a non-FAC long-distance partition. That may be intentional, but it is exactly the kind of overlap worth reviewing. If the unrestricted pattern is an equally good match in the effective calling path, the FAC-controlled pattern may not provide the restriction somebody thinks it does.

## Query 4: Local Calling

For local dialing, change both the route pattern and target partition:

```text
run sql select d.name as Device,d.description as Description,ln.dnorpattern as Extension,dcss.name as DeviceCSS,lcss.name as LineCSS,rp.dnorpattern as RoutePattern,rppt.name as RoutePatternPT,rp.authorizationlevelrequired as AuthorizationLevel from device d inner join devicenumplanmap dnpm on dnpm.fkdevice=d.pkid and dnpm.numplanindex=1 inner join numplan ln on ln.pkid=dnpm.fknumplan left outer join callingsearchspace dcss on dcss.pkid=d.fkcallingsearchspace left outer join callingsearchspace lcss on lcss.pkid=ln.fkcallingsearchspace_sharedlineappear inner join numplan rp on rp.dnorpattern='8.[2-9]XXXXXX' and rp.tkpatternusage=5 inner join routepartition rppt on rppt.pkid=rp.fkroutepartition and rppt.name='Local-PT' where d.tkclass=1 and ((d.fkcallingsearchspace is not null and exists (select csm.pkid from callingsearchspacemember csm where csm.fkcallingsearchspace=d.fkcallingsearchspace and csm.fkroutepartition=rp.fkroutepartition)) or (ln.fkcallingsearchspace_sharedlineappear is not null and exists (select csm2.pkid from callingsearchspacemember csm2 where csm2.fkcallingsearchspace=ln.fkcallingsearchspace_sharedlineappear and csm2.fkroutepartition=rp.fkroutepartition))) order by d.name
```

```text
device          description    extension devicecss              linecss                routepattern  routepatternpt authorizationlevel
=============== ============== ========= ====================== ====================== ============= ============== ==================
ATA000000000001 Bruce Wayne    3101      Gotham-Device-CSS      JusticeLeague-Line-CSS 8.[2-9]XXXXXX Local-PT       0
ATA000000000002 Clark Kent     3102      Metropolis-Device-CSS  JusticeLeague-Line-CSS 8.[2-9]XXXXXX Local-PT       0
ATA000000000003 Diana Prince   3103      Themyscira-Device-CSS  JusticeLeague-Line-CSS 8.[2-9]XXXXXX Local-PT       0
ATA000000000004 Barry Allen    3104      CentralCity-Device-CSS JusticeLeague-Line-CSS 8.[2-9]XXXXXX Local-PT       0
ATA000000000005 John Stewart   3105      CoastCity-Device-CSS   JusticeLeague-Line-CSS 8.[2-9]XXXXXX Local-PT       0
```

This gives us the local-call population using the same test as the long-distance queries. Keeping the shape consistent makes the three results easy to compare without changing the meaning of each column along the way.

## Auditing Every Line Appearance

The first three reachability queries deliberately include:

```sql
dnpm.numplanindex=1
```

That limits the audit to the first line appearance on each phone. It is useful when the mission is specifically the device's primary line, but it is not a complete inventory of every line configured on that device.

To inspect them all, remove that condition and return `dnpm.numplanindex` as `LineIndex`:

```text
run sql select d.name as Device,d.description as Description,dnpm.numplanindex as LineIndex,ln.dnorpattern as Extension,dcss.name as DeviceCSS,lcss.name as LineCSS,rp.dnorpattern as RoutePattern,rppt.name as RoutePatternPT,rp.authorizationlevelrequired as AuthorizationLevel from device d inner join devicenumplanmap dnpm on dnpm.fkdevice=d.pkid inner join numplan ln on ln.pkid=dnpm.fknumplan left outer join callingsearchspace dcss on dcss.pkid=d.fkcallingsearchspace left outer join callingsearchspace lcss on lcss.pkid=ln.fkcallingsearchspace_sharedlineappear inner join numplan rp on rp.dnorpattern='8.1[2-9]XXXXXXXXX' and rp.tkpatternusage=5 inner join routepartition rppt on rppt.pkid=rp.fkroutepartition and rppt.name='LD-FAC-PT' where d.tkclass=1 and ((d.fkcallingsearchspace is not null and exists (select csm.pkid from callingsearchspacemember csm where csm.fkcallingsearchspace=d.fkcallingsearchspace and csm.fkroutepartition=rp.fkroutepartition)) or (ln.fkcallingsearchspace_sharedlineappear is not null and exists (select csm2.pkid from callingsearchspacemember csm2 where csm2.fkcallingsearchspace=ln.fkcallingsearchspace_sharedlineappear and csm2.fkroutepartition=rp.fkroutepartition))) order by d.name,dnpm.numplanindex
```

The example targets `LD-FAC-PT`, but the same substitutions used above work here: change `rp.dnorpattern` and `rppt.name` together to test another exact route pattern and partition.

This distinction matters on phones with shared lines, secondary extensions, or multiple appearances with different Line CSS assignments. A primary-line report can be the right report without being the whole report.

## Where This Overlaps With Earlier Queries

The existing [Dial Plan Dump Using SQL](/2019/07/21/dial-plan-dump-using-sql.html) is the natural starting point when I want a broad inventory of Directory Numbers, route patterns, transformations, partitions, and digit manipulation. It tells me what the dial plan contains. The queries here add the authorization side of the question: which phone and line CSSs contain the partition holding a specific route pattern?

[Do You Hear That? It's A Dial Plan Overlap](/2019/07/05/do-you-hear-that-its-a-dial-plan-overlap.html) approaches the same CSS-to-partition relationship from a troubleshooting direction. It uses Dialed Number Analyzer and debug evidence to understand what happened to a call. This post uses Informix SQL to locate configured reachability across an environment before—or after—a particular failure sends us looking.

There is also structural overlap with [Finding Active Phone Extensions And Voice Mail Profiles Using CUCM SQL](/2026/08/25/finding-active-phone-extensions-and-voicemail-profiles-using-cucm-sql.html). Both start at `device`, cross `devicenumplanmap`, and use `numplan` to retain the device-to-line relationship. That query inventories assigned phone extensions and Voice Mail Profiles. This set continues outward through the Device and Line CSSs, their member partitions, and an exact route pattern.

The tables overlap because the configuration overlaps. The reason for pulling them is different.

## Turning The Results Into A Permissions Review

I would retain the original query results, compare the three device populations, and start with the exceptions:

- devices present in both FAC and non-FAC long-distance results;
- devices that should be local-only but appear in a long-distance result;
- devices expected to have long-distance access that are absent;
- secondary line appearances that differ from the primary-line result; and
- FAC-required route patterns whose required level is not represented by an appropriate, controlled FAC assignment.

An unexpected row is not permission to delete a CSS or remove a partition. Shared lines, application-controlled devices, common-area phones, fax endpoints, and intentionally privileged devices may all produce legitimate exceptions.

Make the correction through supported CUCM Administration or the organization's provisioning workflow. Then run the same query again and retain the post-change result beside the original. The before-and-after comparison is more useful than a vague note saying the calling permissions were cleaned up.

## Ask CUCM What The CSS Can Reach

These queries do not recreate every decision CUCM makes during digit analysis, and I would still use Dialed Number Analyzer or a controlled call test when I need to prove the complete path.

What they do is save us from opening every phone, every line, and every CSS just to establish where the permissions are coming from. We get a list of the devices that can see the target partition, the line involved, and whether the pattern expects a FAC.

A CSS name records what somebody intended. Its member partitions show us what was actually configured.

That is where I want to start the audit.
