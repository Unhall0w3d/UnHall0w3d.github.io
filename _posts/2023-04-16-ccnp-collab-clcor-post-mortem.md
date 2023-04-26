---
title: "CCNP Collab CLCOR Post Mortem"
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

Well, I managed to pass the CCNP Collab CLCOR exam to refresh the expiry date on my Cisco certifications.<!--more--> The bright side is that my certs are refreshed, I can refocus myself on the Blog and other endeavors (such as switching my daily driver PC from Windows 11 to Linux (Arch?)) as part of a "30 day challenge" -- might talk about this later. The not-so-bright side is that, with the old certifications being deprecated my bonified CCNA Wireless, CCNA Data Center, CCNA Route/Switch and CCNA Collaboration certifications are gone... well.. not gone, they exist as the "CCNA" now, but I missed having extra certifications, resume fluff that it was.

So now it happens that I am CCNA, CCNP Collab and CCNP Data Center, AudioCodes E-SBC Associate, and VMWare VCP6 Data Center Virtualization certified. What's next, I wonder?

## The CCNP Collaboration CLCOR Exam

Most folks reading this will have experienced a Pearson VUE Cisco exam at one time or another and is familiar with the experience, but testing centers are different and some monitors handle the testing experience a little differently.

For me a standout interaction was having to take my glasses off and prove to the test monitor that they did not contain cameras. 

Sitting for the exam took me, from the time I "signed-in" and "signed-out" of the testing sitek, approximately 45minutes. That includes getting the picture taken, signing some documents, putting my personal items into a locker, then sitting for the exam. The exam moved quickly for me as there was a large portion of the material I had direct experience or knowledge of due to work (13 years in Cisco VoIP/UC)... though due to my semi-limited scope being at an MSP, some features (like self provisioning IVR and UCM Auto-Registration) were a bit more abstract. 

Another particularly difficult subject for me was QOS -- implementation on the devices, as well as critical information such as DSCP markings, CoS values, etc. As I specialize on the UC side of the Cisco environment things such as provisioning access switches for user PCs/phones, dhcp configurations, QoS configs, trust boundaries, etc are typically under the purview of my companies Route/Switch team and I don't get much exposure to it day-to-day.

That said, I did make a good effort to remember DSCP marking/CoS Values, what traffic each is assigned to, translations between DSCP and COS, the relevant IOS configs... and it was sufficient for the exam.

I want to add the short time on the test is primarily due to me being one of those "If I know it I know it, if I don't know it then no amount of staring at the question will give me the answer." test takers. Having ADHD and trying to "actively think" during exams results in a very blank quiet brain... which is not at all what I need. So I tend to move quickly through exams.

## CLCOR Areas of Interest

So I figured I would mention some subjects that would be good to study for the CLCOR exam, if you want to target specific knowledge areas outside of any general studying.

I would include the following in my studies:

