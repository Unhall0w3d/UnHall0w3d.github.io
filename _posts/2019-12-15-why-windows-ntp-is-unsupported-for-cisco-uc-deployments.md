---
title: "Windows NTP Is Not Supported In Cisco UC"
layout: single
classes: wide
date: 2019-12-15T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Unified Communications
  - Cisco
  - Windows
tags:
  - Cisco Unity Connection
  - Cisco
  - Cisco Unity
  - Cisco UC
  - Cisco Emergency Responder
  - Unified Communications
  - Cisco UCCX
  - UCCX
  - Contact Center Express
  - Cisco IM&P
  - Cisco Presence Server
---

## Windows NTP Is A No-Go

So as we all know as part of the UC VOS Deployments, NTP Servers are one element that needs to be configured during install time... and occasionally needs to be updated as things change on the network.  For those of you unsure of what devices are UC VOS, please see the list below.

<!--more-->

- Cisco CallManager
- Unity Connection
- Emergency Responder
- IM & Presence
- Media Sense
- Intelligence Center
- Finesse
- Contact Center Express

These devices all run on the same UC VOS Platform (as seen in a 'show status' command). And as part of the NTP deployment some of our basic responsibilities are to confirm that we have reachability to the NTP server through commands such as 'utils network ping ntp-ip' and 'utils network connectivity ntp-ip'. In later versions, such as 11.5, we can issue a 'utils network connectivity ntp-ip port 123', and we can verify connectivity to the NTP server on the NTP port itself.

Another responsibility that is often overlooked in the deployments I have worked in post-install is to ensure that the NTP server deployed supports NTPv4, and uses NTPv4 as it's network time protocol. A byproduct of this requirement that is often overlooked is that Windows based NTP servers should not be used in the environment. This is due to Windows NTP implementation being sNTP (Simple NTP). Due to this, when an NTP Client packet is received at the Windows based NTP server, an NTPv3 Server packet will be returned.

Now, most folks that keep up with NTP and the difference in the versions, what they support, what they don't, will know that NTPv4 is backwards compatible with NTPv3, so this should all be fine, right? Well, not in Cisco's case. As with most things, Cisco seems to have fiddled with their ntpdate implementation and do not support NTPv3. As I'll show in the example below, using a Windows based NTP server -- even if it works initially, is not stable and is not supported by Cisco.

## Supporting Documentation

