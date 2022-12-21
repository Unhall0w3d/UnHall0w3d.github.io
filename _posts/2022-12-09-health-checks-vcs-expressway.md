---
title: "Health Checks - VCS/Expressway"
layout: single
classes: wide
date: 2022-12-09T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Cisco
  - Unified Communications
tags:
  - Health Checks
  - Cisco
  - Unified Communications
  - Telepresence
---

## 𝄞 This Is How We Do It 𝄞

And here it is, my list of commands and checks that I run against Cisco VCS-C/E & Expressway-C/E servers for most changes that take place. It's useful output to collect prior to changing configurations, Upgrades, Restarts -- anything that makes a change system-wide or otherwise has the opportunity to "break" the system.<!--more-->

I pull this data to refer back to in the event that the change has disrupted endpoint registration status, inter-cluster communication, intra-cluster communication, MRA, zone connectivity, anything. Consider this output a "CYA" for later. Something to refer back to and confirm all is as it was prior to the change, with applicable exceptions/changes seen in the post-change output.

Without further ado, let's get to it.

## CLI Health Check Commands [VCS/Expressway]

### xstatus SystemUnit

Returns data such as the Serial Number, Product Name, Build info, some configuration options such as Encryption, Dual NIC, Expressway feature set, Registration count, Traversal Call count, device name, Release Key, Software Version, and TimeZone/DateTime configuration. It will also include the system uptime in 'epoch' time (e.g. 12023815).

### xstatus Hardware

Returns data such as the CPU speed, Core Affinity (if applicable), Memory Total, CPU Model Details, Network Adapters, Non-Traversal Call Limit, Logical Core Count, Physical CPU count, Physical to Logical core mappings, Registration, Traversal Call and Turn Relay limits.

### xstatus

Returns an assortment of output also viewable via the GUI including but not limited to Intrusion Protection, Links, Zones, Media Statistics, Microsoft IMP, configured Options, Policies, Port usage, Resource usage, SIP Configuration and connectivity status, SIP service domains, SIP service zones, Zones, System metrics, TURN server status, Warnings, XMPP connection status and more.

### xconfiguration

Returns configuration data for various elements including Zones, Transforms, Timezone, SNMP, SIP, Policies, NTP, Option Keys, Login configs and more.

### configlog|eventlog|networklog 100

With this we will collect the last 100 entries in the Config, Event and Network logs. This can be expanded by increasing the '100' number in the command.

## GUI Health Check Snapshots [VCS/Expressway]

It is worth noting that the screenshots that I collect (described below) are primarily redundant due to the output already being present in the 'xstatus' command run from the CLI. In that case, these would be optional. To ensure thoroughness and to ensure I have snapshots to refer back to of specific configuration and status pages, I collect these anyway. Some pages, such as the Status > Overview and Status > Unified Communications pages do not present output in the 'xstatus' command.

### Status > Overview

Provides an overview of the VCS/Expressway you are logged in to.

### Status > Alarms

This is similar to the 'xstatus alarm' output and contains data on the alarms that are, or have been raised on the system and not yet acknowledged and cleared.

### Status > System > Information

This is similar to the 'xstatus SystemUnit' output. See the CLI command description for more detail.

### Status > System > ResourceUsage

This is similar to the output from 'xstatus Resourceusage' and contains data on resource utilization on the Expressway server.

### Status > Registrations > By Device

This is applicable to Cisco VCS-C / VCS-E only. Data is reported on the current registrations against VCS. Alternatively the CLI command "xstatus applications presence" could be used, although this is included in the base "xstatus" command output.

### Status > Calls > Calls

This is similar to the output from xstatus Calls which displays active calls on the system, and details about them.

### Status > LocalZone

Here we collect information on connected/disconnected Local Zones. Alternatively the command "xstatus Zones LocalZone SbuZone" can be used, although this is included in the base 'xstatus' command output.

### Status > Zone

In addition to taking a screenshot of the configured Zones, it is advised to also open the configuration page for the Zone with Type "Traversal Client". Verify the status and take a screenshot. Be sure to do the same with the "Unified Communications Traversal" zone.

