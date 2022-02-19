---
title: "Identifying Static Phone Loads With SQL"
layout: single
date: 2019-06-21T08:00:00-05:00
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
## Intent
As part of the process of upgrading phones to new firmware I've formed a habit of verifying if there are any phones of the particular model (or models) that I'm upgrading that have a static phone load assignment. Now, there's a few reasons you might want a static phone load including but not limited to:

<!--more-->

1. Testing a new firmware load on a pilot/test device to ensure no new bugs pop up
2. Specific request, this might be a request from a VP or C-level management due to a new feature (hello Cisco 8851's Enhanced Line Mode).
3. Manual downgrade due to a bug

The thing with manual phone loads is just that -- they're manually assigned. It doesn't care that you've upgraded away from an older firmware. We could run a batch job using BAT to blank out the phone loads anyway and not care about looking at the phone load assignments, but who jumps ahead without verifying? Well, some of us for various reasons, BUT, it's a good habit to form to verify verify verify before we put a plan into action. That said, I have a query I run against the CCM Pub to confirm which phones have a static phone load so I can deal with them on a one-by-one basis. (e.g. do we need to keep X user's phone load statically assigned due to feature/design (GUI) changes (usually a VP or C level exec), etc.)

## Relevant Data/Attributes and Tables

As with many of the queries I run, I like to define the attributes I am pulling from the Informix DB to be easier to understand and so that the data can be conveyed to a client, architect, whoever without much/any modification or manipulation. In this case we are dealing with the following attributes and tables:

### Attributes

```text
d.name as MACAddress

d.specialloadinformation as PhoneLoad (this is what we're after, but we need the rest to relate it to which phone/who owns it)

d.description as DeviceDescription (this provides us, provided we put proper descriptions in, to quickly identify an owner)

n.dnorpattern as DN (DN's aren't required, and in fact, will produce duplicate entries for phones that have multiple lines. I like having this information as when I provide these details to a client, if they are unsure they can call the user directly and ask if there was a reason this was implemented. You'd be surprised how often the admins aren't sure. They usually aren't sure. 🙂 ) We can remove the dnorpattern field and I'll note how we can modify this query as well!
```

### Tables

```text
device as d
numplan as n
devicenumplan as dnpm
```

### Conditions

```text
dnpm.fkdevice = d.pkid (relate the pkid of a device to the pkid of the entry in devicenumplanmap. If the device does not exist within both tables, ignore it)

dnpm.fknumplan = n.pkid (relate the pkid of a dnorpattern to the pkid of the entry in devicenumplanmap. If the number does not exist, ignore it)

d.tkclass = 1 (device must be a phone, not a CUCI, CSF, BOT or otherwise)

d.specialloadinformation = !'' (static phone load field must not be empty)
```

## Query

```text
run sql select d.name as MACAddress, d.specialloadinformation as PhoneLoad, d.description as DeviceDescription, n.dnorpattern as DN from device as d, numplan as n, devicenumplanmap as dnpm where dnpm.fkdevice = d.pkid and dnpm.fknumplan = n.pkid and d.tkclass = 1 and d.specialloadinformation != ''
```

### Client Ask/Scenario 1

Typically our request comes in one of three ways. The client wants to update their phone firmware to the latest because who doesn't want to be on the latest firmware? (Well, turns out some folks don't. I've run into clients that refuse to use the latest firmware unless it's been out for >6 mo... but that's a whole other can of worms). The client or I suggest upgrading to the latest firmware to rule out existing firmware as the cause for a specific phone behavior that is not explained by CUCM configuration or expressed in Cisco CallManager traces. Finally, we confirm that we have hit a bug and are required to upgrade the firmware to mitigate the bug. Regardless of how the upgrade discussion comes about, there's some pre-work we want to complete. Part of that pre-work involves verifying if any of the endpoints we're about to upgrade are going to ignore the Device Defaults entry due to a static phone load. If so, does it need to stay or can we blank it out. This query gives us a "less than" 3 minute turnaround time on gathering the required data while we're on a call with our client.

### Return

With the return below we can see three returns, but only two devices. We can take this data and, say we're upgrading 88xx firmware to 12.5(1)SR3. We can blank out the phone load for that particular user manually. Save. Perform our firmware upgrade. Reset the device(s) and not have to worry about a phone being on an old [bugged|undesired] firmware load. Quick, easy, simple.

```text
run sql select d.name as MACAddress, d.specialloadinformation as PhoneLoad, d.description as DeviceDescription, n.dnorpattern as DN from device as d, numplan as n, devicenumplanmap as dnpm where dnpm.fkdevice = d.pkid and dnpm.fknumplan = n.pkid and d.tkclass = 1 and d.specialloadinformation = ''

macaddress      phoneload                  devicedescription                                       dn
=============== ========================== ======================================================= =====
SEPAAAAAAAAAAAA sip88xx.12-0-1SR1-1        VPN - USER 1 - 8851                      7444
SEPAAAAAAAAAAAA sip88xx.12-0-1SR1-1        VPN - USER 1 - 8851                      78444
SEPAAAAAAAAAAAB sipdx650.10-2-3-33         Boulder - Desk Alpha - DX650                                7478
```

## Modified Query

Here we modify the query to remove any DN information, and thus simplify the query and dip into less tables. This could satisfy most requests and unless there is a need (or want) for the DN information this could be used in the original queries place.

```text
run sql select d.name as MACAddress, d.specialloadinformation as PhoneLoad, d.description as DeviceDescription from device as d where d.tkclass = 1 and d.specialloadinformation != ''
```

### Modified Query Output

```text
macaddress phoneload devicedescription
========== ========= =================
SEPAAAAAAAAAAAA sip88xx.12-0-1SR1-1        VPN - USER 1 - 8851
SEPAAAAAAAAAAAA sip88xx.12-0-1SR1-1        VPN - USER 1 - 8851
SEPAAAAAAAAAAAB sipdx650.10-2-3-33         Boulder - Desk Alpha - DX650
```

If anyone is interested in a full break down of my pre/post upgrade verification steps, and/or the firmware upgrade process I follow let me know! I may do a series on upgrades from servers to endpoints in the future, knowing you're looking for it helps me set a priority on it.

That's it for now! Make sure to follow the blog to get alerts on new posts. Also check out my Twitter (@kperryuc) where you can also ask UC and DC related questions!
