---
title: "Do You Hear That? It's a Dial Plan Overlap! Run!"
layout: single
date: 2019-07-05T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Unified Communications
  - Cisco
tags:
  - Cisco Callmanager
  - Cisco Unified Communications
  - Cisco
  - Cisco UC
  - Call Manager
  - Reports
  - Unified Communications
  - Dial Plan
---

## User Report & Context

All users at Site A is experiencing issues making calls from Site A (Santarem) in Brazil to Site B when calling from Cisco IP Phone. When calling from Cisco Jabber the call works fine.

<!--more-->

### Relevant Call Flow

```text
SIP Phone --> CUCM --> H.323 GW --> E1 via R2-Digital signaling (Voice-Ports, not Serial!)
```

### Initial Steps

1. Collect a call example

    ```text
    Calling Party: (e.g. +559335552222)
    Called Party: (e.g. +559198886666)
    Date/Time: 3:45PM EST 7-04-19
    Result: Your call cannot be completed as dialed.
    ```

2. Review the user report for any relevant information as to what might be causing the problem.

    ```text
    -Indicating that the call fails from Cisco IP Phone but works from Jabber for all users points me away from a configuration issue from the perspective of, say, the CSS configurations. This is because the expectation is that a user's Jabber and Phone have identical calling permissions, so it wouldn't make sense for one to work and the other to not work for all users given this expectation.
    -Indicating that the call fails from Cisco IP phone but works from Jabber makes me think of digit-by-digit vs en bloc dialing. The common expectation when dialing from a Cisco IP Phone is that a user will pick up the handset and get dial tone, then dial the digits one-by-one for the number they intend to reach. From Jabber's perspective we just type in the full number we want to dial and hit call. There is no prompt for dial-tone and digit acceptance.
    -Given the above my presumption is that there is an overlap in the dial plan causing users dialing out to hit an undesired pattern (probably due to Urgent Priority) and thus causing the call to fail.
    ```

3. Reproduce the issue to get a current sample that will exist within UCM traces, and debug the egress gateway as well while we have the user on the phone. We are not able to reproduce the issue without the client (due to a lack of jumpbox access, or proper hardware/software provisioned to do so).

Now you might be saying "Woah, woah. Slow down. You're making guesses at what's causing the issue before you've even looked at anything! You're a mad man! You can't do that!" Well, you're right, and you're wrong. I can as long as I don't let it distract me and become my focus point as you would be correct -- it can lead me down a rabbit hole and away from a potential root cause. So this is where we back up and take a look at all the information we have.

## Analysis and Review

So by now the client has responded back with the call example (below) and I have reviewed our billing server for the specific CDR I need.

```text
Calling Party:+559335552222
Called Party:+009198886543
Date/Time: Jul 4th, 14:36
Result: Your call cannot be completed as dialed.
```

From the CDR perspective I see some pretty critical data that confirms my initial thoughts.

1. We see a "Cause Value = 1" on the Destination side of the call (H.323 egress gateway). This tells me that the call made it through call processing on CUCM and was sent to the gateway, where either the VGW or Carrier reported back that the number doesn't exist.
2. The called party presentation is a bit odd. We see the far-right most dialed digit is missing, presenting the called party as "+55919888654". This immediately keys me in to the fact that the call is being sent before all the digits we want to dial are collected. My expectation when taking a look at the debugs pulled is that we will see "+55919888654" rather than our expected "+559198886543" as the called party in the Gateway's signaling as the modification (or omission) was caused by CUCM.

Now for the debugs to confirm my theory; during the troubleshooting call where we reproduce the issue I stood up "debug voip ccapi inout" in order to take a look at call control and the calling/called party presentation. Here we can see the expected modified called party, pointing me back at CUCM (as expected) for the cause of the issue.

