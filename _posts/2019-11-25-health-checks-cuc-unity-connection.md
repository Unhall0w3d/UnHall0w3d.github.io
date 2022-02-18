---
title: "Health Checks - CUC - Unity Connection"
date: 2019-11-25T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Cisco
  - Unified Communications
tags:
  - Health Checks
  - Server Health
  - Cisco
  - Cisco UC
  - Unity Connection
  - Unified Communications
  - CUC
  - Voicemail
  - Action Plan
  - Reboot
  - Restart
---

<span class="image fit"><img src="{{ "/assets/images/cuchealthcheck1.png" | absolute_url }}" alt="" /></span>

Now for the third technology on my list, Cisco Unity Connection. And for this I've provided the list of commands and checks that I run against CUC nodes (7.x-12.x)  for most changes that take place. It's useful output to collect prior to changing configurations like domains, DNS servers, IP/Hostname changes, Upgrades, Restarts -- anything that makes a change system wide, or that would affect call processing.

I pull this data to refer back to in the event that the change has disrupted dbrepliction, endpoint registration status, inter-cluster communication, intra-cluster communication, service status, anything. Consider this output a "CYA" for later. Something to refer back to to confirm all is as it was prior to the change, with whatever exceptions should exist (e.g. IP address changed should reflect in post-change "show network eth0 detail" output.

So without further adieu, this is my personal list

## Health Check Commands [CUC]

### show status

Shows the status of the system, such as system uptime, disk I/O usage, CPU usage, Memory usage, Partition space, Platform version and more.

### show version active

Shows the version installed into the active partition as well as any cop files installed.

### show version inactive

Shows the version installed into the inactive partition as well as any cop files installed.

### show hardware

Shows data relating to the underlying hardware of the system, less pertinent for virtualized servers. In the case of virtualization we would refer to additional ESXi and UCS-C/B/E command output for hardware status.

### show network cluster

Returns a list of IP addresses and hostnames/FQDNs for CUC nodes joined to the cluster.

### show perf query class Processor|Memory

Query perfmon to review data relating to memory, virtual memory, swap, CPU usage/allocation.

### utils diagnose test

Runs self diagnostics on the CUC node itself pertaining to disk, memory, tomcat, DNS, NTP and other functions. Can detect various issues, such as the ever-common "reverse dns lookup failure" and more.

### utils service list

Returns the list of services running on the CUC node, whether it is the Publisher node or not, and what the state of the service is (running|notrunning).

### utils ntp status

Reports back the status of configured NTP servers, what the stratum is currently, and the jitter, and latency is to each.

### utils disaster_recovery history backup

Reports back the last 10 (or so) backups, whether they succeeded or failed, what components were backed up and on what date. Also displays what the network device was that was used for SFTP backup.

### utils dbreplication runtimestate

Reports back the state of dbreplication AS PER THE LAST STATUS CHECK. This includes the dbreplication state (should be 2), what the replication queue looks like, as well as what nodes are participating in replication.

*Replication should be confirmed as 'healthy' prior to completing any work. Resolve any replication issues before performing upgrades or other work.*
*To run a fresh status check of dbreplication, issue the command utils dbreplication status*

### utils core active list

Provides a list of all core files found. Core files are generated whenever a service crashes. These should be analyzed and the backtrace analyzed against open Cisco Bug IDs, or by Cisco TAC.

*To analyze the backtrace of a core file, issue utils core active analyze <filename>*

### show cuc cluster status

Command used to verify the current state of the cluster. This will display whether the Pub or Sub is Primary, what node is Secondary, what the status is (e.g. Split Brain Resolution, Normal, etc.).

*It is not advised to proceed with changes when the cluster is in an unfavorable state, such as Sub acting Primary or Split Brain Resolution. The underlying issue (service crashing, WAN/LAN outages, IOWAIT, etc.) should be resolved prior to fixing SBR.*

## Screenshots

### Alert Central - RTMT

<span class="image fit"><img src="{{ "/assets/images/cuchealthcheck2.png" | absolute_url }}" alt="" /></span>

### System Summary - RTMT

<span class="image fit"><img src="{{ "/assets/images/cuchealthcheck3.png" | absolute_url }}" alt="" /></span>

In addition to the above, it may be prudent to log into CUCM and verify the state of the SIP Trunk to CUC (SIP Integration) or voicemail ports (SCCP Integration). There's a few additional elements from the GUI we should collect too, and I've listed them below.

### Cisco Unified CM Administration > Device > Trunk

<span class="image fit"><img src="{{ "/assets/images/videocalling4.png" | absolute_url }}" alt="" /></span>

### Cisco Unity Connection Administration > Mailbox Storage > Mailbox Stores

Confirm status of the mailbox store, current usage details.

### Cisco Unity Connection Serviceability > Tools > Cluster Management

Take a screenshot to identify the status of each node, we should see the Pub as Primary and Sub as Secondary. This is akin to "show cuc cluster status" in the CLI.

### Log in to Enterprise/Prime License Manager

Take note of any License or Product Instance Alerts. Also verify that the Last Successful Synchronization was recent. If desired, prompt a manual sync. Also verify License Usage for the proper instance.

## Verification Steps

### Leave a voicemail

Retrieve it from an internal phone and externally via Global Access Number (or relevant DID that routes in to Unity).

### Verify MWI

Ensure it turns on/off as VM is left/retrieved.

### Verify Message Timestamps

Ensure that there are no issues related to the timing with which messages are sent. If voicemail is left at 10:13, it shouldn't show a massively different date/time.

### System Call Handlers

If you are utilizing SCH, verify the proper Greetings are playing for relevant call handlers. Verify the TUI options work appropriately.

These checks can be performed prior to the scheduled (or impromptu) work, as well as after for comparisons sake, and to document the relative health of the applications at the time. This can be useful in identifying that your change didn't break something as all was tested good at 2AM on Saturday Morning, and that something else likely broke between then and 8AM on Monday when folks start complaining.

So what do you look for when you perform scheduled work? I'd love to hear it! Think I forgot something important? Let me know! We can all benefit from getting in the habit of defining and following better practices and documentation strategies!

That's it for now! Make sure to follow the blog to get alerts on new posts, check out my Twitter (@kperryuc) where you can also ask UC and DC related questions, suggest post topics, or talk about anything!
