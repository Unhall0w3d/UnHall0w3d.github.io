---
title: "Cisco UCCX Health Checks"
layout: single
classes: wide
date: 2023-02-14T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Cisco
  - Unified Communications
tags:
  - Health Checks
  - Cisco
  - Unified Communications
  - Action Plan
  - Cisco Unified Communications Manager
  - Cisco Unified Contact Center Express
---

## 𝄞 This Is How We Do It 𝄞

And here it is, my list of commands and checks that I run against Cisco Unified Contact Center Express (UCCX) servers for most changes that take place. It's useful output to collect prior to changing configurations, Upgrades, Restarts -- anything that makes a change system-wide or otherwise has the opportunity to "break" the system.<!--more-->

I pull this data to refer back to in the event that the change has disrupted endpoint registration status, inter-cluster communication, intra-cluster communication, MRA, zone connectivity, anything. Consider this output a "CYA" for later. Something to refer back to and confirm all is as it was prior to the change, with applicable exceptions/changes seen in the post-change output.

Without further ado, let's get to it.

## CLI Health Check Commands [UCCX]

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

### show uccx jtapi_client version

Reports back the JTAPI version currently in use on the system.

### show uccx license

Shows UCCX License Data, useful in confirming the licensing state pre/post change.

### show uccx provider ip axl/rmcm/jtapi

Reports back the the AXL, JTAPI, or RMCM provider IP address.

### show uccx version

Shows the system version, similar to show version active/show version inactive.

### show uccx livedata connections

Displays the status of the Socket.IO service and the active client connections (total), as well as long polling clients connected (total).


## Additional Health Check Data To Collect

### RTMT

From RTMT, I recommend taking a screenshot of the System Summary page which includes CPU, Memory and Disk Usage information. Be sure to grab a screenshot of Tools > Alert central as well. You can document and be aware of existing alarms prior to your change, and confirm no new ones generate.

### GUI

From the GUI of UCCX Publisher, take a screenshot of the UCCX Serviceability Page including the Master/Slave (Publisher/Subscriber) state, and the subsystem state ("IN SERVICE", "OUT OF SERVICE", "PARTIAL SERVICE").

### Test Calls

If applicable, and if possible, perform test calls to critical Toll Free Numbers/DIDs that route to UCCX. Ensure proper scripts are hit, options work, any pre-delivery audio required is playing, etc. You'll want to verify this pre- & post-change to verify there are no issues with the call queues.

## Automating the Process

If you're interested in automating the CLI output collection and potentially speeding up the process I've created a basic python script to log in to UCCX via CLI, collect the data, and store it in a file. The script can be found [here](https://github.com/Unhall0w3d/mind-enigma/blob/master/Health%20Check%20Scripts/uccxHealthCheck.py). I often use scripts like this to perform the CLI checks and grab GUI/RTMT screenshots simultaneously. Less time collecting means more time reviewing.

## Finishing Up

At this point your pre-change health checks should have been completed and documented (saved to an applicable internal location, attached to a ticket, etc.), your change completed, and verification steps completed. If something's wrong, you'll likely see it during the verification steps and testing steps. If you don't verify and test, it's possible your users will catch the issue before you. We want to minimize those instances as much as possible with thorough testing.

If the aforementioned is true, it should be safe to proceed to post-change output collection that includes rerunning all previous health check commands run prior to the change, including gathering a second set of appropriately labeled screenshots. These help CYA to prove, to the best of your ability, the status of various configurations and connections. Something may go awry later on, you'll want to prove it was good and working after the change. Not to say the change (upgrade, restart, etc.) won't introduce an issue that crops up later, but at least you can prove there wasn't a drop or miss on your part.

And that's it! Hopefully this is helpful. If there are any commands or GUI pages that you feel were missed, or that you include in your health check process feel free to pitch in by joining the NOC Thoughts Discord and posting in the #improvements-requests channel.