---
title: "Finding Orphaned Devices & Device Profiles"
layout: single
date: 2019-11-06T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Unified Communications
  - Cisco
  - SQL
tags:
  - SQL
  - Cisco
  - Cisco UC
  - Unified Communications
  - Informix
  - Database
  - Cisco Callmanager
---

## A New Query Approaches!

I have to admit, I haven't been doing much SQL work lately as... due to the holidays and other factors... it's been pretty quiet. The occasional phone firmware upgrade here, troubleshooting call quality/audio routing issues there, and some Cisco Unity SMTP Smart Host and assorted issues sprinkled throughout the past few weeks.<!--more--> So imagine my delight (hehe) when asked by a colleague about an SQL query to find devices that do not have an end user assignment.

<span class="image fit"><img src="{{ "/assets/images/orphaneddevices1.png" | absolute_url }}" alt="CCM Data Dictionary for 'device' table." /></span>

What I'm going to show you is a quick and lazy way of pulling the data, followed by a more concise way of pulling what we need. The lazy way will require we use Excel (or Sheets, or other applicable data manipulation program).

## What are we doing?

To pull a list of Devices (IP Phones, Device Profiles) wherein there is no end user assignment. This can be cross-checked by opening the Device and checking the Dependency Records and seeing that there is no End User listed.

We want to be able to account for licensing when it comes to device associations. For example, we want to assign all conference phones to a single "Conference User" to utilize less licensing overall.

We want to ensure we have proper asset tracking by knowing what user has control over what devices.

We want to be able to identify devices/device profiles for deletion/re-purposing if they are unregistered and the end user no longer exists.

## Relevant Data/Attributes and Tables (Query 1)

As with many of the queries I run, I like to define the attributes I am pulling from the Informix DB to be easier to understand and so that the data can be conveyed to a client, architect, whoever without much/any modification or manipulation. In this case we are dealing with the following attributes and tables:

### Attributes

- d.name - Device Name/MAC Address. (e.g. CUCIFLAST, CSFFLAST, SEPAAAABBBBCCCC, TCTFLAST, BOTFLAST)
- d.description - Description placed on the given device, usually denotes user name and extension, physical location, or hotel phone.
- d.fkenduser - Extension Mobility user, or, if EM not used, associated end user.

### Tables

- device as d - Device table, contains everything for all devices from SIP Trunks to EM Profiles to Gateways to Phones.

### Conditions

- None

### Query 1

```text
run sql select d.name as MAC, d.description as Description, d.fkenduser as EndUser from Device as d
```

### Scenario

For this particular query what we are looking for is the EndUser (d.fkenduser) field to show NULL where an end user assignment does not exist. This isn't exactly clean, but it works.

```text
run sql select d.name as MAC, d.description as Description, d.fkenduser as enduser from Device as d
```

```text
mac                                                description                                             enduser
================================================== ======================================================= ====================================
CIPCJHARTMAN                              Jack Hartman - CIPC                                     0e08f1ac-f136-bb5e-bdb2-a582054756c6
SEPD0C789D7B328                                    Hotel BOLCO - 7962                                      c029bf68-3b1a-4f23-bde6-98466fe5dc3d
EMJDOE                                         Jane Doe - EM                                    NULL
```

Now, given that this list would typically be much longer we would want to copy/paste the output from CUCM into Excel such that the Mac, Description, and EndUser columns exist. This may require some manipulation of the output so that we can cleanly use Space separation for generating our columns. If you're not a workable excel user, you may want to go another route with this.

We would then select the enduser column (C in this case), and select "Sort & Filter" --> "Filter". This'll add a filter button.

Finally we would filter for "NULL", and that would leave us with our list of phones.

## Relevant Data/Attributes and Tables (Query 2)

### Attributes

- d.name - Device Name/MAC Address. (e.g. SEPAAAABBBBCCCC, EMFLAST)
- d.description - Description of the device.
- eudm.pkid - Device PKID found within the EndUserDeviceMap table. This will be used to check that the user association count is "0" and thus the device is unassigned.
- eudm.fkdevice - End user association to devices and device profiles by way of the EndUserDeviceMap table.
- d.tkclass - Device Class we are looking at within the Device table. 

Possible tkclass values are listed below with their real world names. This can be found via "run sql select name, enum from TypeClass" -- THANKS MATT!

```text
1 = IP Phone
2 = MGCP Analog Port (AALN/S0/SU0/0@HOSTNAME.DOMAIN.COM)
4 = Conference Bridge Resource
5 = Media Termination Point
7 = Route/Hunt List
8 = Voicemail Port (SCCP)
10 = CTI Route Point
12 = Music on Hold14 = Pilot
15 = GateKeeper
16 = Add-on Modules
18 = SIP Trunk
19 = Annunciator
20 = Remote Destination Profile
248 = EMCC Base Phone Template
249 = EMCC Base Phone
250 = Remote Desintation Profile Template
251 = Gateway Template
252 = UDP Template
253 = Phone Template
254 = Device Profile
301 = IVR
```

### Tables

- device as d
- enduserdevicemap as eudm

### Conditions

- (0=(select count(eudm.pkid) from enduserdevicemap as eudm where eudm.fkdevice=d.pkid)) -- Where the Device Association within the enduserdevicemap MAPPING table is "0"
- (d.tkclass=254 or d.tkclass=1) -- Where the device type is either IP Phone or Device Profile

### Query 2

```text
run sql select d.name, d.description from device as d where (0=(select count(eudm.pkid) from enduserdevicemap as eudm where eudm.fkdevice=d.pkid)) and (d.tkclass=254 or d.tkclass=1) order by d.name
```

### Scenario

In this particular query, we get what we're looking for. IP Phones (CUCI, CSF, TCT, BOT, SEP, CIPC) and Device Profiles(DP/EM) where the device association count is 0. This doesn't get fancy and "IF NOT 0", associate the phone to the user. There are separate queries for that that we can cover in another post.

```text
run sql select d.name, d.description from device as d where (0=(select count(eudm.pkid) from enduserdevicemap as eudm where eudm.fkdevice=d.pkid)) and (d.tkclass=254 or d.tkclass=1) order by d.name
```

```text
name                                               description
================================================== ======================================================
ATA00778D34E8C0                                    BOLCO - Main Fax - 3333
Auto-registration Template                         #FirstName# #LastName# (#Product# #Protocol#)
BOTJDOE                                         Jane Doe - Samsung Galaxy Tab 3
CIPJHARTMAN                                         Jack Hartman - CIPC
SEP003094C3393C                                    Hotel Phone - 7960
EMJHARTMAN                                           Jack Hartman - EM
TCTJHARTMAN                                        Jack Hartman - 1139 
```

So there we go. We can take this data and cross reference devices/EM profiles against the list of users (because we should always document this stuff as we build it out, if we're part of the MACD team, or if MACDs are in our job description! Trust me, it saves lives!) and get them properly associated for proper License and ownership tracking.

I hope this has been helpful, I sure did refresh myself working through these examples with my colleague. It wasn't in my tool bag as a quick go-to query, but it sure is now!

That's it for now! Make sure to follow the blog to get alerts on new posts, check out my Twitter (@kperryuc) where you can also ask UC and DC related questions, share articles and posts, suggest post topics, or talk about anything!