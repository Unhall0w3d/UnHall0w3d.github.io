---
title: "CCM Synced End Users -- And How To Delete Them"
date: 2020-01-19T08:00:00-05:00
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

<head>
    <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-7351461893377144"
     crossorigin="anonymous">
     </script>
</head>

<span class="image fit"><img src="{{ "/assets/images/ccmsync1.png" | absolute_url }}" alt="" /></span>

With Cisco's Unified Communications Manager and Unity Connection products we have a few options when it comes to user accounts for both Endpoint/Permissions management, and Voicemail/Greeting management. We can by default create local users, which are maintained within UCM and CUC itself. We can optionally integrate with LDAP Authentication and/or LDAP Synchronization, which allows us to pull in users from LDAP given certain criteria (e.g. AD & CUCM's LDAP Search Filters). And somewhere in the middle we have the option to pull in users from CUCM to CUC via "CUCM End User Integration".

<!--more-->

What this allows us to do is define local users within Cisco Unified Communications Manager, assign permissions and device ownership, and then sync the user to Cisco Unity Connection to inherit certain information (extension, alias, first/last name, etc.). This helps to achieve an LDAP-like experience while also maintaining isolated user accounts. We get the swiftness of a sync but only after the users are manually defined in UCM.

When a user is integrated via CCM End User, within Unity, we will see the below banner Status message. This is an indication that the user is not local, or LDAP Synced. It has been synced from the AXL (CUCM) Server.

<span class="image fit"><img src="{{ "/assets/images/ccmsync2.png" | absolute_url }}" alt="" /></span>

An issue I commonly run into when working in client environments where CCM End User Sync is used, is that green engineers (MACD, Jr. Engineers, Low level service desk folk) often do not understand the requirements when deleting this type of user. For example, the necessity to delete a CCM Synced End User from the UC Secondary Applications prior to deleting the user from Cisco Unified Communications Manager directly. For an example, if we only have CUC and CUCM in our environment and use CCM End User Sync, we'd want to delete the user from Cisco Unity Connection prior to deleting the user from Cisco Unified Communications Manager.

When this process isn't followed there is a break in communication between the CUC and CUCM. An attempt to delete a voicemail box for the given user in CUC, when it does not exist in CUCM, results in a java.lang error in the GUI and no action is taken. A screenshot of this error is shown below.

<span class="image fit"><img src="{{ "/assets/images/ccmsync3.png" | absolute_url }}" alt="" /></span>

Now, when it comes to resolving an issue like this, we can't just rebuild the user on the CUCM side as the objectid/identifier that is assigned to the user will not be identical. We would still run into the same error when attempting to remove the user from CUC (per testing in Lab on CCM 10.5.2Su9). So because we are limited in our options the next best bet is to run a user deletion through the database. For this, we'll need the CLI. See below for the pre/post verification steps, as well as the deletion process.

## Step 1

Verify in CCM that the user we are failing to delete no longer exists in the Database (which is expected). For this, we should see a blank response as shown below. Use the end user 'alias' that is defined in CUC, as this will be identical to what was in use in CCM before the user was deleted from CCM. For this example, 'veronica.hernandez'

```text
run sql select userid, pkid from enduser where userid = 'veronica.hernandez'

userid pkid 
====== ====

```

## Step 2

Perform a query against the CUC Publisher to pull the given user's object id. We can also run a more general query to get the same, but additional data as shown in the second query. Store the 'objectid', in this instance 'bad09f3d-c1a9-480a-ac2a-08043039f341' as it will be needed in further commands.

```text
run cuc dbquery unitydirdb SELECT ObjectId from vw_User where ALIAS = 'veronica.hernandez'

objectid
------------------------------------
bad09f3d-c1a9-480a-ac2a-08043039f341
```

```text
run cuc dbquery unitydirdb select * from tbl_Globaluser where Alias = 'veronica.hernandez'

objectid                              altfirstname  altlastname  displayname         dtmfnamefirstlast  dtmfnamelastfirst  firstname  lastname   listindirectory  locationobjectid                      streamfileobjectid                    xferstring  istemplate  city  department  alias               dtmfaccessid  partitionobjectid                     dignetobjectid                        dignetobjectidtimestamp  placeholderdatetimeutc
------------------------------------  ------------  -----------  ------------------  -----------------  -----------------  ---------  ---------  ---------------  ------------------------------------  ------------------------------------  ----------  ----------  ----  ----------  ------------------  ------------  ------------------------------------  ------------------------------------  -----------------------  ----------------------
bad09f3d-c1a9-480a-ac2a-08043039f341  null          null         Veronica Hernandez  8376642243762633   4376263398376642   Veronica   Hernandez  1                7dcd1a6e-0e4f-4d57-bdd5-4eb8b14444af  e3db4398-e0e6-4ef2-bdd5-a07e19759b20  null        0           null  null        veronica.hernandez  9252654       3814074e-173b-4a0e-8bb7-278b36de33d4  bad09f3d-c1a9-480a-ac2a-08043039f341  0                        null
```

## Step 3

Verify there are no outstanding dependencies for the given user on CUC. This will make sure the user is not bound to a system call handler.

### CLI

```text
run cuc dbquery unitydirdb select objectid from tbl_callaction where targethandlerobjectid IN (select callhandlerobjectid from vw_subscriber where alias='veronica.hernandez')

No records found
```

### GUI

```text
0 dependencies successfully found for Veronica Hernandez.
```

## Step 4

Run a csp_UserDelete operation using cuc dbquery/SQL against the objectid that was pulled previously for the given user. This will perform a deletion as we would expect.

```text
run cuc dbquery unitydirdb EXECUTE PROCEDURE csp_UserDelete (pObjectId = 'bad09f3d-c1a9-480a-ac2a-08043039f341')

Rows: 0
```

## Step 5

Perform the same command as used in Step 2, either against vw_User table or tbl_Globaluser. We should see no records found, as the references to the objectid should be deleted now.

```text
run cuc dbquery unitydirdb SELECT ObjectId from vw_User where ALIAS = 'veronica.hernandez'

No records found
```

## Step 6

Verify in the GUI that the given user no longer appears.  As this example showed an old format (first.last) and new format (random-ish) username, we can see the newer format 'hernanvr' is still maintained but 'veronica.hernandez' is now deleted, and the extension previously assigned can again be used within CUC.

<span class="image fit"><img src="{{ "/assets/images/ccmsync4.png" | absolute_url }}" alt="" /></span>

And there we go. A breakdown in proper process for user deletions results in a multi-step action against the database. Not exactly desirable, but the method exists for a reason. Ideally we would prefer that all user deletions, additions, modifications take place in proper order with all possible considerations made before action is taken... but... we live in the real world, which is why it's important to know about these alternate methods of tackling the issues we face.

I truly hope that this has been informative and helpful, showing the powerful ability that we have with direct access to the informix database, and how we can use that ability to tackle the issues we face as system admins, UC engineers and the like.

Have an idea on a blog post topic? Have further detail, or questions? Drop a comment on the post! Follow and tweet at me on twitter (@kperryuc), or find me on LinkedIn! Until next post, have a great one!