```text
Jul  4 14:37:15: //-1/00DD7F5B1F01/CCAPI/cc_api_display_ie_subfields:
    cc_api_call_setup_ind_common:
    cisco-username=Elves Ray
    ----- ccCallInfo IE subfields -----
    cisco-ani=559335552222
    cisco-anitype=0
    cisco-aniplan=0
    cisco-anipi=0
    cisco-anisi=1
    dest=00919888654
    cisco-desttype=0
    cisco-destplan=0
    cisco-rdie=FFFFFFFF
    cisco-rdn=
    cisco-rdntype=-1
    cisco-rdnplan=-1
    cisco-rdnpi=-1
    cisco-rdnsi=-1
    cisco-redirectreason=-1   fwd_final_type =0
    final_redirectNumber =
    hunt_group_timeout =0
Jul  4 14:37:15: //-1/00DD7F5B1F01/CCAPI/cc_api_call_setup_ind_common:    Interface=0x41CA0D78, Call Info(    Calling Number=559335552222,(Calling Name=)(TON=Unknown, NPI=Unknown, Screening=User, Passed, Presentation=Allowed),    Called Number=00919888654(TON=Unknown, NPI=Unknown),    Calling Translated=FALSE, Subscriber Type Str=Unknown, FinalDestinationFlag=TRUE,    Incoming Dial-peer=100, Progress Indication=NULL(0), Calling IE Present=TRUE,    Source Trkgrp Route Label=, Target Trkgrp Route Label=, CLID Transparent=FALSE), Call Id=3048
```

So now we pull traces from CUCM, right? Right. I load up Cisco RTMT and attempt to download the Cisco CallManager traces from the cluster. To my surprise I've already exceeded the retention timer and sdl traces have overwritten, however, I do have call log files that support what I was originally believing the issue to be, an overlapping, shorter pattern.

```text
C:\Users\kenop\Downloads\CCMTraces\Node3\2019-07-04_20-04-25\cm\trace\ccm\calllogs\calllogs_00001146.txt  (4 hits)     
Line 11448: 2019/07/04  14:37:15.142|CC|SETUP|55808087|55808096|user@domain.com|00919888654|00919888654   
Line 11448: 2019/07/04  14:37:15.142|CC|SETUP|55808087|55808096| user@domain.com |00919888654|00919888654    
Line 11449: 2019/07/04  14:37:15.146|CC|OFFERED|55808087|55808096| +559335552222 |00919888654|00919888654|SEP00D6FE047204|10.96.26.126     
Line 11449: 2019/07/04  14:37:15.146|CC|OFFERED|55808087|55808096| 559335552222 |009198160656|009198160656|SEP00D6FE047204|10.96.26.126 
```

We can see that even in the call logs we have a shortened called party missing the "3" at the end. By now, the user's already gone and my attempts to reconfigure a test Jabber account are met with me quickly realizing that Jabber works. So testing this is only going to give me a 'good' example which may not be as useful as I expect. So my mind now goes to "DNA". Can I get the answer I need via DNA? I sure can. Load up DNA and input my calling party using the specific test SEP phone as the source.

### DNA against Proper Called Party

```text
Results Summary
    Calling Party Information
        Calling Party = \+559335247867
        Partition = PT_DNDevice CSS = CSS_DEVICE_SANTAREM_E1
        Line CSS = CSS_LINE_FULL_ACCESS
        AAR Group Name =
        AAR CSS = CSS_AAR
        Dialed Digits = 0091981606562
        Match Result = RouteThisPattern
    Matched Pattern Information
        Pattern = 00.[1-9][1-9]9XXXXXXXX
        Partition = PT_SANTAREM_E1
        Time Schedule =
        Called Party Number = 0091981606562
        Time Zone = America/Sao_Paulo
        End Device = RL_SANTAREM
        Call Classification = OffNet
        InterDigit Timeout = NO
        Device Override = Disabled
        Outside Dial Tone = NO
```

### DNA against Actual Called Party

