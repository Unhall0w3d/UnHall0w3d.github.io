---
title: "Mobile Agents, CTIOS, and Service Crashes -- Oh My!"
layout: post
date: 2019-07-17T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - SQL
  - Cisco
tags:
  - CTIOS
  - Cisco Callmanager
  - Cisco
  - Cisco UC
  - Call Manager
  - Contact Center
  - Unified Communications
  - UCCE
---

So here's another "Priority 1" or "Sev 1" issue that I troubleshot last week, and oh boy, it was an interesting one.

<!--more-->

## Issue Report

The customer reported an issue with agents in 3 geographical regions, all Work From Home agents, in which their phones de-registered from CUCM (Mobile Agents // Nailed Up Connection -- LCP/RCP CTI Ports) and they were also unable to access any options in CTIOS and were effectively kicked out of CTIOS. Issue took place around 12:35 EST (give or take a few minutes, as per usual).

For this particular set-up the customer uses Third Party SIP Phones (Software) but registers them against CUCM as LCP ports. We know this due to the client having nailed up connections from an ICM/UCCE perspective. This was gleaned from a conversation I had with one of our UCCE engineers, as even though we know 9/10 times that when an agent is kicked out of Finesse or CTIOS that it's due to the phone deregistering, and when asking for the MAC addresses from UCCE team I was given the LCP ports (which then gives us the knowledge that these are nailed up connections // mobile agents).

### Note - EOS

[CTIOS is no longer supported as of July 31, 2018](https://www.cisco.com/c/en/us/products/collateral/customer-collaboration/unified-contact-center-enterprise/eos-eol-notice-c51-733718.html)

### Finding 1

From the UCCE perspective we pulled the jgw trace and found that the LCP Ports deregistered. This causes the lack of access to CTIOS functionality and is the "root cause" of the CTIOS issue. What we'll hunt down further on in this post is "What is the Root Cause of the LCP Port dereg".. and we chase that rabbit hole as far as we can.

CTIOS and Cisco Agent Desktop (CAD) are both deprecated and no longer supported from TAC's perspective. I made a note to point this out to them, mostly so they can start the conversation on moving to Finesse.

Now in the JGW trace below we see two different LCP ports, both reporting "DEVICE_UNREGISTERED". Anyone that's worked with UCCX or UCCE knows that agent functionality from a CTI perspective is lost when a phone is no longer reachable (e.g. deregisters). We even see it reported as a CALLMANAGER_FAILURE.

```text
12:33:20:028 PG1A-jgw1 Trace: CiscoTermOutOfServiceEv Term: LCP50001182 Cause: DEVICE_UNREGISTERED
12:33:20:028 PG1A-jgw1 Trace: CiscoTermOutOfServiceEv Sending AddressOutOfService for 1 addresses
12:33:20:028 PG1A-jgw1 Trace:   MsgAddressOutOfService:  Addr: 27182 Cause: 1005
12:33:19:564 PG1A-jgw1 Trace: CiscoTermOutOfServiceEv Term: LCP50001148 Cause: DEVICE_UNREGISTERED
12:33:19:564 PG1A-jgw1 Trace: CiscoTermOutOfServiceEv Sending AddressOutOfService for 1 addresses
12:33:19:564 PG1A-jgw1 Trace:   MsgAddressOutOfService:  Addr: 27148 Cause: 1005
12:33:19:564 PG1A-jgw1 Trace: CiscoAddrOutOfServiceEv Addr: 27148 Cause: CALLMANAGER_FAILURE
12:33:19:564 PG1A-jgw1 Trace:   MsgAddressOutOfService:  Addr: 27148 Cause: 1001
```

So at this point, as I'm on a bridge/conference call with the client and relevant support teams, site coordinators and contact center managers I let them know "The agents being kicked out of CTIOS is caused by a deregistration event on the LCP ports. We need to hunt down the cause, so it'll take a bit more time." The technical contacts on the client side then inform the site managers to have the users turn their PC's off, wait 5min, then turn them on and login. This is their defined procedure to attempt to clear any registration issues or CTI weirdness. It's a bit to wait in my eyes, but, it buys me a few minutes to keep digging around.

### Finding 2

As mentioned we can't just say "Well, it deregistered." and leave it at that. We need to understand why the devices deregistered in the first place so that we can (attempt) to prevent the issue from recurring. This is where having a monitoring appliance, syslog collector, or similar can come in handy. As I didn't have time to mess around reviewing our monitoring appliance looking for a ticket/case/incident (whatever you want to call it) relevant to the issue that's happening, as if I don't find anything it ends up wasting time, I hopped in to the CUCMs are started to take a look around.

Now I searched up the CTI Port " LCP50001148 ", reviewed it's Device Pool and CallManager Group configuration to confirm what it's primary node for registration is and found " bldcucmsub7 " as the CUCM node it registers to. So I hop in via SSH and take a look at a few commands and, pretty quickly, found some issues. First, I find that the relevant node lost TCP connectivity and re-authenticated the night prior to the event, no recorded issues or network events/changes/scheduled work took place. I brush this off as coincidence and unrelated to our specific issue due to the timing. We do however see that " bldcucmtftp1 " is not authenticated at all.

```text
admin:show network cluster status
 170.8.4.61 bldcucmpub.voip.com bldcucmpub Publisher authenticated
 142.192.33.79 syrcucmsub6.voip.com syrcucmsub6 Subscriber authenticated using TCP since Sat Jun 29 01:48:39 2019
 142.192.33.73 syrcucmsub2.voip.com syrcucmsub2 Subscriber authenticated using TCP since Sat Jun 29 01:48:39 2019
 142.192.33.75 syrcucmsub4.voip.com syrcucmsub4 Subscriber authenticated using TCP since Sat Jun 29 01:48:39 2019
 142.192.33.83 syrcucmtftp2.voip.com syrcucmtftp2 Subscriber authenticated using TCP since Sat Jun 29 01:48:39 2019
 170.8.4.65 bldcucmsub3.voip.com bldcucmsub3 Subscriber authenticated using TCP since Fri May 31 07:54:03 2019
 170.8.4.63 bldcucmsub1.voip.com bldcucmsub1 Subscriber authenticated using TCP since Fri May 31 07:53:21 2019
 170.8.4.67 bldcucmsub5.voip.com bldcucmsub5 Subscriber authenticated using TCP since Fri Jul 12 12:37:03 2019
 170.8.4.71 bldcucmtftp1.voip.com bldcucmtftp1 Subscriber not authenticated - INITIATOR since Fri Jul 12 12:33:47 2019
 170.8.4.69 bldcucmsub7.voip.com bldcucmsub7 Subscriber authenticated using TCP since Thu Jul 11 23:51:21 2019
 142.192.33.81 syrcucmsub8.voip.com syrcucmsub8 Subscriber authenticated using TCP since Sat Jun 29 01:48:39 2019
```

### Finding 3

After checking RTMT I see many SDLLinkOOS (SDL Link Out Of Service) events relating to " bldcucmtftp1 ". I set this aside to review later as well, however, I check replication and see that all nodes are "3" in RTMT and that " bldcucmtftp1 " shows "off-line". This gets called out on the bridge and I notify the client that it will need to be reviewed, but we have redundant TFTP so should be fine for the time being.

Moving along I check into core dumps on " bldcucmsub7 " and find we have two cores, one for CTI Manager and one for CCM process. BINGO. We know why the phones deregistered.

```text
admin:utils core active list
Size         Date            Core File Name
340196 KB   2016-01-25 13:27:10   core.4560.6.ccm.1453750027
426260 KB   2019-07-12 12:35:58   core.28448.6.ccm.1562952957
364336 KB   2019-02-23 03:24:16   core.29166.6.ccm.1550913855
144160 KB   2019-02-23 03:24:16   core.29514.6.CTIManager.1550913855
155516 KB   2019-07-12 12:35:57   core.28467.6.CTIManager.1562952957
```

### Update to the Client

At this point I let the client know what I've found, that we have core dumps and thus service crashes on CTI Manager, then CCM Manager and this will directly cause the phones registered to this node to register elsewhere based on CMG configuration. I verify the service uptimes and that there are no other related issues to Sub7. I pull the "Event Viewer App & Syslog" logs, "Cisco CallManager" and "Cisco CTI Manager" traces for the relevant time frame as well.

Now the last thing I want to do here is hunt around to see if, after analyzing the backtrace, we can isolate this to a specific Bug ID. Unfortunately I was unable to track this down with sufficient "Sureness" that we are in fact hitting a known bug, and attempts to contact Cisco TAC were met with "your version is too old//end of life and thus we won't assist in RCA". That battle is still being fought, but unfortunately I wasn't able to make much process with what's publicly available, and without access to critical resources such as Cisco Topic, however, after a quick analyzing of the backtrace TAC can usually point this down to a particular internal bug.

-Analyzing the following core file yields a backtrace showing CCM unable to process signals; core.28448.6.ccm.1562952957

```text
====================================
backtrace
===================================
0  0x0305f266 in raise () from /lib/libc.so.6
1  0x03060c31 in abort () from /lib/libc.so.6
2  0x08436f8b in IntentionalAbort (reason=0xb03c678 "CallManager unable to process signals. This may be due to CPU or blocked function. Attempting to restart CallManager.") at ProcessCMProcMon.cpp:80
3 0x0843704c in CMProcMon::monitorThread () at ProcessCMProcMon.cpp:530
4  0x05a64ca7 in ACE_OS_Thread_Adapter::invoke (this=0xb1668be8) at OS_Thread_Adapter.cpp:94
5  0x05a1a541 in ace_thread_adapter (args=0xb1668be8) at Base_Thread_Adapter.cpp:137
6  0x00e61791 in start_thread () from /lib/libpthread.so.0
7  0x0310dbbe in clone () from /lib/libc.so.6
```

-Analyzing the following core file yields a backtrace showing CCM unable to process signals; core.28467.6.CTIManager.1562952957

```text
====================================
backtrace
===================================
0  0x00dc8266 in raise () from /lib/libc.so.6
1  0x00dc9c31 in abort () from /lib/libc.so.6
2  0x08499591 in IntentionalAbort (reason=0x87019e8 "SDL Router Services declared dead. This may be due to high CPU usage or blocked function. Attempting to restart CTIManager.") at ProcessCTIProcMon.cpp:65
3  0x084996ac in CMProcMon::verifySdlTimerServices () at ProcessCTIProcMon.cpp:573
4  0x0849a358 in CMProcMon::callManagerMonitorThread (cmProcMon=0x9ff2ef8) at ProcessCTIProcMon.cpp:330
5  0x00857ca7 in ACE_OS_Thread_Adapter::invoke (this=0xa55ba60) at OS_Thread_Adapter.cpp:94
6  0x0080d541 in ace_thread_adapter (args=0xa55ba60) at Base_Thread_Adapter.cpp:137
7  0x0039d791 in start_thread () from /lib/libpthread.so.0
8  0x00e76bbe in clone () from /lib/libc.so.6
```

### Finding #4

So now that we know that the users deregistered which caused the CTIOS issue, and they deregistered due to relevant processes coring on one of the Subscribers, I can move on to the next issue which was the TFTP server not authenticated, not participating in DBreplication and not responding to TFTP file requests.

For this one I sent a few pings over to the node, noted 20ms on "normal" responses (e.g. before the issue started) and 400+ms during the issue. I notice SSH and HTTPs attempts fail. This brings me to using vSphere Client to check out the ESXi host.

Upon logging in the console for the node is locked, not coming up at all. Checking the ESXi graphing I can see that the CPU utilization over the past 2 hour roll-up was 99.9%. Without any way to recover the node or really know what it's doing I was given authorization to reboot the node via vSphere. I want to note that this is not advised unless no other steps are available, although I can't find the Bug ID at the time of writing I was presented recently with a Bug ID from Cisco TAC that details the following, and I paraphrase:

> "Any UC VOS appliance (CUCM, CUC, CER, UCCX, etc) that experiences an ungraceful shutdown should be rebuilt, as they are real-time systems corruption of various kinds can occur when the VM is abruptly shut down."

This is something I bring to the conference call and advise the client. After rebooting the node we see CPU usage go back to normal, services start cleanly and (as far as we can see) no issues. I log in to RTMT and pull the PerfMonLogs, Event Viewer App & Syslogs for review. This particular node is on the same UCS Chassis/ESXi host as one of my previous [posts](https://unhall0w3d.github.io/2019/06/26/and-boom-goes-the-storage-controller.html). As we are still having issues with that particular chassis which has warranted Motherboard replacements, RAID controller replacements, drive replacements, chassis replacements, the issue is chalked up to more chassis issues, and/or a byproduct of previously having been abruptly shutdown due to storage controller issues. The client is discussing whether to RMA the entire unit (at once) and get a replacement for all parts. The VMs will likely be rebuilt on that new chassis due to the aforementioned bug.

So this was a fun call that ended up lasting about 4 hours in total, another 2 hours messing with Cisco TAC, Cisco Account Reps for their official word on the "EoL/EoS" status of the nodes. I also had to spend time parsing the logs to determine when the CPU condition started on the TFTP server, and it turns out it had been pegged at 99% for the majority of the day and was a coincidence that the issue had been found.

That's it for now! Make sure to follow the blog to get alerts on new posts, check out my Twitter (@kperryuc) where you can also ask UC and DC related questions, suggest post topics, or talk about anything!
