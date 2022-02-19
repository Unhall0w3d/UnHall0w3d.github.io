---
title: "Dial Plan Dump using SQL"
layout: single
date: 2019-07-21T08:00:00-05:00
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

So given that I work for a Virtual NOC/MSP in a Day 2 setting it's fairly often that I'm thrown into a random request for data. It could be for the Home Cluster enablement on a given (or all) End Users on UCM (we have a post for that!) or it could be for a dump of all the dialable numbers in the environment, or all route patterns.. or anything. This query is one I like to use when the meat and potatoes of what we need is the DN/Pattern, Description, and possible modifications that would take place during digit analysis.

<!--more-->

## Purpose

1. What do the egress route patterns look like? Do we prefix any digits in the pattern (e.g. 8, 9)? If we do prefix, do we prefix before a dot? If so, we must be discarding PreDot. (If not there's probably an issue!).
2. What do our used internal DNs look like? This is usually in an environment where DIDs are not assigned to users and instead internal DNs are used.
3. What translation patterns do we have and what are they doing? Do we add site codes or similar when we translate a 4 or 5 digit number?

With just a little bit of data you can get a big picture into how an environment operates and is designed.

## Intent

To pull all DNs, Translation, Transformation and Route Patterns as well as their associated Partition (so duplicate DNs in different Partitions show as well), whether they discard digits (e.g. PreDot), what digits are Prefixed, and what the Called Party Transformation is, if set.

## Relevant Data/Attributes and Tables

As with many of the queries I run, I like to define the attributes I am pulling from the Informix DB to be easier to understand and so that the data can be conveyed to a client, architect, whoever without much/any modification or manipulation. In this case we are dealing with the following attributes and tables:

### Attributes:

```text
n.dnorpattern as dnorpattern -- This is all pattern and DN info
rp.name as partition -- This is the partition name
ddi.name as DiscardDigits -- This is the digits to discard (e.g. PreDot) if configured
n.prefixdigitsout as PrefixDigits -- This is the digits to prefix, if configured
n.calledpartytransformationmask as CalledPartyXForm -- This is the called party transformation mask to apply, if configured
n.description as description -- pattern description
```

### Tables

```text
numplan as n
routepartition as rp
```

### Conditions

```text
on n.fkroutepartition=rp.pkid  -- partition is translated via pkid
left join digitdiscardinstruction table -- Left join with the discarddigitinstruction table
on n.fkdigitsdiscardinstruction=ddi.pkid -- discard digits are translated via pkid
order by n.dnorpattern -- put the results in order of translation pattern, starting with nothing/empty --> symbols --> numbers.
```

## Query

```text
run sql select n.dnorpattern as dnorpattern, rp.name as Partition, ddi.name as DiscardDigits, n.prefixdigitsout as PrefixDigits, n.calledpartytransformationmask as CalledPartyXForm from numplan as n left join routepartition as rp on n.fkroutepartition=rp.pkid left join digitdiscardinstruction ddi on n.fkdigitdiscardinstruction=ddi.pkid order by n.dnorpattern
```

## Use Case / Scenario

In scenarios where I need to perform an audit of an environment's dial plan from a base level, I like to run this query to get a quick idea of what patterns and DNs we have and how the modification settings are set. I don't use this query in instances where I'm looking for data about where calls are routing, obviously, as there's no Route Group // Route List configuration details shown. We'll go over that in another post.

### Command & Output

```text
run sql select n.dnorpattern as DNorPattern, n.description, rp.name as Partition, ddi.name as DiscardDigits, n.prefixdigitsout as PrefixDigits, n.calledpartytransformationmask as CalledPartyXForm from numplan n left join routepartition rp on n.fkroutepartition=rp.pkid left join digitdiscardinstruction ddi on n.fkdigitdiscardinstruction=ddi.pkid order by n.dnorpattern

dnorpattern                                  description                                       partition                            discarddigits prefixdigits calledpartyxform
============================================ ================================================= ==================================== ============= ============ ================ 
!                                            VZ SIP Xlat pattern to reach black list           Global-Inbound-PT                    NULL  
!                                            Default route for non-matched black list#s Global-Filter-Passthrough-PT                NULL  
1[2-9]XX[2-9]XXXXXX                          NANP 11-Digits to E164                            PT_PSTN                              NULL          NULL         NULL  
9.1[2-9]XX[2-9]XXXXXX                                                                          PT_PSTN                              PreDot  
[2-9]XX[2-9]XXXXXX                           NANP 10-Digits to E164                            PT_PSTN                              NULL          NULL         NULL  
+!                                           Screen all calls by ANI                           Global-Inbound-PT                    NULL  
+!                                           Default route for non-matched black list#         Global-Filter-Passthrough-PT         NULL
```

Have a go to query for your dial plan analysis and review? Let me know! Leave a comment! Make sure to follow the blog to get alerts on new posts, check out my Twitter (@kperryuc) where you can also ask UC and DC related questions, suggest post topics, or talk about anything!