```
1. CCM - General
    a. Understand DNS/DNS SRV records/entries and their function in CCM, how/what they are used for, how many DNS SRV entries can be defined on the endpoint types that DNS SRV records can be used on.
    b. Understand how to configure variable length dialing plans.
    c. How to globalize a dial plan, such as with e.164
    d. Understand inter-digit timeout, the default value, how to bypass/mitigate it (avoid having to wait for it).
    e. NTP on UC VOS. Understand what type of NTP server is needed, how to read the output of "utils ntp status" and replace NTP servers. I have a [post](https://nocthoughts.com/2019/12/15/why-windows-ntp-is-unsupported-for-cisco-uc-deployments.html) for this! 
    f. Also identify if the Publisher is having an NTP issue from the output of a Subscriber node.
    g. Endpoint Time Synchronization (e.g. Cisco SIP Phone & date/time groups)
    h. Standard. Local. Route. Groups. Learn them. How to configure them, where, why you would want to.
    i. CUCM digit analysis (on-hook vs off-hook // en bloc vs digit by digit analysis)
    j. SNMP -- what ports does it use, is it TCP or UDP, what port does "snmpwalk" use versus an "snmp trap" or "inform". How do traps and informs differ?
    k. Region Relationships, Location configurations
    l. How to identify if call signaling/media is encrypted or not by only having access to a Cisco IP Phone's screen (E.g. determine if the current active call is encrypted)
    m. CCM Clustering Requirements over WAN -- round trip delay (e.g. 80ms)
    n. Translation Patterns, Transformation Patterns, how to use/when to use -- also understand valid wildcards for patterns and how to use them.
    o. Media Resource types, transcoder capabilities (software vs hardware), pvdm types
    p. Dial plan configuration and manipulation should be muscle memory, including the use of pre dot patterns.
    q. LDAP Configuration on CUCM, sync timings, garbage collection process for removed users.
    r. DHCP Option 150/66 -- learn them, live them, love them.
    s. Self Provisioining IVR/Device Auto Registration on CUCM. Understand all aspects.
    t. Codecs, transcoding/conference resources, when they're needing and where, whether a call will progress or fail based on SDP contents.
    u. CCM backups and when to run them (or when not to run them) (e.g. run them during off hours)
    v. DTMF configurations, in band, out of band, how to identify and how to configure, also how to resolve DTMF mismatch issues using Media Resources.
    w. What CCM servers can run the TFTP service?
    x. Service Parameters such as Apply Transformations On Remote Number -- what does it do? Why would you use it? (Outbound Calling Party Transform CSS can be used to localize remote connected party information with this parameter set to TRUE), Maximum Serving Count (TFTP) service parameter (specifies maximum number of TFTP client requests to accept and serve at a given time).
    y. What kind of Media Resource does the IP Voice Media Streaming (IPVMS) service invoke?
    z. LDAP/Dir Sync garbage collection process. When does it kick off? How long until it kicks off again (e.g. how often does it run?) -- think about how long you'd have to wait for a user to be removed from CCM after it is deleted from LDAP.

2. CCM - MGCP
    a. How to configure MGCP on a gateway such that it will register to CUCM.
    b. How to configure an MGCP Gateway and endpoints on CUCM such that the endpoints will register.
    c. Related "URLs" or "buttons" to click from the CUCM Administration Page to perform MGCP related actions (e.g. Device > Gateway > Add Gateway)
    d. How does MGCP work as a protocol (server/client relationship), MGCP configurations on IOS gateway -- review 'show run' and know a working config from a non-working config (e.g. command syntax, required commands)
    e. Audit Endpoint message contents from CCM to MGCP endpoint

3. CCM - Toll Fraud Prevention
    a. Understand and know how to implement common toll fraud prevention techniques
        i. How to block "offnet to offnet" transfers, and why you would want to. What's required to allow this to work?
        ii. How to prevent conference calls from continuing after the conference creator drops. Why is this important? How do you enable this behavior?
        iii. How do you prevent call forwards from internal to international? (FAC & Restrict Call Forward All CSS from international patterns)

4. CCM - SIP
    a. Understand how to read SIP Signaling, including the SDP contents for codecs negotiated, fax negotiations, bitrate, audio ports, media ip addresses and whether SDP contents may be missing or not, and how that affects a call.
    b. Know your codec to identifier translation -- for example, in the m=audio line know what codec "0" is, "8", "18", etc.
    c. How to configure SIP Route Patterns
    d. SIP High patterns -- what are valid 4xx messages, and 5xx messages?
    e. Understand what SDP line (e.g. m= line) contains the RTP port, and what happens if it is set to "0". 

5. CCM - Device Pool, Region Relationships, Media Resources, Codecs
    a. What configurations are held within the Device Pool?
    b. What do device pools enable you to do?
    c. How do you change maximum session bit rate configurations for a region?
    d. When region relationships are configured to use "X" kbps, what codec would be used? (e.g. 8kbps = g.729)
    e. How can a Device Pool be leveraged for Standard Local Route Groups?
    f. What media resource can be used to interwork DTMF mismatch between MGCP registered FXS port and CCM SIP Trunk?
    g. What is the iLBC codec and when should it be used?
    h. What codecs to use when bandwidth is limited.
    i. Learn how to disable g.722 and Opus codecs. Opus can be disabled only for recording devices via service parameter. Learn what parameter that is.

6. CCM/Expressway - Certificates & Security
    a. What service authenticates certificates on behalf of IP Phones, that runs on callmanager?
    b. What two services certificates should not be regenerated at the same time (Callmanager & Trust Verification Service)
    c. What requirements are mandatory to enable Mixed Mode on Cisco Callmanager?
    d. When deploying MRA, what two SAN entries are mandatory in the Expressway cert to allow secure phone registrations?

5. QoS
    a. DSCP Markings and the traffic they relate to (video conferencing, voice traffic, call signaling, management traffic, etc.)
    b. CoS Values and the traffic they relate to (call signaling, voice traffic, etc.)
    c. Queuing policies (policing, shaping) -- what each do, the result of using each on the traffic that is policed/shaped
    d. Queueing policies (queueing strategies such as, but not limited to Weighted Fair Queueing -- understand how each affects traffic, how the traffic is separated, etc.)
    e. IOS commands for verifying related policy maps
    f. QoS trust boundaries
    g. Characteristics of different types of traffic (video, conferencing, audio) that governs QoS requirements for that type of traffic (e.g. variable bit rate, bursty, lossy, etc.)
    h. Translating CoS to IP Precedence to Per Hop Behavior (PHB) to DSCP.
    i. Explain what happens/what impacts are viewed/what issues happen when QoS is not deployed across the LAN or WAN.

6. Cisco Expressway/VCS
    a. Expressway-C (inside, ccm facing)
    b. Expressway-E (outside, internet facing)
    c. How traffic is passed between C/E (firewall traversal), benefits of using Expressway, how it allows remote agents to access internal resources, functionality enabled by or provided by expressway servers.
    d. Where do devices register to when using Mobile and Remote Access (MRA)?
    e. MRA Supported endpoint features
    f. Functions provided by Expressway
    g. Explain call flow for traffic from MRA registered endpoint to Call Control (CCM), and visa versa

7. CUC (Unity Connection)
    a. Understand call handler types, what their function is.
    b. Understand CCM End User sync, and how to administrate the users properly (add/delete/change) when not using LDAP
    c. Understand Message Waiting Indicator configs on both CCM and Unity side
    d. Understand Alternate Extensions, why you would use it.
    e. Understand SIP and SCCP integrations, as well as IPv4 & IPV6 configurations, how to enable both, what webpage/buttons do you have to click, etc.
    f. Describe how CUC Single Inbox works for Unified Messaging integrations.

8. IOS/XE
    a. Reading and understanding debugs for ISDN Q921 and ISDN Q931
    b. How to configure ISDN T1/E1, know valid linecodes and framing. Understand how to provide or receive clocking.
    c. Voice translation rules, profiles, and dial-peers
    d. Voice service voip and sip configurations, as well as IDSN PRI configurations
    e. DTMF configurations
    f. DNS based high availability/failover -- what records need to be created to support a X%/X% split across two CUBEs (e.g. 20/80 split, 60/40 split)
    g. Linecodes. Framing. Don't mess up and mistake a framing type for a linecode type.
    h. On an ISDN PRI based call, calling party's name is not being received. What change do you make on the Serial Interface to support supplementary services such as calling/called party name presentation.
    i. Know how to configure a gateway to provide, or receive clocking on a T1/E1 controller.
    j. What is the default codec used on a dial-peer (POTS and VOIP)
    k. Know how to configure an ISDN T1 PRI so that calls start with channel 1 and use channels in a predictable order.
    l. Diagnose Slips/Slip Secs on a PRI.
    m. Know how to configure DTMF on a CUBE/Gateway -- such as configuring inband dtmf relay as first priority, out of band as second priority on a dial-peer or globally in voice service voip.
    n. What field in an RTP packet allows devices to detect loss?
    o. Pass-Thru vs Flow-Around media when it comes to calls via CUBE. What's the difference?
    p. How do you allow video endpoints to negotiate without CUBE interfering? What do you configure?

9. Telepresence
    a. Telepresence devices, such as SX80, IX5000 -- general knowledge of them and how to troubleshoot basic issues such as cli commands on the telepresence endpoint.
    b. Conferencing multiple devices (such as IX5000) together -- what media resource/server is needed (Cisco Meeting Server)
    c. Cisco Callmanager registered DX80 is upgraded, and is found to be downgraded the next day. What causes this in the device config on CUCM and how do you fix it?
    d. Recognize different ways to explain or describe Mobile & Remote Access.

10. IM & Presence
    a. Protocols used by Jabber to authenticate
    b. DNS records required for discovery when connected inside corporate LAN, as well as for expressway edge connection.
    c. Jabber for Android vs Jabber for Windows vs Jabber for iPhone naming convention (TCT/BOT/CSF)
    d. End User access control groups
    e. User Permissions required for Cisco Jabber, and deskphone mode (e.g. Standard CTI Enabled)
    f. Understand Active/Standby configuration vs Active/Active, the role of Cisco Server Recovery Manager in IM&P, how long failback takes.
    g. If a manual failback is performed, what happens to the users? What do they need to do?


11. SNMP
    a. SNMP Trap vs SNMP Inform
    b. SNMP Get/Walk vs Trap, what port is used
    c. What underlying protocol does SNMP use? (UDP)
    d. What versions of SNMP does CUCM support? Which one provides encryption?


```

This is what I can remember I was tested on, and what I remember looking into prior to the test that ended up being helpful. It is by no means the definitive or most exhaustive prep list for the exam.

Of course, this is all set to change when the exams are refreshed -- but may hold true for the most part. We'll see. But as I think of additional topics to study I will edit the list!

## Thanks For Stopping By

Now that my humble brag for passing the exam is done, and I've shared some target areas to study if you're aiming to take the exam, I'd like to thank you for reading and wish anyone taking the exam the best of luck. As always you can suggest posts on our Discord server, which you can join using the hyperlink in the side bar. Have a good one!