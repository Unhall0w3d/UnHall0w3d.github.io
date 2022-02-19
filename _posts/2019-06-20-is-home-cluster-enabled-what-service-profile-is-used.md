---
title: "Home Cluster And Service Profile Check"
layout: post
date: 2019-06-20T08:00:00-05:00
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
  - Jabber
  - Cisco Jabber
  - SQL
  - IM & Presence
  - IM&P
---
## Intent

Pull a list of users where Home Cluster (islocaluser) is Enabled (t) only. Do not display if the user does not have Home Cluster enabled (f). We also want to do the following:

<!--more-->

1. Rename the attributes to be easier to read for those not familiar with the SQL Data Dictionary and possible attributes/relation to real word terminology
2. Inner join with ucserviceprofile table to translate the pkid of the user's service profile with it's actual name, as the enduser table only holds the pkid. The ucserviceprofile table holds the pkid AND name and can be used to relate the two.

## Client Ask/Scenario 1

Client has multiple CUCM clusters in geographically separated areas (EMEA, ASIA, USA, etc.) and users are pulled in from all regions and shared across the clusters. (e.g. EndUser user1 exists on all clusters). This is for mobility reasons as people can be promoted or moved to different business units, travel, etc. and still require certain access. 
One issue that comes up due to this setting is that folks are unable to log into Cisco Jabber due to a "Unable to Communicate with Server" error message. Though there are many things that can cause this (discovery failure, DNS failure, port blockage, etc.) I have found that the first quick check I can do is to ensure that the Home Cluster setting is ONLY enabled on ONE cluster for that user. Enabling this on multiple clusters simultaneously breaks the user's ability to log in.

The specific ask we had was to pull a full list, ONLY for users that had the option Home Cluster enabled, from each cluster's Publisher so that we could compare and contrast more easily to confirm which users had this option enabled on multiple clusters so it could be rectified proactively, and more quickly.

### Query

```text
run sql select eu.userid as ID, eu.firstname as First, eu.lastname as Last, eu.islocaluser as homeCluster, ucp.name as serviceprofile from enduser eu inner join ucserviceprofile as ucp on ucp.pkid=eu.fkucserviceprofile where eu.islocaluser='t' order by eu.userid
```

### Query Output 1

In the output below we can see a few things are provided, including the User ID (id), First Name (first), Last Name (last), that Home Cluster is Enabled (homecluster) and what service profile the user is using. This data was selected for a few reasons:

1. In a large enterprise first and last names are far from unique in a lot of cases. There are more than a few Ken's and a whole bunch of Smith's. We want to make sure we limit our output to just enough that we can get our relevant data (is home cluster enabled, what service profile is used) as well as a way to cross-reference against another cluster's output (userid, first, last).
2. I did not need additional information such as the user's mail id, primary extension, associated devices or anything else. It may be nice to have in a report or general check-up query but was unnecessary for my purposes.

```text
run sql select eu.userid as ID, eu.firstname as First, eu.lastname as Last, eu.islocaluser as homeCluster, ucp.name as serviceprofile from enduser eu inner join ucserviceprofile as ucp on ucp.pkid=eu.fkucserviceprofile where eu.islocaluser='t' order by eu.userid
id first last      homecluster serviceprofile
====== ===== ========= =========== ==============
user1 User 1 t           Jabber_SP
user2 User 2 t           Jabber_Webex_SP
```

## Client Ask/Scenario 2

Sometimes I'll get this ask for a specific user only. As logging into the CLI is faster than navigating to the GUI, waiting for pages to load, etc. etc. I will perform the SQL query against the Pub DB on each cluster to confirm that the user isn't enabled in multiple spots. There is additional information in the enduser table that could be pulled should it be useful for your use case, such as a mail id, primary extension or otherwise. I didn't need that much detail for this request but I did want to include the userid, first and last name to ensure we got the right user info.

### Modified Query

The query was modified by adding the "and eu.userid='user1'" statement in order to limit our output to just the one user we want. Unlike the previous ask we don't want to pull a full report for all users, we just want a quick and easy way to verify the setting against a single problematic user.

```text
run sql select eu.userid as ID, eu.firstname as First, eu.lastname as Last, eu.islocaluser as homeCluster, ucp.name as serviceprofile from enduser eu inner join ucserviceprofile as ucp on ucp.pkid=eu.fkucserviceprofile where eu.islocaluser='t' and eu.userid='user1' order by eu.userid
```

### Return

#### Cluster 1

```text
run sql select eu.userid as ID, eu.firstname as First, eu.lastname as Last, eu.islocaluser as homeCluster, ucp.name as serviceprofile from enduser eu inner join ucserviceprofile as ucp on ucp.pkid=eu.fkucserviceprofile where eu.islocaluser='t' and eu.userid='user1' order by eu.userid

id first last homecluster serviceprofile
== ===== ==== =========== ==============
<no return>
```

The reason we get no return is because we are looking for these details where eu.islocaluser='t'. If Home Cluster is disabled ('f'), we shouldn't get a return, (and we don't).

#### Cluster 2

```text
run sql select eu.userid as ID, eu.firstname as First, eu.lastname as Last, eu.islocaluser as homeCluster, ucp.name as serviceprofile from enduser eu inner join ucserviceprofile as ucp on ucp.pkid=eu.fkucserviceprofile where eu.islocaluser='t' and eu.userid='user1' order by eu.userid

id     id first last      homecluster serviceprofile
====== ===== ========= =========== ==============
user1 User 1 t           Jabber_SP
```

And there we go! Not only can we pull data en masse from multiple clusters and compare as needed we can also perform single user information pulls to validate the configuration more quickly without needing to log all the way in to the GUI and navigate around. Have a few users? No problem! We can expand this out with an OR statement, or change what we're searching by.

Ensure you insert the relevant parameter within the ticks below! Remember, you can always pull in additional data such as department or otherwise and include that as a search parameter as well.

## Query Modification Ideas

### Quick replacements for "eu.userid=''" as a search parameter after "where"

```text
ucp.name='' (Everyone with the Service Profile "Jabber_SP"?) 
eu.lastname='' (Everyone with the last name Wells?)
eu.firstname='' (Everybody named Weldon?)
```

That's it for now! Make sure to follow the blog to get alerts on new posts, check out my Twitter (@kperryuc and @thoughtsnoc) where you can also ask UC and DC related questions, suggest post topics, get updates on the latest posts and chat!
