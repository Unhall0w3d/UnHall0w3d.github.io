---
title: "And Boom Goes The Storage Controller"
layout: single
date: 2019-06-26T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Cisco
  - UCS
  - Unified Communications
tags:
  - UCS
  - UCS-C
  - Storage
  - Cisco UCS
  - Crash
  - Cisco
  - Data Center
  - Virtualization
---

Story time. It's a wonderful day in early April. The birds are singing, Spring is upon us. We had a lovely drive in to work, it was an easy morning. We break for lunch and have some pizza delivered to work for the team to share. Just a great day.

<!--more-->

## The Story Begins

Boom. All of this changes as a UCS-C server blows up. Resident VMs, a mixture of CUCM nodes as well as a CVP server and two Agent PGs all stop responding to ICMP. Hypervisor's still responding though. We start to get reports of agents kicked out of Finesse. Phones having failed over to a secondary, or tertiary node. This is the last thing we want on such a nice day.

The first thing I do is take a quick second to try to understand what issues are happening and potential root causes. I think about what is the most likely cause, or causes for a particular issue and do a quick spot check. Is this something that can easily be checked in a minute or two? If so, let's check real quick while we firm up the details from the user reports. Knowing -- through our preferred monitoring application -- that we lost ICMP on the aforementioned servers, I immediately want to check the UCS Chassis and Hypervisor. We log in to ESXi and are graced with powered on VMs. "This doesn't make sense", I said. So I pop open the console to CUCM. Then CVP. As I move along I witness the same thing -- a non-responsive console. The VMs are stuck.


## Into The Action

I don't have the ability to gracefully shut the VMs down due to the hanging condition so I bite the bullet and power off/power on the VMs to restore service while I investigate root cause. Given the Hypervisor was on, responsive, and seemingly didn't experience any issues I thought "whatever caused this seems to have resolved... but I need to look at the hardware." I thought this for two reasons:

1. Get a handle on any potential failures from the hardware perspective and if necessary line up a replacement. We don't want this to happen again.

2. Whatever issue occurred it impacted multiple VMs simultaneously. If there was a hypervisor level issue I would expect ESXi itself to be behaving oddly or show some symptoms, or, that only one VM would be impacted. If it's storage (given the VMs were all hosted on the same storage) it would impact them all, and is a good spot check before I dig into the logs.

### Look to the UCS Chassis

Logging into the UCS Chassis via CIMC I quickly throw some commands into the CLI.

```text
scope chassis
show storageadapter
scope storageadapter SLOT-3
show detail
show virtual-drive
show physical-drive
```

These commands provide me the storageadapter name (SLOT-3) so that I can scope into it, the detail regarding the storageadapter (showing Optimal at the time), the virtual-drive status, and the physical-drive status.

```text
BoulderUCSC# scope chassis
BoulderUCSC /chassis # show storageadapter
 PCI Slot     Health         Controller Status Product Name                       Serial Number  Firmware Package Build Product ID Battery Status Cache Memory Size Boot Drive     Boot Drive is PD 
 SLOT-3       Good           Moderate Fault LSI MegaRAID SAS 9261-8i           Serial#         FW#           LSI Logic  discharging    346 MB            65535          false
```

```text
BoulderUCSC /chassis/storageadapter # show virtual-drive
 Virtual Drive Health         Status               Name             Size       RAID Level Boot Drive 
 0             Moderate Fault Degraded             VirtualDisk1    1996036 MB RAID 5     false
 1             Good           Optimal              VirtualDisk2    1996036 MB RAID 5     false
```

```text
BoulderUCSC /chassis # scope storageadapter SLOT-3
BoulderUCSC /chassis/storageadapter # show detail
 PCI Slot SLOT-3:
     Health: Moderate Fault
     Controller Status: Optimal
     Product Name: LSI MegaRAID SAS 9261-8i
     Serial Number: Serial#
     Firmware Package Build: FW#
     Product ID: LSI Logic
     Battery Status: discharging
     Cache Memory Size: 346 MB
     Boot Drive: 65535
     Boot Drive is PD: false
```

