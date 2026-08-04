---
title: "Finding Alternate Extensions in Unity Connection Using SQL"
date: 2026-08-04T12:00:00-04:00
categories:
  - Unified Communications
  - Cisco
  - SQL
tags:
  - Cisco Unity Connection
  - Cisco
  - Cisco UC
  - Database
  - Informix
  - SQL
  - Alternate Extensions
description: "Use a targeted Unity Connection SQL query to find the mailbox user holding a specific number as an alternate extension when it blocks new-user onboarding."
draft: false
---

## When The Extension Is Already In Use—Somewhere

Today's post covers a small SQL query for one of those Unity Connection problems that is simple once you know where to look and remarkably irritating until you do.

You are onboarding a new user with a mailbox. The extension should be available, the expected user is not already present, and then Unity Connection informs you that the extension is already in use.

The catch is that the number may not be another user's **primary extension**. It may be assigned to an existing User with Mailbox as an **alternate extension**. Looking only at the primary extension field will not tell you who owns it, and clicking through users one at a time is not how I want to spend an afternoon.<!--more-->

So, naturally, we query the database.

## What Is Our Mission?

Given one extension, identify the Unity Connection mailbox user who currently has that number assigned as an alternate extension.

Once we know the user, we can review the assignment, remove the alternate extension through Unity Connection Administration, verify that the number is no longer claimed, and proceed with onboarding the new user.

The SQL portion of this process is read-only. It tells us where the extension lives; it does not remove it from the database.

## Relevant Data, Attributes, And Tables

As with most of the Informix queries I use, it helps to understand what we are pulling and how the records relate before dropping the whole thing into the CLI.

### Attributes

```text
vw_user u
------------
u.objectid
u.alias
u.firstname
u.lastname
u.dtmfaccessid

tbl_dtmfaccessid d
------------------
d.parent_globaluserobjectid
d.dtmfaccessid
d.idindex

vw_mailbox m
------------
m.userobjectid
```

From `vw_user`, we pull the user's alias, first name, last name, and `dtmfaccessid`. The user's `dtmfaccessid` is presented in our output as the primary extension. We also use `u.objectid` behind the scenes to correlate that user with the other tables.

`tbl_dtmfaccessid` contains the DTMF access IDs associated with the user. Its `parent_globaluserobjectid` points back to `u.objectid`, while `d.dtmfaccessid` gives us the extension we are searching for. The `idindex` value lets us exclude index `0`, which represents the primary extension in this relationship, and return only non-primary—or alternate—extensions.

Finally, `vw_mailbox` is joined through `m.userobjectid=u.objectid`. We do not need to display a mailbox attribute in the output; the join is there to limit the result to a user who actually has a mailbox.

### Tables And Views

```text
vw_user
User identity and extension information presented through the Unity directory view.

tbl_dtmfaccessid
DTMF access IDs associated with users, including indexed alternate extensions.

vw_mailbox
Mailbox records associated with Unity Connection users.
```

## Query—Find A Specific Alternate Extension

In this example, the new user needs extension `2230`, but Unity Connection reports that the extension is already in use.

Run the following command from the Unity Connection Publisher CLI:

```text
run cuc dbquery unitydirdb select distinct u.alias,u.firstname,u.lastname,u.dtmfaccessid as primaryextension,d.dtmfaccessid as alternateextension from vw_user u inner join tbl_dtmfaccessid d on d.parent_globaluserobjectid=u.objectid inner join vw_mailbox m on m.userobjectid=u.objectid where d.dtmfaccessid='2230' and d.idindex not in (0)
```

## Query Output

```text
alias    firstname  lastname  primaryextension  alternateextension
-------  ---------  --------  ----------------  ------------------
JaneDoe  Jane       Doe       3223              2230
```

There we go.

The extension we need, `2230`, is not Jane Doe's primary extension. Her primary extension is `3223`, but `2230` is still attached to her mailbox as an alternate extension. That existing assignment is what prevents us from using `2230` during the new user's onboarding.

The `distinct` keyword keeps the result focused if the joins would otherwise return the same user and extension combination more than once.

## Remove The Alternate Extension

Now that we know which user owns the extension, open that user in Cisco Unity Connection Administration and review the alternate extensions assigned to the mailbox.

For the example above:

1. Open the User with Mailbox for `JaneDoe`.
2. Navigate to the user's alternate-extension configuration.
3. Confirm that `2230` is no longer required for that mailbox.
4. Remove the `2230` alternate extension and save the change.

I would not perform the removal with a direct SQL `delete`. The query gives us the quick identification method we need, while the administrative interface handles the actual configuration change through the supported application workflow.

## Verify The Extension Is Available

After removing the alternate extension, run the original query again:

```text
run cuc dbquery unitydirdb select distinct u.alias,u.firstname,u.lastname,u.dtmfaccessid as primaryextension,d.dtmfaccessid as alternateextension from vw_user u inner join tbl_dtmfaccessid d on d.parent_globaluserobjectid=u.objectid inner join vw_mailbox m on m.userobjectid=u.objectid where d.dtmfaccessid='2230' and d.idindex not in (0)
```

The expected result is:

```text
No records found
```

At that point, the alternate-extension assignment is gone and we can return to the normal onboarding process for the new User with Mailbox.

## Reuse It For Another Extension

The only value that needs to change for another lookup is the extension in the `where` clause:

```sql
where d.dtmfaccessid='<EXTENSION>' and d.idindex not in (0)
```

Substitute the extension Unity Connection reports as being in use, run the query, and it should return the mailbox user holding that number as an alternate extension.

That's it. One read-only query saves us from hunting through user records, shows both the primary and conflicting alternate extension in the same output, and gives us exactly where to go to clear the old assignment before continuing with onboarding.
