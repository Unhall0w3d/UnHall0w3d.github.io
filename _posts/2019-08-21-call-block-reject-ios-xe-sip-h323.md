---
title: "Call Block or IOS/XE on SIP/H.323"
layout: single
date: 2019-08-21T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Cisco
  - IOS
  - Unified Communications
tags:
  - IOS-XE
  - Call Block
  - Dial Plan
  - Gateway
  - Dial Peer
  - IOS
  - Cisco
  - CUBE
  - Cisco Unified Border Element
---

## Gotta Block Those Calls, Man

A common request that we get is to perform call blocking. It's usually due to an irate customer, irate former employee, or general solicitations. By now our clients have call blocking configs in place at most/all sites, or on their primary/secondary CUBEs (or CCM, which I'll cover in another post), so for these requests it's typically as easy as adding an additional line to the config to block a new number.<!--more--> But for now we can act as if we have an IOS CUBE (SIP to SIP) with no call blocking configured, and we can whip up a quick config to satisfy the client requirements.

[Supporting Documentation](http://www.cisco.com/c/en/us/support/docs/voice/call-routing-dial-plans/64020-number-voice-translation-profiles.html)

## Client request for Call Blocking

We have been receiving calls from 3152223333, an irate former employee. Can we please initiate call blocking against this number?

## Review Steps

Depending on the deployment, some steps may be skipped, but as I can work 30+ deployments in a given week, it's difficult to remember exactly what's set up, where, at all times.

### Review CDR Data

1. Identify the ingress CUBE/VGW.
2. Confirm per CDR what ANI is being passed to UCM. If there are any calling party modifications that you perform on CallManager, keep it in mind.

### If The call Is Active, Get Some Debugs

- If Carrier Connection is SIP - set up *debug ccsip messages* to confirm calling party presentation from the carrier.
- If Carrier Connection is TDM/ISDN (T1/E1) - *use debug isdn q931* , or applicable debugging for your signal type.

### Verify Your Ingress Dial-Peer

Provided things have been labeled properly you should be able to identify the ingress dial-peer by description, or by session target. Otherwise you may need to review the configuration to know which dial-peer is being hit. In a pinch *debug voip dialpeer inout* can be used with live or reproducible call examples.

```text
BLDRVOIPGW1#show run | sec dial-peer
dial-peer voice 500 voip
  description Incoming Calls FROM AT&T
  translation-profile incoming fromPSTN
  session protocol sipv2
  incoming uri via fromTelco
  voice-class codec 2
  voice-class sip bind control source-interface Loopback1
  voice-class sip bind media source-interface Loopback1
  dtmf-relay rtp-nte
  fax protocol pass-through g711ulaw
  ip qos dscp cs5 media
  ip qos dscp cs3 signaling
  no vad
```

## Initiate Call Blocking

### Create A Voice Translation-Rule For Call Reject

Syntax

```text
voice translation-rule YYY
rule 1 reject /ANI/
```

Example

```text
voice translation-rule 100
  rule 1 reject /3152223333/
```

Now create a translation profile to specify whether we are going to translate against calling or called party, and using what rule set.

### Create A Voice Translation Profile

```text
voice translation-profile Call_Block
translate calling 100
```

Now that we have configured the profile, and rule set we'll want to apply it to the INGRESS dial-peer. We do this because we are modifying the CALLING party.

CALLED party modifications can be performed too, but for the purposes of call blocking we don't need to.

### Apply The Translation Profile to a Dial-Peer

Syntax

```text
conf t"
dial-peer voice #### voip
call-block translation-profile [incoming/outgoing] [profile_name]
call-block disconnect-cause incoming [call-reject/user-busy/invalid-number/unassigned-number]
```

Example

```text
conf t
    dial-peer voice 500 voip
        call-block translation-profile incoming Call_Block
        call-block disconnect-cause incoming call-reject
end
wr
```

### Verify the Call Block Configurations are Applied

```text
 BLDRVOIPGW1#show run | sec dial-peer
dial-peer voice 500 voip
  description Incoming Calls FROM AT&T
  translation-profile incoming fromPSTN
  call-block translation-profile incoming Call_Block
  call-block disconnect-cause incoming call-reject
  session protocol sipv2
  incoming uri via fromTelco
  voice-class codec 2
  voice-class sip bind control source-interface Loopback1
  voice-class sip bind media source-interface Loopback1
  dtmf-relay rtp-nte
  fax protocol pass-through g711ulaw
  ip qos dscp cs5 media
  ip qos dscp cs3 signaling
  no vad
```

So now when a call comes in from the carrier on ingress dial-peer 500, prior to the outbound dial-peer being selected the call-block translation-profile specified will be run against the ANI of the call and, if applicable, will take action depending on the rule. In our case, we specified to "Reject" the call. Further, we optionally chose to specify "call-reject" as the  reason code for rejecting the call, as opposed to Unallocated/Unassigned or User Busy.

This is the quickest way, even if it's not set up yet, to initiate call blocking on a known, consistent number. This can work, and additional rules can be added in situations where you have 5, 10 numbers. All we need to do is go back into the translation-profile and add "rule 2 reject /ANI/" and repeat, incrementing the rule number each time. Do note that there is a maximum number of rules that can be added (100). This solution will not be appropriate where you have hundreds, or thousands, of calls to block/filter. For that we'd want to call block/filter within UCM (version 8 and higher -- I can't tell you how many times a client with MGCP GW and CUCM 7 has asked to call block. No. Can't do it. Don't use MGCP or upgrade your CUCM servers).

This is reactive, so it won't cure all your woes when it comes to spoofed numbers or bad actors, but it can certainly put a damper on their attempts to angrily call in with threats, or even just to annoy.

If you found this useful, or have any horror stories about call blocking in your environment (and maybe what necessitated it) let me know in the Discord, or on Twitter (@kperryuc)! Thanks for reading!