```text
Results Summary
    Calling Party Information
        Calling Party = \+559335247867
        Partition = PT_DNDevice CSS = CSS_DEVICE_SANTAREM_E1
        Line CSS = CSS_LINE_FULL_ACCESS
        AAR Group Name =
        AAR CSS = CSS_AAR
        Dialed Digits = 009198160656
        Match Result = RouteThisPattern
    Matched Pattern Information
        Pattern = 00.[1-9][1-9]XXXXXXXX
        Partition = PT_SANTAREM_E1
        Time Schedule =
        Called Party Number = 009198160656
        Time Zone = America/Sao_Paulo
        End Device = RL_SANTAREM
        Call Classification = OffNet
        InterDigit Timeout = NO
        Device Override = Disabled
        Outside Dial Tone = NO
```

So there we go, we can see via the DNA that we hit two different patterns based on the called party, and upon inspection both have Urgent Priority enabled. Urgent Priority, in the event you do not know, causes a call to be sent as soon as it matches the affected pattern (provided the PT it exists in is contained within the dialing endpoint's CSS). This is why when dialing our 13 digit number it stops at 12 digits and sends the call, as it matches and is set to send the call.

```text
Desired Pattern:
00.[1-9][1-9]9XXXXXXXX in PT_SANTAREM_E1, Urgent Priority ON
```

```text
Actual Pattern:
00.[1-9][1-9]XXXXXXXX in PT_SANTAREM_E1, Urgent Priority ON
```

Now what this actually comes down to is a flaw in the dial plan design. Given that we have overlap patterns like this it should have been noted and mitigated during roll out. Additionally we don't tackle full on dial plan re-designs unless it's under a billable project. So now I'm in mitigation mode. How can I resolve the issue and restore expected dialing behavior without impacting the user's too much? For this I came up with three ideas, however, I recognize that there may be many many answers to this and likely most more elegant. Here's what I noted are the possibilities:

1. Add a “#” to the end of the 00.[1-9][1-9]XXXXXXXX pattern.
    This would require any users trying to dial the shorter 12 digit pattern in Santarem to press “#” when they are done dialing the number they want to reach.
    It would also require a modification in the way the users dial the 12 digit pattern in Santarem.

2. Do not add a “#” to the end of the 00.[1-9][1-9]XXXXXXXX pattern and remove urgent priority.
    This will require users to wait for the 15sec inter-digit timeout when dialing the 12 digit pattern in Santarem before their call is sent to the gateway.
    It would also introduce a delay and in my opinion would be the least desired option.

3. Add a prefix, such as “9” to the beginning of the 00.[1-9][1-9]XXXXXXXX pattern, leave urgent priority on.
    This would require users to dial a 9 at the beginning of the 12 digit number in order to hit the appropriate pattern.
    The 9 would be discarded “pre-dot” so no changes would be required at the gateway.
    This, like option 1, would require a modification in the way users dial the 12 digit pattern only in Santarem.

At this juncture we are waiting on feedback from the site on how they would like to proceed, as even if "Option X" might be the best from my perspective, the users are the ones who ultimately have to deal with the change to their dialing habits, therefore we give the option to the site and provide our own input for context.

So here's a few questions for ya'll: In what ways would you tackle this dial plan overlap? Is there a more elegant solution that I'm missing? Would you recommend re-designing the dial plan over providing a band-aid solution? Would you have thought to look elsewhere or gather any additional information?

I find that in troubleshooting issues I like to think of what is most likely, or what things are most likely causing an issue before I dive in. This helps give me a framework to work off of and a checklist of things to review, as it provides contexts to the signaling and configuration and I can say "this signaling supports idea B, but not A and C" and such, and narrow down my causes there. Not always, but in cases where I don't have a full set of traces to see *what the traces say* I especially utilize this method.

If you enjoyed this, maybe learned something, or even sympathize with the random issues of the Day 2 side of life consider following my blog, or tweeting at me on Twitter (@kperryuc)!