```text
BoulderUCSC /chassis/storageadapter # show physical-drive
 Physical Drive Number Controller Health         Status                 Manufacturer   Model          Predictive Failure Count Drive Firmware Coerced Size   Type 

1                     SLOT-3     Good           Online                 SEAGATE        ST300MM0006    0                        0001           285148 MB      HDD
 2                     SLOT-3     Failed        Offline                SEAGATE        ST300MM0006    0                        0001           285148 MB      HDD
 3                     SLOT-3     Good           Online                 SEAGATE        ST300MM0006    0                        0001           285148 MB      HDD
 4                     SLOT-3     Good           Online                 SEAGATE        ST300MM0006    0                        0001           285148 MB      HDD
 5                     SLOT-3     Good           Online                 SEAGATE        ST300MM0006    0                        0001           285148 MB      HDD
 6                     SLOT-3     Good           Online                 SEAGATE        ST300MM0006    0                        0001           285148 MB      HDD
 7                     SLOT-3     Good           Online                 SEAGATE        ST300MM0006    0                        0001           285148 MB      HDD
 8                     SLOT-3     Good           Online                 SEAGATE        ST300MM0006    0                        0001           285148 MB      HDD
 9                     SLOT-3     Good           Online                 SEAGATE        ST300MM0006    0                        0001           285148 MB      HDD
 10                    SLOT-3     Good           Online                 SEAGATE        ST300MM0006    0                        0001           285148 MB      HDD
 11                    SLOT-3     Good           Online                 SEAGATE        ST300MM0006    0                        0001           285148 MB      HDD
 12                    SLOT-3     Good           Online                 SEAGATE        ST300MM0006    0                        0001           285148 MB      HDD
 13                    SLOT-3     Good           Online                 SEAGATE        ST300MM0006    0                        0001           285148 MB      HDD
 14                    SLOT-3     Good           Online                 SEAGATE        ST300MM0006    0                        0001           285148 MB      HDD
 15                    SLOT-3     Good           Online                 SEAGATE        ST300MM0006    0                        0001           285148 MB      HDD
 16                    SLOT-3     Good           Online                 SEAGATE        ST300MM0006    0                        0001           285148 MB      HDD
```

