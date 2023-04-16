---
title: "CCNP Collab ENCOR Post Mortem"
layout: single
classes: wide
date: 2023-04-16T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Cisco
  - Unified Communications
tags:
  - Cisco
  - Unified Communications
  - General
---
<span class="image fit"><img src="{{ "/assets/images/ccnpcollab.png" | absolute_url }}" alt="CCNP Collaboration" /></span>

## Recertified, Again!

Well, I managed to pass the CCNP Collab ENCOR exam to refresh the expiry date on my Cisco certifications.<!--more--> The bright side is that my certs are refreshed, I can refocus myself on the Blog and other endeavors (such as switching my daily driver PC from Windows 11 to Linux (Arch?)) as part of a "30 day challenge" -- might talk about this later. The not-so-bright side is that, with the old certifications being deprecated my bonified CCNA Wireless, CCNA Data Center, CCNA Route/Switch and CCNA Collaboration certifications are gone... well.. not gone, they exist as the "CCNA" now, but I missed having extra certifications, resume fluff that it was.

So now it happens that I am CCNA, CCNP Collab and CCNP Data Center, AudioCodes E-SBC Associate, and VMWare VCP6 Data Center Virtualization certified. What's next, I wonder?

## The CCNP Collaboration ENCOR Exam

Most folks reading this will have experienced a Pearson VUE Cisco exam at one time or another and is familiar with the experience, but testing centers are different and some monitors handle the testing experience a little differently.

For me a standout interaction was having to take my glasses off and prove to the test monitor that they did not contain cameras. 

Sitting for the exam took me, from the time I "signed-in" and "signed-out" of the testing sitek, approximately 45minutes. That includes getting the picture taken, signing some documents, putting my personal items into a locker, then sitting for the exam. The exam moved quickly for me as there was a large portion of the material I had direct experience or knowledge of due to work (13 years in Cisco VoIP/UC)... though due to my semi-limited scope being at an MSP, some features (like self provisioning IVR and UCM Auto-Registration) were a bit more abstract. 

Another particularly difficult subject for me was QOS -- implementation on the devices, as well as critical information such as DSCP markings, CoS values, etc. As I specialize on the UC side of the Cisco environment things such as provisioning access switches for user PCs/phones, dhcp configurations, QoS configs, trust boundaries, etc are typically under the purview of my companies Route/Switch team and I don't get much exposure to it day-to-day.

That said, I did make a good effort to remember DSCP marking/CoS Values, what traffic each is assigned to, translations between DSCP and COS, the relevant IOS configs... and it was sufficient for the exam.

I want to add the short time on the test is primarily due to me being one of those "If I know it I know it, if I don't know it then no amount of staring at the question will give me the answer." test takers. Having ADHD and trying to "actively think" during exams results in a very blank quiet brain... which is not at all what I need. So I tend to move quickly through exams.

## ENCOR Areas of Interest

So I figured I would mention some subjects that would be good to study for the ENCOR exam, if you want to target specific knowledge areas outside of any general studying.

I would include the following in my studies:

