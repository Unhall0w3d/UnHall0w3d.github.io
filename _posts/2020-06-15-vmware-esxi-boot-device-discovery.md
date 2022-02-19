---
title: "VMWare ESXi Boot Device Discovery"
layout: post
date: 2020-06-15T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - VMWare
tags:
  - esxcli
  - Command Line
  - ESXi
  - VMWare
  - Shell
  - VMWare ESXi
  - Linux
  - Unix
---

<span class="image fit"><img src="{{ "/assets/images/esxibootdevicediscovery.png" | absolute_url }}" alt="" /></span>
The view after SSHing into an ESXi Host. In this picture we check the version of ESXi running on the system.

Oh how I love ISV1 SmartNET contracts. Provided that we have an ISV1 contract available we’re able to contact Cisco TAC to assist in VMWare ESXi Hypervisor issues. It’s a wonderful thing, really, as it provides us with engineers specialized in supporting the hypervisor in a more in depth way, and with respect to the Cisco UCS chassis hardware. Now, Cisco typically sends out initial information gathering emails when an SR is open. For Hypervisor issues the most common question I am asked is “what is the hypervisor booting from?”.

<!--more-->

Now, normally you’d think that we could answer that off the top of our heads, right? Small/medium sized companies may have at most 4 or 8 UCS chassis for Unified Collaborations, and typically they are all configured in a similar manner… however I have the joy of supporting a wide variety of deployments, so it’s not always the same. Because of this I have documented some commands that assist in identifying the boot device (FlexFlash, Local LSI, SAN) in order to give Cisco the data that they need. Even if it isn’t associated with a Cisco TAC SR, it’s still useful to know these details and how to pull them. I like to know multiple ways to pull a set of information, and in this case we could identify boot device by checking:

```text
1. UCS CIMC BIOS
2. VMWare vSphere Client/WebUI
3. VMWare ESX Shell
```

Today I’ll be detailing the esxcli commands issued through the VMWare ESX Shell required to determine what device we are booting from, what type it is, what’s the associated identifiers and more. Let’s get to it, but before we do please know that SSH needs to be enabled and port 22 reachable on the ESXi Server you’re issuing these commands on.

Login to the ESXi Host using “ssh username@ip-addr”

Run the below command to determine the boot volume. This will return a directory structure that includes the UUID of the given storage unit.

## Determine the Boot Volume

```text
~ # ls -l /bootbank | awk -F"-> " '{print $2}'
/vmfs/volumes/f3512b78-bf3b7cad-7894-c76c8646a5b6
```

Use the output provided in the previous step and issue the below command to gather details on the file system and partition associated with the UUID, as well as the disk identifier.

## Dump the File System Details

```text
~ # vmkfstools -P /vmfs/volumes/f3512b78-bf3b7cad-7894-c76c8646a5b6
vfat-0.04 file system spanning 1 partitions.
File system label (if any):
Mode: private
Capacity 261853184 (63929 file blocks * 4096), 123760640 (30215 blocks) avail
UUID: f3512b78-bf3b7cad-7894-c76c8646a5b6
Partitions spanned (on "disks"):
        naa.600605b008afce501b05352b89f78b69:5
Is Native Snapshot Capable: NO
```

Use the output provided in the previous step and issue the below command to gather the boot device details. We will utilize the identifier provided under “Partitions spanned (on “disks”):”.

## Confirm the Boot Device Details

```text
~ # esxcli storage core device list | grep -A27 naa.600605b008afce501b05352b89f7
8b69
naa.600605b008afce501b05352b89f78b69
   Display Name: Local LSI Disk (naa.600605b008afce501b05352b89f78b69)
   Has Settable Display Name: true
   Size: 855444
   Device Type: Direct-Access
   Multipath Plugin: NMP
   Devfs Path: /vmfs/devices/disks/naa.600605b008afce501b05352b89f78b69
   Vendor: LSI
   Model: MR9271-8i
   Revision: 3.45
   SCSI Level: 5
   Is Pseudo: false
   Status: on
   Is RDM Capable: false
   Is Local: true
   Is Removable: false
   Is SSD: false
   Is Offline: false
   Is Perennially Reserved: false
   Queue Full Sample Size: 0
   Queue Full Threshold: 0
   Thin Provisioning Status: unknown
   Attached Filters:
   VAAI Status: unsupported
   Other UIDs: vml.0200000000600605b008afce501b05352b89f78b694d5239323731
   Is Local SAS Device: false
   Is USB: false
   Is Boot USB Device: false

mpx.vmhba0:C0:T24:L0
   Display Name: Local CISCO Enclosure Svc Dev (mpx.vmhba0:C0:T24:L0)
   Has Settable Display Name: false
   Size: 0
   Device Type: Enclosure Svc Dev
```

Based on the output from the final command listed above, we can confirm that this particular ESXi is booting from a Local LSI Disk, has a model number of MR9271-8i, is hardware revision 3.45, has an SCSI Level of 5 and is a direct access device.

Simply running through these commands and providing the associated output to TAC has always satisfied the request for ‘where is this ESXi host booting from’ and can help identify if Cisco FlexFlash is even being used, or if you’re booting from a Local disk or SAN (if you don’t know and need to do some quick discovery).

I thank you for reading, you can find me on LinkedIn and Twitter using our social buttons. Have some feedback, or something you’re trying to get output for and want some help with the command syntax? Join the Discord!
