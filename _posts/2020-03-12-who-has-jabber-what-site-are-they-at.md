---
title: "Who has Jabber? Where are they?"
layout: single
classes: wide
date: 2020-02-20T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Unified Communications
  - SQL
  - Cisco
tags:
  - Cisco Unified Communications Manager
  - Cisco
  - Cisco Jabber
  - Database
  - SQL
  - Unified Communications
---

## Who Is Your Father And What Does He Do?

The requests just keep coming... and always for a slightly different set of information requiring the combination of multiple SQL queries or the development of a new one if I don't have a base query to build off of.

<!--more-->

For this request the title says it all - who has a Jabber profile/uses Jabber and what site are they at? But wait, just as I thought this request was complete, like a self-fulfilling prophecy another set of data was requested. Take a look below to see what was added to the query and what the output looks like once we make the change.

The answer is straight forward, but also not... depending on how granularly you build out certain configurations such as Device Pools. Does your BUE_DP actually mean Buenos Aires, or does it include 3 or 4 surrounding sites that, even though they share a config should be tracked separately? I don't know! But you should. And that is where the beauty is for some of these data pulls. I get you the data that meets your ask, but the real trouble (which is usually on the requester, or some data manipulation folk) is understanding some of the nuances to site naming conventions, site grouping based on geography, etc.

So here we go, how do we go about pulling information on who has a Jabber Profile or is enabled for Jabber (without looking at specific CSFs, as some don't have phone profiles) within UCM? Well, we have a query for that already that we can modify or build off of to satisfy this request. We talked about it [in this post](https://nocthoughts.com/2019/06/20/is-home-cluster-enabled-what-service-profile-is-used.html).

## Root Query - Where It All Starts

```text
run sql select eu.userid as ID, eu.firstname as First, eu.lastname as Last, eu.islocaluser as homeCluster, ucp.name as serviceprofile from enduser eu inner join ucserviceprofile as ucp on ucp.pkid=eu.fkucserviceprofile where eu.islocaluser=’t’ order by eu.userid
```

This query pulls the userid, first name, last name, home cluster setting, and what service profile is associated to that user. This is a start. From here, I want to rip out the first and last names and in place of that I want to include the device name (d.name as devicename), and the associated device pool (dp.name as devicepool). But we have to do this in relation to what's associated, so here we need to relate the device pool to the device, and the device to the end user. We do this by inner joining fkdevice in enduserdevicemap against the pkid in device, fkenduser in enduserdevicemap against the pkid in enduser, and fkdevicepool in device against the pkid in devicepool. Sounds like a lot, right? Well, let's work out the syntax.

## Query Update 1 - Adding Some Relationships

```text
run sql select eu.userid, d.name as devicename, dp.name as devicepool, eu.islocaluser as homecluster, ucp.name as serviceprofile from device as d inner join devicepool as dp on d.fkdevicepool=dp.pkid inner join enduserdevicemap as eudm on eudm.fkdevice=d.pkid inner join enduser as eu on eudm.fkenduser=eu.pkid inner join ucserviceprofile as ucp on ucp.pkid=eu.fkucserviceprofile where eu.islocaluser='t' order by eu.userid
```

For good measure we'll sort by userid, but it's not entirely necessary. Below is the output, in my example I have one user configured with a few test devices, in production this should return many more results.

```text
userid devicename devicepool homecluster serviceprofile
====== =============== ============= =========== ======================
kperry SEPCCBBAACCBBAA Remote_EST_DP t Test-ServiceProfile
kperry CUCIkperry Remote_EST_DP t TestServiceProfile
kperry CIPCKPERRY Remote_EST_DP t Test-ServiceProfile
```

So what we end up with is multiple entries based on userid (as there's multiple devices associated to the user). In plain text, what we look for/get back is:

```text
The user
What device is assigned to them (which is relevant to find...)
The device pool associated to that device (which is relevant to find...)
The site the user is at
ONLY FOR...
Users that have Home Cluster enabled, and thus have a Jabber profile.
```

## Initial Request Expanded

After sending the manipulated data in .xlsx format over to the client an amendment was made to the original request. Something to the effect of "This is great, but can we also see what extension is assigned to these users?" Well... sure. We can do that. My initial thought was to simply pull a report of all End Users with a line level association. That was until I realized that the client did not have a firm strategy of assigning lines to the users that owned them. I then decided to simply alter my original query and pull some additional data from the devicenumplanmap and numplan tables to relate the extension(s) assigned to the given devices we've already pulled data for. Let me show you.

So without the entire command syntax, what I am very interested in is pulling dnorpattern from the numplan table. To related this to the devices assigned to the users, I need to perform two additional inner joins.

```text
inner join devicenumplanmap as dmap on dmap.fkdevice=d.pkid

inner join numplan as n on dmap.fknumplan=n.pkid
```

What these allow us to do is compare and combine the foreign key (device) in devicenumplanmap against the pkid in the device table, then, we compare and combine the foreign key (numplan) in devicenumplanmap against the pkid in the numplan table. So what does this look like as a query? I'll display the query a little bit differently, as if in sections as it helps me to visualize the statements.

## Query Update 2 - Adding User Extension Assignments

```text
run sqlselect eu.userid, d.name as devicename, dp.name as devicepool, eu.islocaluser as homecluster, ucp.name as serviceprofile, n.dnorpattern as DN from device as dinner join devicepool as dp on d.fkdevicepool=dp.pkidinner join enduserdevicemap as eudm on eudm.fkdevice=d.pkidinner join enduser as eu on eudm.fkenduser=eu.pkidinner join ucserviceprofile as ucp on ucp.pkid=eu.fkucserviceprofileinner join devicenumplanmap as dmap on dmap.fkdevice=d.pkidinner join numplan as n on dmap.fknumplan=n.pkidwhere eu.islocaluser='t'order by eu.userid
```

And what does the output then look like? Well, it looks like this:

```text
userid devicename devicepool homecluster serviceprofile dn
====== =============== ============= =========== ====================== =====
kperry SEPE0899DFA7228 Remote_EST_DP t Test-ServiceProfile 1234
kperry SEPE0899DFA7228 Remote_EST_DP t Test-ServiceProfile 52289
kperry CUCIkperry Remote_EST_DP t Test-ServiceProfile 1234
kperry CIPCKPERRY Remote_EST_DP t Test-ServiceProfile 1234
kperry CIPCKPERRY Remote_EST_DP t Test-ServiceProfile 52047
```

And there we go. If the way we configure CUCM and our regions, locations, device pools and such are site specific, this becomes incredibly easy. If we just generically make "US_DP", well, those users are in the U.S. but whether they are in Anaheim CA, Boulder CO, or Albany NY isn't readily available and would require additional digging against external documentation, or a more complex query to take into account a specific value in the EndUser Profile that may relate what site they are at (if that's updated/correct). 

Now, as we move forward I will be looking to transition my queries away from direct SQL and rather through SOAP/AXL or relevant APIs where available. This will take quite a bit of learning as I am not classically/formally trained in any form of programming or scripting, and what I don't use semi-often I generally don't retain, so it's like starting from scratch. But I am very excited to start sharing those new posts with you as soon as they are ready!

I hope this was informational, or useful to you and thank you for stopping by! Give the @ThoughtsNOC Twitter account a follow for updates when posts go live, are updated, to chat, or even suggest future post ideas! I can also be found on LinkedIn @kperryuc.