```
1. QoS
    a. DSCP Markings and the traffic they relate to (video conferencing, voice traffic, call signaling, management traffic, etc.)
    b. CoS Values and the traffic they relate to (call signaling, voice traffic, etc.)
    c. Queuing policies (policing, shaping) -- what each do, the result of using each on the traffic that is policed/shaped
    d. Queueing policies (queueing strategies such as, but not limited to Weighted Fair Queueing -- understand how each affects traffic, how the traffic is separated, etc.)
    e. IOS commands for verifying related policy maps
    f. QoS trust boundaries
    g. Characteristics of different types of traffic (video, conferencing, audio) that governs QoS requirements for that type of traffic (e.g. variable bit rate, bursty, lossy, etc.)

2. Cisco Expressway/VCS
    a. Expressway-C (inside, ccm facing)
    b. Expressway-E (outside, internet facing)
    c. How traffic is passed between C/E (firewall traversal), benefits of using Expressway, how it allows remote agents to access internal resources, functionality enabled by or provided by expressway servers.

3. CCM - MGCP
    a. How to configure MGCP on a gateway such that it will register to CUCM.
    b. How to configure an MGCP Gateway and endpoints on CUCM such that the endpoints will register.
    c. Related "URLs" or "buttons" to click from the CUCM Administration Page to perform MGCP related actions (e.g. Device > Gateway > Add Gateway)
    d. How does MGCP work as a protocol (server/client relationship), MGCP configurations on IOS gateway -- review 'show run' and know a working config from a non-working config (e.g. command syntax, required commands)
    e. Audit Endpoint message contents from CCM to MGCP endpoint

4. CCM - Toll Fraud Prevention
    a. Understand and know how to implement common toll fraud prevention techniques
        i. How to block "offnet to offnet" transfers, and why you would want to. What's required to allow this to work?
        ii. How to prevent conference calls from continuing after the conference creator drops. Why is this important? How do you enable this behavior?

5. CCM - General
    a. Understand DNS/DNS SRV records/entries and their function in CCM, how/what they are used for, how many DNS SRV entries can be defined on the endpoint types that DNS SRV records can be used on.
    b. Understand how to configure variable length dialing plans.
    c. How to globalize a dial plan, such as with e.164
    d. Understand inter-digit timeout, the default value, how to bypass/mitigate it (avoid having to wait for it).
    e. NTP on UC VOS. Understand what type of NTP server is needed, how to read the output of "utils ntp status" and replace NTP servers. I have a [post](https://nocthoughts.com/2019/12/15/why-windows-ntp-is-unsupported-for-cisco-uc-deployments.html) for this! 
    f. Also identify if the Publisher is having an NTP issue from the output of a Subscriber node.
    g. Endpoint Time Synchronization (e.g. Cisco SIP Phone & date/time groups)
    h. Standard. Local. Route. Groups. Learn them. How to configure them, where, why you would want to.
    i. CUCM digit analysis (on-hook vs off-hook)
    j. SNMP -- what ports does it use, is it TCP or UDP, what port does "snmpwalk" use versus an "snmp trap" or "inform". How do traps and informs differ?
    k. Region Relationships, Location configurations
    l. How to identify if call signaling/media is encrypted or not by only having access to a Cisco IP Phone's screen (E.g. determine if the current active call is encrypted)
    m. CCM Clustering Requirements over WAN
    n. Translation Patterns, Transformation Patterns, how to use/when to use.
    o. Media Resource types, transcoder capabilities (software vs hardware), pvdm types
    p. Dial plan configuration and manipulation should be muscle memory, including the use of pre dot patterns.
    q. LDAP Configuration on CUCM, sync timings, garbage collection process for removed users.
    r. DHCP Option 150/66 -- learn them, live them, love them.
    s. Self Provisioining IVR/Device Auto Registration on CUCM. Understand all aspects.
    t. Codecs, transcoding/conference resources, when they're needing and where, whether a call will progress or fail based on SDP contents.
    u. CCM backups and when to run them (or when not to run them).
    v. DTMF configurations, in band, out of band, how to identify and how to configure

6. CUC (Unity Connection)
    a. Understand call handler types, what their function is.
    b. Understand CCM End User sync, and how to administrate the users properly (add/delete/change) when not using LDAP
    c. Understand Message Waiting Indicator configs on both CCM and Unity side
    d. Understand Alternate Extensions, why you would use it.
    e. Understand SIP and SCCP integrations, as well as IPv4 & IPV6 configurations, how to enable both, what webpage/buttons do you have to click, etc.

7. CCM - SIP
    a. Understand how to read SIP Signaling, including the SDP contents for codecs negotiated, fax negotiations, bitrate, audio ports, media ip addresses and whether SDP contents may be missing or not, and how that affects a call.
    b. Know your codec to identifier translation -- for example, in the m=audio line know what codec "0" is, "8", "18", etc.
    c. How to configure SIP Route Patterns
    d. SIP High patterns -- what are valid 4xx messages, and 5xx messages?

8. IOS/XE
    a. Reading and understanding debugs for ISDN Q921 and ISDN Q931
    b. How to configure ISDN T1/E1, know valid linecodes and framing. Understand how to provide or receive clocking.
    c. Voice translation rules, profiles, and dial-peers
    d. Voice service voip and sip configurations, as well as IDSN PRI configurations
    e. DTMF configurations

9. Telepresence
    a. Telepresence devices, such as SX80, IX5000 -- general knowledge of them and how to troubleshoot basic issues such as cli commands on the telepresence endpoint.

10. IM & Presence
    a. Protocols used by Jabber to authenticate
    b. DNS records required for discovery when connected inside corporate LAN, as well as for expressway edge connection.
    c. Jabber for Android vs Jabber for Windows vs Jabber for iPhone naming convention (TCT/BOT/CSF)
    d. End User access control groups
```

This is what I can remember I was tested on, and what I remember looking into prior to the test that ended up being helpful. It is by no means the definitive or most exhaustive prep list for the exam.

Of course, this is all set to change when the exams are refreshed -- but may hold true for the most part. We'll see. But as I think of additional topics to study I will edit the list!

## Thanks For Stopping By

Now that my humble brag for passing the exam is done, and I've shared some target areas to study if you're aiming to take the exam, I'd like to thank you for reading and wish anyone taking the exam the best of luck. As always you can suggest posts on our Discord server, which you can join using the hyperlink in the side bar. Have a good one!