[Relevant Support Forum Post](https://community.cisco.com/t5/ip-telephony-and-phones/ntp-unsynchronised-in-cucm/m-p/2309599#M244609)

### Opened to Add NTPv4 requirement to SRND

[Cisco Bug](https://quickview.cloudapps.cisco.com/quickview/bug/CSCte17541)

### Lists Requirement for NTPv4, supports Windows is not supported

[Cisco NTP Troubleshooting Document](https://www.cisco.com/c/en/us/support/docs/unified-communications/unified-communications-manager-callmanager/118718-technote-cucm-00.html)

## Behavior

1. NTP shows as Unsynchronized when issuing a 'utils ntp status'.
2. NTP servers defined are Domain Controllers (Windows based NTP).
3. No issue with NTP prior to environment power down for 2 days.

## Symptoms

-NTP Shows as Unsynchronized
admin:utils ntp status
ntpd (pid 20559) is running…
unsynchronised
time server re-starting
polling server every 64 s
Current time in UTC is : Sat Dec 14 11:49:11 UTC 2019
Current time in America/Los_Angeles is : Sat Dec 14 03:49:11 PST 2019

## Troubleshooting

### When performing a packet capture on port 123 we can see a client packet sent out as NTPv4, with a server response of NTPv3.

```text
admin:utils network capture port 123
05:21:02.186421 IP iptlab-ccmpub.iptlab.corp.42930 > iptlab-dc2.iptlab.corp.ntp: NTPv4, Client, length 48
05:21:02.186606 IP iptlab-dc2.iptlab.corp.ntp > iptlab-ccmpub.iptlab.corp.42930: NTPv3, Server, length 48
05:21:02.187176 IP iptlab-ccmpub.iptlab.corp.42930 > iptlab-dc2.iptlab.corp.ntp: NTPv4, Client, length 48
05:21:02.187312 IP iptlab-dc2.iptlab.corp.ntp > iptlab-ccmpub.iptlab.corp.42930: NTPv3, Server, length 48
05:21:02.187344 IP iptlab-ccmpub.iptlab.corp.42930 > iptlab-dc2.iptlab.corp.ntp: NTPv4, Client, length 48
05:21:02.187457 IP iptlab-dc2.iptlab.corp.ntp > iptlab-ccmpub.iptlab.corp.42930: NTPv3, Server, length 48
05:21:02.187487 IP iptlab-ccmpub.iptlab.corp.42930 > iptlab-dc2.iptlab.corp.ntp: NTPv4, Client, length 48
05:21:02.187595 IP iptlab-dc2.iptlab.corp.ntp > iptlab-ccmpub.iptlab.corp.42930: NTPv3, Server, length 48
05:21:02.377404 IP iptlab-ccmpub.iptlab.corp.43404 > iptlab-dc5.iptlab.corp.ntp: NTPv4, Client, length 48
05:21:02.377678 IP iptlab-dc5.iptlab.corp.ntp > iptlab-ccmpub.iptlab.corp.43404: NTPv3, Server, length 48
05:21:02.377712 IP iptlab-ccmpub.iptlab.corp.43404 > iptlab-dc5.iptlab.corp.ntp: NTPv4, Client, length 48
05:21:02.377860 IP iptlab-dc5.iptlab.corp.ntp > iptlab-ccmpub.iptlab.corp.43404: NTPv3, Server, length 48
05:21:02.377883 IP iptlab-ccmpub.iptlab.corp.43404 > iptlab-dc5.iptlab.corp.ntp: NTPv4, Client, length 48
05:21:02.378005 IP iptlab-dc5.iptlab.corp.ntp > iptlab-ccmpub.iptlab.corp.43404: NTPv3, Server, length 48
05:21:02.378026 IP iptlab-ccmpub.iptlab.corp.43404 > iptlab-dc5.iptlab.corp.ntp: NTPv4, Client, length 48
05:21:02.378151 IP iptlab-dc5.iptlab.corp.ntp > iptlab-ccmpub.iptlab.corp.43404: NTPv3, Server, length 48
05:21:02.548419 IP iptlab-ccmpub.iptlab.corp.33463 > iptlab-dc5.iptlab.corp.ntp: NTPv4, Client, length 48
05:21:02.548671 IP iptlab-dc5.iptlab.corp.ntp > iptlab-ccmpub.iptlab.corp.33463: NTPv3, Server, length 48
05:21:02.549371 IP iptlab-ccmpub.iptlab.corp.33463 > iptlab-dc5.iptlab.corp.ntp: NTPv4, Client, length 48
05:21:02.549505 IP iptlab-dc5.iptlab.corp.ntp > iptlab-ccmpub.iptlab.corp.33463: NTPv3, Server, length 48
05:21:02.550477 IP iptlab-ccmpub.iptlab.corp.33463 > iptlab-dc5.iptlab.corp.ntp: NTPv4, Client, length 48
05:21:02.550609 IP iptlab-dc5.iptlab.corp.ntp > iptlab-ccmpub.iptlab.corp.33463: NTPv3, Server, length 48
05:21:02.551367 IP iptlab-ccmpub.iptlab.corp.33463 > iptlab-dc5.iptlab.corp.ntp: NTPv4, Client, length 48
05:21:02.551485 IP iptlab-dc5.iptlab.corp.ntp > iptlab-ccmpub.iptlab.corp.33463: NTPv3, Server, length 48
```

### Attempting to add an alternate NTP server on the network that has NTPv4, but no port 123 reachability

```text
admin:utils ntp server add 172.30.2.174
172.30.2.174 : [ Inaccessible NTP server. Not added. ]
```

### Due to NTP issues, dbreplication cannot set up in the cluster between Pub/Subs

```text
admin:utils dbreplication runtimestate
Server Time: Sat Dec 14 05:15:51 PST 2019
Cluster Replication State: Replication status command started at: 2019-03-13-04-19
Replication status command COMPLETED 681 tables checked out of 681
Last Completed Table: devicenumplanmapremdestmap
No Errors or Mismatches found.
Use 'file view activelog cm/trace/dbl/sdi/ReplicationStatus.2019_03_13_04_19_40.out' to see the details
DB Version: ccm10_5_2_12901_1
Repltimeout set to: 300s
PROCESS option set to: 1
Cluster Detailed View from iptlab-ccmpub (5 Servers):
SERVER-NAME IP ADDRESS (msec) DbMon? QUEUE Group ID (RTMT) & Details
----------- ---------- ------ ------- ----- ----------- ------------------
iptlab-ccmpub 172.30.100.21 0.016 Y/Y/Y 0 (g_2) (3) Out Of Sync
iptlab-ccmsub1 172.30.100.25 0.157 Y/Y/Y 391694 (g_3) (3) DB Active-Failed
iptlab-ccmsub2 172.30.100.36 0.224 Y/Y/Y 391842 (g_4) (3) DB Active-Failed
iptlab-ccmsub3 172.30.100.35 0.374 Y/Y/Y 394074 (g_5) (3) DB Active-Failed
iptlab-ccmsub4 172.30.100.24 0.348 Y/Y/Y 394222 (g_6) (3) DB Active-Failed
```

### Checking Port 1500 connectivity for Database Layer shows Established connectivity

```text
admin:show open ports regexp 1500
Executing.. please wait.
dbmon 29042 database 11u IPv4 60853 0t0 TCP 172.30.100.21:35262->172.30.100.21:1500 (ESTABLISHED)
dbmon 29042 database 113u IPv4 76652 0t0 TCP 172.30.100.21:35281->172.30.100.21:1500 (ESTABLISHED)
dbmon 29042 database 114u IPv4 76655 0t0 TCP 172.30.100.21:48897->172.30.100.35:1500 (ESTABLISHED)
dbmon 29042 database 115u IPv4 76658 0t0 TCP 172.30.100.21:57778->172.30.100.36:1500 (ESTABLISHED)
dbmon 29042 database 116u IPv4 76659 0t0 TCP 172.30.100.21:60899->172.30.100.25:1500 (ESTABLISHED)
dbmon 29042 database 117u IPv4 76660 0t0 TCP 172.30.100.21:39591->172.30.100.24:1500 (ESTABLISHED)
dbmon 29042 database 662u IPv4 556131 0t0 TCP 172.30.100.21:41603->172.30.100.21:1500 (ESTABLISHED)
dbmon 29042 database 664u IPv4 557166 0t0 TCP 172.30.100.21:41621->172.30.100.21:1500 (ESTABLISHED)
dbmon 29042 database 679u IPv4 557780 0t0 TCP 172.30.100.21:41637->172.30.100.21:1500 (ESTABLISHED)
dbmon 29042 database 685u IPv4 559313 0t0 TCP 172.30.100.21:41672->172.30.100.21:1500 (ESTABLISHED)
```

So there we have it. Cisco says NTPv3 isn't supported. In this particular instance we were getting back NTPv3 Server packets which are primarily rejected and invalidates the NTP server leaving us unsynchronized.  As shown, it can have consequences relating to dbreplication, general date/time data displayed on CCM and thus on endpoints that rely on CCM for NTP and more.

Proper planning and due diligence go a long way here. Read Cisco documentation, blog posts, and actively lab whatever you can relating to the Cisco devices you support. This isn't something that is covered on a CCNA/CCNP Voice or Collab exam, and thus would likely not come up during study.  Normally I see this come up as a 'lesson learned' for the client after batting down every 'can't you just restart the service/server to fix this?' and 'it was working before, so it must have been something you did'. Deploy it correctly, follow SRND where applicable and possible.

If you've found this post to be helpful please leave a like, or a comment and let me know! Have an idea for a post, or a topic you'd like covered? Let me know what, and how in depth and we'll try to make it happen! Follow me on Twitter (@uckperry) or find me on LinkedIn for post announcements. You can also join the Discord!