There we go. We have a drive failure. I raise a Cisco TAC case and request an RMA, providing UCS CLI output as proof of drive failure. I also generate a [Tech Support File](https://www.cisco.com/c/en/us/support/docs/servers-unified-computing/ucs-manager/115023-visg-tsfiles-00.html) and upload it to the TAC case. The engineer responds back, processes the RMA for the drive just like we want. They also respond back with a snippet of logging from the UCS chassis identifying a fault storage controller. AHHA! Before I had time to get back in and hunt down the cause of the VMs hanging, TAC had provided the root cause of our VM hanging issue. It had taken a back seat to the drive issue as coordinating the replacement and ensuring the 4 hour turnaround time was critical to prevent any further issues (as RAID 5 can only tolerate one drive failure).


## Spell It Out -- What Happened?

What was a great day turned into very busy afternoon having to deal with the rammifications of not only a failed hard drive, but also the LSI storage controller! As we see in the log detail below, the controller did in fact fail. I've notated the logs below to make them easier to digest.

### Controller data reports stale, encounters a fatal error

```text
 6:2019 April 02 14:12:03:BMC:storage:-: ctlr.c:1315:Controller data might be stale, FW cannot resume the CMD over OOB since it is not active., errno=32815 
```

### CIMC reports Storage Controller in SLOT-3 as inoperable. Reseat or replace

```text
 2:2019 April 02 14:12:04:BMC:fault-engined:-: %CIMC-2-EQUIPMENT_INOPERABLE:[F1004][critical][equipment-inoperable][sys/rack-unit-1/board/storage-SAS-SLOT-3] Storage controller SLOT-3 inoperable: reseat or replace the storage controller SLOT-3  
```

### This causes an error on Virtual Drive 0 and 1. Storage is lost for the VMs causing the hang condition

```text
 2:2019 April 02 14:12:05:BMC:fault-engined:-: %CIMC-2-EQUIPMENT_INOPERABLE:[F1007][critical][equipment-inoperable][sys/rack-unit-1/board/storage-SAS-SLOT-3/vd-0] Storage Virtual Drive 0 is inoperable: Check storage controller, or reseat the storage drive  
 2:2019 April 02 14:12:06:BMC:fault-engined:-: %CIMC-2-EQUIP 
 MENT_INOPERABLE:[F1007][critical][equipment-inoperable][sys/rack-unit-1/board/storage-SAS-SLOT-3/vd-1] Storage Virtual Drive 1 is inoperable: Check storage controller, or reseat the storage drive  
```

### To add a cherry on top, we have a bad BBU on the RAID controller

```text
 3:2019 April 02 14:12:07:BMC:fault-engined:-: %CIMC-3-EQUIPMENT_INOPERABLE:[F0531][major][equipment-inoperable][sys/rack-unit-1/board/storage-SAS-SLOT-3/raid-battery] Storage Raid Battery SLOT-3 is inoperable: Check Controller battery  
 4:2019 April 02 14:12:14:BMC:storage:-: SLOT-3: PD 11a(e0x00/s0) Path 5000c500588feca1  reset (Type 03) 
```

### Shortly after the failing condition (appx 1 minute) we receive a cleared state for previous alarms

```text
 6:2019 April 02 14:13:12:BMC:fault-engined:-: %CIMC-6-EQUIPMENT_INOPERABLE:[F1004][cleared][equipment-inoperable][sys/rack-unit-1/board/storage-SAS-SLOT-3] Storage controller SLOT-3 inoperable: Cleared  
 6:2019 April 02 14:13:13:BMC:fault-engined:-: %CIMC-6-EQUIPMENT_INOPERABLE:[F1007][cleared][equipment-inoperable][sys/rack-unit-1/board/storage-SAS-SLOT-3/vd-0] Storage Virtual Drive 0 inoperable: Cleared  
 6:2019 April 02 14:13:14:BMC:fault-engined:-: %CIMC-6-EQUIPMENT_INOPERABLE:[F1007][cleared][equipment-inoperable][sys/rack-unit-1/board/storage-SAS-SLOT-3/vd-1] Storage Virtual Drive 1 inoperable: Cleared  
 6:2019 April 02 14:13:15:BMC:fault-engined:-: %CIMC-6-EQUIPMENT_INOPERABLE:[F0531][cleared][equipment-inoperable][sys/rack-unit-1/board/storage-SAS-SLOT-3/raid-battery] Storage Raid Battery SLOT-3 inoperable: Cleared  
```

## The End

So in the end we replaced the controller, a drive, and a BBU/Storage controller battery. What a day, what a night. I have to hand it to the folks at TAC on this one. Although I (hopefully) would have identified the storage controller issue they saved us precious time by noting all errors viewed, not just the one I reported on. Do I ever want to deal with this type of failure again? No, not really. Will I? Probably next week. Drive and storage controller issues are fairly commonplace for me now as a large percentage of my client base utilizes older UCS chassis, like UCS C22, UCS C220, 240, and 260 -- early models.  V1 CPUs, not V2. You know the kind.

And there we go. The story of how a wonderfully pleasant day turned into a manic conference call filled afternoon. Unlike my other posts that are more geared towards teaching or providing useful commands and insights, this one was a bit therapeutic. A way to reminisce on a very stressful 6-7 hours with a refreshed mindset and far less frustration over the abruptness that is virtually every issue I seem to run into. I just hope next time it's just a single hard drive... please...

I hope this was a fun little read for you! As always if there are any questions, comments, or suggestions please leave a comment or reach out to me on Twitter (@kperryuc)!