### Status > Unified Communications

It is always good to verify the status of the Unified Communications server connections, and refresh them after a change. If applicable, take a screenshot of the Advanced Status > View Federated Connections page. Primarily, the SSH tunnel status.

### Status > Hardware

This is similar to the 'xstatus Hardware' output. See the CLI command description for more detail.

### System > Time

The data here is also available in the 'xstatus' base command, and is visible under a scoped 'xstatus Time' command. We use this to verify system time and NTP configuration.

### System > Clustering

This data is also gatherable by using the 'xstatus cluster' command, and is included in the base 'xstatus' command output. Here we see the status of the VCS/Expressway cluster.

### System > External Manager

This data is also gatherable by using the 'xstatus ExternalManager' command, and is included in the base 'xstatus' command output. This shows the status of configured External Manager. If unconfigured, status should show "Inactive".

## Taking a Backup

### Maintenance > Backup and Restore

To take a backup, navigate to the Maintenance > Backup and Restore page. Under Backup, regarding the Encryption Password, you are not required to enter an encryption password. If you do, document it well and do not lose it as restoration will require the use of the encryption password.

To proceed with a backup, click on "Create System Backup File" and, when prompted, save the file to an appropriate location and ensure it is stored according to your internal backup storage policies.

## Verification Steps

Prior to moving into the full post-change data collection (re-collecting the same data as the pre-checks for comparison purposes) it is important to perform some quick verification steps. This will aid in resolving some odd behaviors or catching issues with day to day function quickly. Think of it as a spot check. If the spot check is good, we'll start full health checks.

### Rediscover Unified Communications Servers

Any time work is performed on VCS/Expressway OR associated Cisco Unified Communications Server, Unity Connection and IM & Presence servers it is important to perform manual discovery of the associated UC servers and services. This can be performed via the Expressway-C/VCS-C webpage.

### Configuration > Unified Communications > Unified CM Servers

On this page we'll want to click on the Unified CM Servers under Publisher Address and click the "Refresh Servers" button. After this completes, review the TCP status and ensure it shows "TCP: Active" with no errors. The same steps should be completed for associated IM & Presence and Unity Connection servers under their applicable Configuration > Unified Communications > * page.

### MRA Test, if applicable

Using a test Jabber account, or remote MRA enabled Cisco phone (or other applicable device), verify that MRA login is possible (from off-net, which means turning off your VPN before launching and connecting using Jabber). Once logged in via MRA, perform basic chat, presence status, and contact lookup tests. Test persistent and non-persistent chat rooms as applicable, as well as WebEx creation and calendar functions, and voicemail access. If your business uses Cisco Jabber to control Cisco Phones via CTI, ensure this is working as well. Additionally, test internal and external dialing. For Telepresence users, test sending and receiving Video calls. Include tests for any features not mentioned that are critical or relied on by your business relating to the UC devices connecting to, through, or utilizing the VCS/Expressways.

## Finishing Up

At this point your pre-change health checks should have been completed and documented (saved to an applicable internal location, attached to a ticket, etc.), your change completed, and verification steps completed. If something's wrong, you'll likely see it during the verification steps and testing steps. If you don't verify and test, it's possible your users will catch the issue before you. We want to minimize those instances as much as possible with thorough testing.

If the aforementioned is true, it should be safe to proceed to post-change output collection that includes rerunning all previous health check commands run prior to the change, including gathering a second set of appropriately labeled screenshots. These help CYA to prove, to the best of your ability, the status of various configurations and connections. Something may go awry later on, you'll want to prove it was good and working after the change. Not to say the change (upgrade, restart, etc.) won't introduce an issue that crops up later, but at least you can prove there wasn't a drop or miss on your part.

And that's it! Hopefully this is helpful, this process has been followed for x8.x through x12.x software versions. If there are any commands or GUI pages that you feel were missed, or that you include in your health check process feel free to pitch in by joining the NOC Thoughts Discord and posting in the #improvements-requests channel.