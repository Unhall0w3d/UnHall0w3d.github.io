---
title: "Check Call Forward Configs Using SQL"
layout: single
date: 2019-07-08T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - SQL
  - Cisco
tags:
  - Informix
  - Cisco Callmanager
  - Cisco
  - Cisco UC
  - Call Manager
  - Reports
  - Unified Communications
  - Database
---

## How to Check CFWD Configs using SQL - Faster

There's an SQL query I run against CUCM Pub in instances where a user has call forward enabled and I have a suspicion this is causing the problem, but I don't always want to build out an SSH port forwarding tunnel to get into the GUI and check. This can be used when you want to check a single user, or, for every call forward enabled in the environment.

<!--more-->

What's useful about this query is that it will report back call forwards enabled on a specific line, but will also tie that line to the specific device name (CSF, CIPC, SEP, etc.) where it is enabled, so we can glean information about shared lines from this query as well.

## What is our mission?

To pull a list of phones (SEP, CSF, CUIC, CIPC, etc.) that have call forward enabled on an associated line.

## Relevant Data/Attributes and Tables

As with many of the queries I run, I like to define the attributes I am pulling from the Informix DB to be easier to understand and so that the data can be conveyed to a client, architect, whoever without much/any modification or manipulation. In this case we are dealing with the following attributes and tables:

### Attributes

The attributes listed below are used to pull a device name, the relevant assigned DN(s) and the Call Forward All destination associated with the same line. This requires pulling the names, pkid, fknumplan data to correlate and give us the desired output.

```text
------------
d.name
d.pkid
------------
n.dnorpattern
n.pkid
------------
cfd.cfadestination
cfd.fknumplan
------------
dmap.fknumplan 
```
 

### Tables

```text
device (contains data relating to the actual phone)
devicenumplanmap (contains an ordered association of numplan records with a device (line appearance))
numplan (list of all directory numbers and patterns) 
callforwarddynamic (frequently updated settings for call forward all) [read only]
```

## Query 1

```text
run sql select d.name as device, n.dnorpattern, cfd.cfadestination from device as d inner join devicenumplanmap as dmap on dmap.fkdevice = d.pkid inner join numplan as n on n.pkid=dmap.fknumplan inner join callforwarddynamic as cfd on cfd.fknumplan=n.pkid where (cfd.cfadestination != '')
```

## Query 1 Output

Below is the expected return (nothing) when there is no Call Forward All enabled in the environment at all.

```text
run sql select d.name as device, n.dnorpattern, cfd.cfadestination from device as d inner join devicenumplanmap as dmap on dmap.fkdevice = d.pkid inner join numplan as n on n.pkid=dmap.fknumplan inner join callforwarddynamic as cfd on cfd.fknumplan=n.pkid where (cfd.cfadestination != '')

device dnorpattern cfadestination
====== =========== ==============
```

## Query 2 - Target a Specific Phone

Now say I wanted to only run this query against one user, how would we modify it? We would add "and d.name='<devicename>'" and substitute the <devicename> for the actual name of the device, whether it be the SEPMAC or CSF or CIPC name.

```text
run sql select d.name as device, n.dnorpattern, cfd.cfadestination from device as d inner join devicenumplanmap as dmap on dmap.fkdevice = d.pkid inner join numplan as n on n.pkid=dmap.fknumplan inner join callforwarddynamic as cfd on cfd.fknumplan=n.pkid where (cfd.cfadestination != '') and d.name='CIPCJSMITH'

device     dnorpattern   cfadestination
========== ============= ============== 
CIPCJSMITH +12223334444 345 CIPCJSMITH +13334445555 331
```

### Query 3 - Target a Specific DN

What about wanting to get a return given a specific DN? Well we can do that too. In this case we would modify the query to include "and n.dnorpattern ='<dn>'" and substitute the <dn> with the actual DN assigned to one or more phones. This is where we can isolate issues to one phone or many (due to shared line configs).

```text
run sql select d.name as device, n.dnorpattern, cfd.cfadestination from device as d inner join devicenumplanmap as dmap on dmap.fkdevice = d.pkid inner join numplan as n on n.pkid=dmap.fknumplan inner join callforwarddynamic as cfd on cfd.fknumplan=n.pkid where (cfd.cfadestination != '') and n.dnorpattern ='+13334445555'

device     dnorpattern   cfadestination
========== ============= ==============
CIPCKPERRY +13334445555 331  CIPCJSMITH +13334445555 331
```

That's it for now! Make sure to follow the blog to get alerts on new posts, check out my Twitter (@kperryuc) where you can also ask UC and DC related questions, suggest post topics, or talk about anything!
