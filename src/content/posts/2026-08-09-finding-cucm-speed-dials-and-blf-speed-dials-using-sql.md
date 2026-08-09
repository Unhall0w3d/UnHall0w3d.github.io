---
title: "Finding CUCM Speed Dials and BLF Speed Dials Using SQL"
date: 2026-08-09T14:00:00-04:00
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
  - Speed Dial
  - BLF Speed Dial
description: "Use one read-only CUCM SQL query to find phones with a Speed Dial or BLF Speed Dial configured for a specific extension, then verify labels after an ownership change."
draft: false
---

## When The Extension Changes Hands, But The Buttons Do Not

One of the ordinary cleanup tasks after a user moves, changes names, or inherits an existing extension is making sure the people who watch that extension are still seeing the right label on their phones.

The directory number itself may be fine. Calls land where they should. The thing that is now wrong is the nearby button: an old Speed Dial or BLF Speed Dial still says `Peter`, or `Peter Parker`, even though extension `3012` now belongs to Miles Morales.

Sure, we can open devices one at a time and look for the button. That gets old quickly, especially when the extension is present as a BLF Speed Dial on several phones and the label is not uniform.<!--more-->

So, naturally, we query the database.

## What Is Our Mission?

Given one extension, return every CUCM device with either:

- a regular **Speed Dial** pointing to that extension; or
- a **BLF Speed Dial** pointing to that extension, whether CUCM stores the destination directly or through a Directory Number record.

The result tells us the device, its description, the button position, the existing label, the destination, and—where CUCM can associate it—the partition. That gives us a focused checklist for updating the label through the supported CUCM Administration interface, followed by a quick re-check.

The query is read-only. It identifies configuration that needs attention; it does not change a Speed Dial or BLF Speed Dial.

## Relevant Data, Attributes, And Tables

As with many of the queries I run, I like to define the attributes we pull from the Informix database so the output can be handed to an engineer, administrator, or client without another round of translation.

### Attributes

```text
device d
--------
d.pkid
d.name
d.description

speeddial s
------------
s.fkdevice
s.speeddialindex
s.label
s.speeddialnumber

blfspeeddial b
---------------
b.fkdevice
b.blfindex
b.label
b.blfdestination
b.fknumplan

numplan n
---------
n.pkid
n.dnorpattern
n.fkroutepartition

routepartition r
----------------
r.pkid
r.name
```

From `device`, we pull the device name and description. The `pkid` is not displayed, but it is the key that lets us relate each Speed Dial record back to the correct phone.

The `speeddial` table gives us the regular Speed Dial records: `speeddialindex` is the button position, `label` is what the user sees, and `speeddialnumber` is the configured destination.

`blfspeeddial` provides the equivalent BLF Speed Dial information. Its `blfindex` and `label` work the same way for our report. The destination needs slightly more care: CUCM may store it directly in `blfdestination`, or it may point to a Directory Number through `fknumplan`.

That is why we also use `numplan` and `routepartition`. `n.dnorpattern` gives us the actual directory number when the BLF points to a DN record, and `r.name` gives us that DN's partition. Both are `left outer join` values because a BLF Speed Dial with a direct destination does not necessarily have a matching `numplan` record or partition to return.

### Tables

```text
device
The configured phone or other CUCM device.

speeddial
Regular Speed Dial buttons assigned to a device.

blfspeeddial
BLF Speed Dial buttons assigned to a device.

numplan
Directory Number and pattern records used when a BLF references a CUCM DN.

routepartition
The partition associated with the referenced Directory Number.
```

## Query—Find Speed Dials And BLF Speed Dials For One Extension

In this example, extension `3012` has a new owner. Before and after updating the button labels, we want to know every phone configured to reach or monitor that extension.

Run the following command from the CUCM Publisher CLI:

```text
run sql select 'SD' as entrytype,d.name,d.description,s.speeddialindex as buttonindex,s.label,s.speeddialnumber as destination,'' as partitionname from speeddial s inner join device d on s.fkdevice=d.pkid where s.speeddialnumber='3012' union all select 'BLF' as entrytype,d.name,d.description,b.blfindex as buttonindex,b.label,case when b.blfdestination is null or b.blfdestination='' then n.dnorpattern else b.blfdestination end as destination,r.name as partitionname from blfspeeddial b inner join device d on b.fkdevice=d.pkid left outer join numplan n on b.fknumplan=n.pkid left outer join routepartition r on n.fkroutepartition=r.pkid where b.blfdestination='3012' or n.dnorpattern='3012' order by 1,2,4
```

There are two separate `select` statements here, joined with `union all`:

1. The first returns regular Speed Dials from `speeddial` and tags them as `SD`.
2. The second returns BLF Speed Dials from `blfspeeddial` and tags them as `BLF`.

The BLF half uses a `case` statement so `destination` remains useful in both common configurations. If `blfdestination` contains a direct value, we return it. If it is empty, we return `n.dnorpattern` from the linked Directory Number record instead.

`union all` is intentional. A regular Speed Dial and a BLF Speed Dial can legitimately appear on the same device for the same extension; we want to see both, not have SQL collapse one of them. The final `order by 1,2,4` groups the result by entry type, device name, and button position.

## Initial Query Output

Here is the initial return for extension `3012`:

```text
entrytype  name              description                 buttonindex  label          destination  partitionname
---------  ----------------  --------------------------  -----------  -------------  -----------  -------------
BLF        SEPA4780687DE0E  CO - Tuesday - 3016          12           Peter          3012         PT_EXTENSIONS
BLF        SEPA4780687E2CA  CO - Jarvis - 3007           2            Peter Parker   3012         PT_EXTENSIONS
BLF        SEPA4780698888C  CO - Steve Rogers - 3002     2            Peter Parker   3012         PT_EXTENSIONS
BLF        SEPA47806B2F5C0  CO - Tony Stark - 3006       2            Peter Parker   3012         PT_EXTENSIONS
BLF        SEPD47798E0F470  CO - Dr. Banner - 3001       2            Peter Parker   3012         PT_EXTENSIONS
BLF        SEPD47798E14A20  CO - Thor Odinson - 3015     14           Peter Parker   3012         PT_EXTENSIONS
BLF        SEPD47798E159B8  CO - Loki Odinson - 3003     2            Peter          3012         PT_EXTENSIONS
```

The important part here is not just that `3012` appears seven times. We also know exactly which devices have it, which button index to inspect, and which labels are stale. In this example, the old labels are a mix of `Peter` and `Peter Parker`, so a broad search-and-replace would be less useful than reviewing the returned buttons directly.

## Update The Labels Through CUCM Administration

For each returned device, open the phone in CUCM Administration and locate the identified Speed Dial or BLF Speed Dial button position.

1. Confirm the button still needs to point to `3012`.
2. Update its label to the current owner or the local naming convention—for this example, `Miles` or `Miles Morales`.
3. Save the phone configuration and apply/reset it when CUCM requires the device to receive the updated configuration.

The query is deliberately the discovery and verification tool. I would make the label change through the supported phone configuration workflow, not with a direct Informix update.

## Re-Check After Updating The BLF Speed Dials

Run the same query again after saving the changes:

```text
entrytype  name              description                 buttonindex  label          destination  partitionname
---------  ----------------  --------------------------  -----------  -------------  -----------  -------------
BLF        SEPA4780687DE0E  CO - Tuesday - 3016          12           Miles          3012         PT_EXTENSIONS
BLF        SEPA4780687E2CA  CO - Jarvis - 3007           2            Miles Morales  3012         PT_EXTENSIONS
BLF        SEPA4780698888C  CO - Steve Rogers - 3002     2            Miles Morales  3012         PT_EXTENSIONS
BLF        SEPA47806B2F5C0  CO - Tony Stark - 3006       2            Miles Morales  3012         PT_EXTENSIONS
BLF        SEPD47798E0F470  CO - Dr. Banner - 3001       2            Miles Morales  3012         PT_EXTENSIONS
BLF        SEPD47798E14A20  CO - Thor Odinson - 3015     14           Miles Morales  3012         PT_EXTENSIONS
BLF        SEPD47798E159B8  CO - Loki Odinson - 3003     2            Miles          3012         PT_EXTENSIONS
```

The destination did not change; it is still `3012` in the expected partition. What changed is the label users see on the physical or soft button. That re-check is a small thing, but it is the difference between assuming the cleanup was complete and proving it.

## Reuse It For Another Extension

To search for another extension, replace both occurrences of `3012` in the `where` clauses with the extension you need to inspect:

```sql
where s.speeddialnumber='<EXTENSION>'

...

where b.blfdestination='<EXTENSION>' or n.dnorpattern='<EXTENSION>'
```

For example, to search for `5222`, change those two values to `'5222'`:

```text
where s.speeddialnumber='5222'

...

where b.blfdestination='5222' or n.dnorpattern='5222'
```

Keep both BLF conditions. Removing the `n.dnorpattern` condition would miss BLF Speed Dial records that reference the Directory Number through `fknumplan` instead of storing the destination directly in `blfdestination`.

That is it. One read-only query gives us a fast, consistent way to find all of the Speed Dial and BLF Speed Dial references that should be reviewed after an extension owner or display name changes.
