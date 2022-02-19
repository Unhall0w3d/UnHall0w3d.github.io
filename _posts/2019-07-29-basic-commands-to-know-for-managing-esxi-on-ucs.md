---
title: "Basic Commands To Know For Managing ESXi on Cisco UCS-C"
layout: single
date: 2019-07-29T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Cisco
  - UCS
  - VMWare
tags:
  - Cisco
  - ESXi
  - VMWare
  - UCS
  - UCS-C
---

Every so often I need to perform a CIMC Firmware upgrade due to a bug, such as the infamous memory leak per bug [CSCun88303](https://quickview.cloudapps.cisco.com/quickview/bug/CSCun88303), [CSCus63934](https://quickview.cloudapps.cisco.com/quickview/bug/CSCus63934); noted under Field Notice [FN63943](https://www.cisco.com/c/en/us/support/docs/field-notices/639/fn63943.html) for which I've either drafted the Method of Procedure document (to detail the upgrade), or have actually performed the upgrade well over 50 times for this bug alone. (This is not a flex. It wasn't fun.) When I do, part of the initial steps in the process after determining we are hitting the bug is, what CIMC version is compatible with the ESXi version we are running, and based on the bug details, what version can we move to that has the fix that our chassis supports.

<!--more-->

The compatibility matrix I use is here: https://ucshcltool.cloudapps.cisco.com/public/ , and having that is great on it's own, but some of the details asked for -- specifically the Operating System Version and Processor Version I usually don't have in documentation, and if I do, 9/10 times it's not up to date (it's an unfortunate reality for many of us). So what I thought might be useful is to detail some commands that I used regularly.

In most cases there's going to be more than one way to get the data you need, sometimes it's easier to remember one command over another, so I'll try to provide all the ways I know to get what we need.  I also want to add that the output of many of these commands, such as the vmkload_mod commands and esxcfg commands are commonly requested by Cisco TAC when troubleshooting various issues, including instability (driver mismatch issues), storage controller failing, and more.

## System Information

```text
~ # vmware -v
 VMware ESXi 5.5.0 build-3248547
```

```text
~ # vmware -l
 VMware ESXi 5.5.0 Update 3
```

```text
~ # esxcli system version get
    Product: VMware ESXi
    Version: 5.5.0
    Build: Releasebuild-3248547
    Update: 3
```

```text
~ # smbiosDump | grep -A 5 'System Info'
   System Info: #2
     Manufacturer: "Cisco Systems Inc"
     Product: "C260-BASE-2646"
     Version: "A"
     Serial: "FCH12345678"
     UUID: 
```
 
## Storage Device Details

### Notes

```text 
'esxcfg-scsidevs -a' shows all HBA devices with identifying information
'esxcfg-scsidevs -m' shows all VMFS mappings and relates the vmhba name to the VMFS volume, and it's "real name" (e.g. Datastore1)
'esxcfg-scsidevs -A' shows the mappings between HBAs and the devices it provides a path to.
```

```text
~ # vmkload_mod -s megaraid_sas
 vmkload_mod module information
  input file: /usr/lib/vmware/vmkmod/megaraid_sas
  Version: Version 6.604.54.00.1vmw, Build: 1331820, Interface: 9.2 Built on: May 28 2014
  License: GPL
  Required name-spaces:
   com.vmware.driverAPI#9.2.2.0
   com.vmware.vmkapi#v2_2_0_0
  Parameters:
   heap_max: int
     Maximum attainable heap size for the driver.
   heap_initial: int
     Initial heap size allocated for the driver.
   msix_disable: int
     Disable MSI interrupt handling. Default: 0
   cmd_per_lun: int
     Maximum number of commands per logical unit (default=128)
   max_sectors: int
     Maximum number of sectors per IO command
   fast_load: int
     megasas: Faster loading of the driver, skips physical devices!       (default=0)
```

```text
~ # vmkload_mod -s lsi_mr3
 vmkload_mod module information
  input file: /usr/lib/vmware/vmkmod/lsi_mr3
  Version: 0.255.03.01-2vmw.550.3.68.3029944
  License: GPLv2
  Required name-spaces:
   com.vmware.vmkapi#v2_2_0_0
  Parameters:
   max_sectors: int
     Maximum number of sectors per IO command
```

```text
~ # esxcfg-scsidevs -a
 vmhba38 bnx2fc            link-n/a  fcoe.1000f40f1b495c99:2000f40f1b495c99  (0:132:0.0) Broadcom Corporation QLogic 57712 10 Gigabit Ethernet Adapter
 vmhba39 bnx2fc            link-n/a  fcoe.1000f40f1b495c9b:2000f40f1b495c9b  (0:132:0.1) Broadcom Corporation QLogic 57712 10 Gigabit Ethernet Adapter
 vmhba0  ata_piix          link-n/a  sata.vmhba0                             (0:0:31.2) Intel Corporation ICH10 4 port SATA IDE Controller
 vmhba1  ata_piix          link-n/a  sata.vmhba1                             (0:0:31.5) Intel Corporation ICH10 2 port SATA IDE Controller
 vmhba2  megaraid_sas      link-n/a  unknown.vmhba2                          (0:135:0.0) LSI / Symbios Logic MegaRAID SAS GEN2 Controller
 vmhba32 bnx2i             unbound   iscsi.vmhba32                           QLogic 5709 1 Gigabit Ethernet Adapter
 vmhba33 bnx2i             unbound   iscsi.vmhba33                           QLogic 5709 1 Gigabit Ethernet Adapter
 vmhba34 bnx2i             unbound   iscsi.vmhba34                           QLogic 57712 10 Gigabit Ethernet Adapter
 vmhba35 bnx2i             unbound   iscsi.vmhba35                           QLogic 57712 10 Gigabit Ethernet Adapter
 vmhba36 ata_piix          link-n/a  sata.vmhba36                            (0:0:31.2) Intel Corporation ICH10 4 port SATA IDE Controller
 vmhba37 ata_piix          link-n/a  sata.vmhba37                            (0:0:31.5) Intel Corporation ICH10 2 port SATA IDE Controller
```

```text
~ # esxcfg-scsidevs -m
 naa.600605b008de55301b682f19bee11ef3:1                           /vmfs/devices/disks/naa.600605b008de55301b682f19bee11ef3:1 53d6343f-65f9ea4e-602b-508789ad4756  0  ESX1VMFS2
 naa.600605b008de55301b682ed0ba9120cb:3                           /vmfs/devices/disks/naa.600605b008de55301b682ed0ba9120cb:3 53d58476-2724a720-198f-508789ad4756  0  ESX1VMFS1
```

```text
~ # esxcfg-scsidevs -A
 vmhba2      naa.600605b008de55301b682ed0ba9120cb
 vmhba2      naa.508789ad475001bd
 vmhba2      naa.508789ad475000bd
 vmhba2      naa.600605b008de55301b682f19bee11ef3
```

```text
~ # esxcfg-scsidevs -l | egrep -i 'Display Name|Vendor'
    Display Name: Local VMware, Disk (mpx.vmhba0:C0:T0:L0)
    Vendor: VMware,   Model: VMware Virtual S  Revis: 1.0
    Display Name: Local NECVMWar CD-ROM (mpx.vmhba64:C0:T0:L0)
    Vendor: NECVMWar  Model: VMware IDE CDR10  Revis: 1.00
```

```text
~ # esxcli storage vmfs extent list
 Volume Name    VMFS UUID                            Extent Number  Device Name                           Partition
 -------------  -----------------------------------  -------------  ------------------------------------  ---------
 ESX1VMFS2  53d6343f-65f9ea4e-602b-508789ad4756              0  naa.600605b008de55301b682f19bee11ef3          1
 ESX1VMFS1  53d58476-2724a720-198f-508789ad4756              0  naa.600605b008de55301b682ed0ba9120cb          3
```

```text
 ~ # esxcli storage filesystem list
 Mount Point                                        Volume Name    UUID                                 Mounted  Type             Size          Free
 -------------------------------------------------  -------------  -----------------------------------  -------  ------  -------------  ------------
 /vmfs/volumes/53d6343f-65f9ea4e-602b-508789ad4756  ESX1VMFS2  53d6343f-65f9ea4e-602b-508789ad4756     true  VMFS-5  2092722814976  338536955904
 /vmfs/volumes/53d58476-2724a720-198f-508789ad4756  ESX1VMFS1  53d58476-2724a720-198f-508789ad4756     true  VMFS-5  2087622541312  341421588480
 /vmfs/volumes/5ac33538-d615f73a-2183-508789ad4756                 5ac33538-d615f73a-2183-508789ad4756     true  vfat       4293591040    4266524672
 /vmfs/volumes/db6a367e-61e87ec1-6d87-ab51a0986d11                 db6a367e-61e87ec1-6d87-ab51a0986d11     true  vfat        261853184      92631040
 /vmfs/volumes/dca97b75-ecd68014-550e-84c0e21adba7                 dca97b75-ecd68014-550e-84c0e21adba7     true  vfat        261853184      93069312
 /vmfs/volumes/53d5846d-2eea530d-d5ad-508789ad4756                 53d5846d-2eea530d-d5ad-508789ad4756     true  vfat        299712512      88342528
```

## Boot Device Details

### Notes


These commands are used in series to isolate the storage device used to boot from. This has helped me to confirm if FlexFlash is used for boot, or whether the ESXi host boots from local storage or not.

```text
~ # ls -l /bootbank | awk -F"-> " ''
 /vmfs/volumes/db6a367e-61e87ec1-6d87-ab51a0986d11
```

```text
~ # vmkfstools -P /vmfs/volumes/db6a367e-61e87ec1-6d87-ab51a0986d11
 vfat-0.04 file system spanning 1 partitions.
 File system label (if any):
 Mode: private
 Capacity 261853184 (63929 file blocks * 4096), 92631040 (22615 blocks) avail, max file size 0
 UUID: db6a367e-61e87ec1-6d87-ab51a0986d11
 Partitions spanned (on "disks"):
         naa.600605b008de55301b682ed0ba9120cb:5
 Is Native Snapshot Capable: NO
```

```text
~ # esxcli storage core device list | grep naa.600605b008de55301b682ed0ba9120cb
 naa.600605b008de55301b682ed0ba9120cb
    Display Name: Local LSI Disk (naa.600605b008de55301b682ed0ba9120cb)
    Devfs Path: /vmfs/devices/disks/naa.600605b008de55301b682ed0ba9120cb
```

## Network Details

### Note

The command 'ethtool -i vmnicX' is intended to be used against the NICs with a link status of "up". We usually don't need/want information for unused NICs.

```text
~ # esxcli network firewall get
    Default Action: DROP
    Enabled: true
    Loaded: true
```

```text
~ # esxcli network firewall ruleset list | awk '$2 =="true"'
 sshServer              true
 sshClient              true
 dhcp                   true
 dns                    true
 snmp                   true
 ntpClient              true
 CIMHttpServer          true
 CIMHttpsServer         true
 CIMSLP                 true
 iSCSI                  true
 vpxHeartbeats          true
 faultTolerance         true
 webAccess              true
 vMotion                true
 vSphereClient          true
 NFC                    true
 HBR                    true
 DHCPv6                 true
 WOL                    true
 rdt                    true
 cmmds                  true
 vsanvp                 true
 rabbitmqproxy          true
 ipfam                  true
 dynamicruleset         true
```

```text
~ # esxcfg-nics -l
 Name    PCI           Driver      Link Speed     Duplex MAC Address       MTU    Description
 vmnic0  0000:01:00.00 bnx2        Down 0Mbps     Half   50:87:89:ad:47:56 1500   Broadcom Corporation QLogic 5709 1000Base-T
 vmnic1  0000:01:00.01 bnx2        Down 0Mbps     Half   50:87:89:ad:47:58 1500   Broadcom Corporation QLogic 5709 1000Base-T
 vmnic2  0000:03:00.00 igb         Up   1000Mbps  Full   a0:36:9f:3e:b4:60 1500   Intel Corporation I350 Gigabit Network Connection
 vmnic3  0000:03:00.01 igb         Up   1000Mbps  Full   a0:36:9f:3e:b4:61 1500   Intel Corporation I350 Gigabit Network Connection
 vmnic4  0000:03:00.02 igb         Up   1000Mbps  Full   a0:36:9f:3e:b4:62 1500   Intel Corporation I350 Gigabit Network Connection
 vmnic5  0000:03:00.03 igb         Up   1000Mbps  Full   a0:36:9f:3e:b4:63 1500   Intel Corporation I350 Gigabit Network Connection
 vmnic6  0000:84:00.00 bnx2x       Down 0Mbps     Half   f4:0f:1b:49:5c:98 1500   Broadcom Corporation QLogic 57712 10 Gigabit Ethernet Adapter
 vmnic7  0000:84:00.01 bnx2x       Down 0Mbps     Half   f4:0f:1b:49:5c:9a 1500   Broadcom Corporation QLogic 57712 10 Gigabit Ethernet Adapter
```

```text
~ # ethtool -i vmnic2
 driver: igb
 version: 5.3.1
 firmware-version: 1.63, 0x80000aa6, 0.384.130
 bus-info: 0000:03:00.0
 ~ # ethtool -i vmnic3
 driver: igb
 version: 5.3.1
 firmware-version: 1.63, 0x80000aa6, 0.384.130
 bus-info: 0000:03:00.1
 ~ # ethtool -i vmnic4
 driver: igb
 version: 5.3.1
 firmware-version: 1.63, 0x80000aa6, 0.384.130
 bus-info: 0000:03:00.2
 ~ # ethtool -i vmnic5
 driver: igb
 version: 5.3.1
 firmware-version: 1.63, 0x80000aa6, 0.384.130
 bus-info: 0000:03:00.3
```

I want to add some context for the next two commands. Often when I perform a CIMC upgrade the enic/fnic drivers need to be updated, as well as the async drivers in order to bring them into compliance -- if ESXi doesn't need to be upgraded entirely. In order to determine what versions we're currently running and compare it against the compatibility matrix, I use the below commands to grab this data. Do note that you can remove the portions of the command after the pipe and see the full output (most of it is not needed in 99% of scenarios).

Another thing to note, whenever instability occurs with a VM, such as an instance where CVP servers lost their NIC at the ESXi level randomly, Cisco TAC has liked to poke at the enic/fnic drivers and will [try to] require they be brought into compliance in order to move forward in the case, and will [try to] refuse to make progress on the case until this is done. I can't say I've ever had an upgrade of the enic/fnic drivers fix a particular issue, but in the sake of staying in compatibility I'll get them upgraded.

```text
~ # vmkload_mod -s enic | egrep -i 'Version'
  Version: Version 1.4.2.15c, Build: 1331820, Interface: 9.2 Built on: Sep 18 2013
```

```text
~ # vmkload_mod -s fnic | egrep -i 'Version'
  Version: Version 1.5.0.4-1vmw, Build: 1331820, Interface: 9.2 Built on: Sep 18 2013
```

## CPU Details

### Note

The output from 'esxcli hardware cpu list' has been truncated as it reports data PER CORE. 

```text
~ # esxcli hardware cpu list
 CPU:0
    Id: 0
    Package Id: 0
    Family: 6
    Model: 47
    Type: 0
    Stepping: 2
    Brand: GenuineIntel
    Core Speed: 2393999742
    Bus Speed: 132999987
    APIC ID: 0x0
    Node: 0
    L2 Cache Size: 262144
    L2 Cache Associativity: 8
    L2 Cache Line Size: 64
    L2 Cache CPU Count: 2
    L3 Cache Size: 31457280
    L3 Cache Associativity: 24
    L3 Cache Line Size: 64
    L3 Cache CPU Count: 2
```

```text
~ # smbiosDump | grep -A 20 'Processor Info'
   Processor Info: #110
     Payload length: 0x28
     Socket: "CPU1"
     Socket Type: 0x1e (Socket LGA1567)
     Socket Status: Populated
     Type: 0x03 (CPU)
     Family: 0xb5 (Xeon MP)
     Manufacturer: "Intel(R) Corporation"
     Version: "Intel(R) Xeon(R) CPU E7- 2870  @ 2.40GHz"
     Processor ID: 0xbfebfbff000206f2
     Status: 0x01 (Enabled)
     Voltage: 1.2 V
     External Clock: 133 MHz
     Max. Speed: 4000 MHz
     Current Speed: 2400 MHz
     L1 Cache: #112
     L2 Cache: #113
     L3 Cache: #114
     Core Count: #10
     Core Enabled Count: #10
     Thread Count: #20 
Processor Info: #115
     Payload length: 0x28
     Socket: "CPU2"
     Socket Type: 0x1e (Socket LGA1567)
     Socket Status: Populated
     Type: 0x03 (CPU)
     Family: 0xb5 (Xeon MP)
     Manufacturer: "Intel(R) Corporation"
     Version: "Intel(R) Xeon(R) CPU E7- 2870  @ 2.40GHz"
     Processor ID: 0xbfebfbff000206f2
     Status: 0x01 (Enabled)
     Voltage: 1.2 V
     External Clock: 133 MHz
     Max. Speed: 4000 MHz
     Current Speed: 2400 MHz
     L1 Cache: #117
     L2 Cache: #118
     L3 Cache: #119
     Core Count: #10
     Core Enabled Count: #10
     Thread Count: #20
```

This isn't intended to be a comprehensive list of commands for an ESXi host, for that I've fallen extremely short. Regardless of that I hope that you find a command or two that are useful to you. As I'm always looking to add new commands to my tool belt, I'm interested in knowing what commands you use in your UC journey. Let me know in a comment, on Twitter (@kperryuc), or chat with me on LinkedIn!
