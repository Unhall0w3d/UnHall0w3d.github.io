---
title: "Calculating Virtual Memory Usage on UC VOS using SNMP"
date: 2021-08-30T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Cisco
  - Unified Communications
tags:
  - CUCM
  - SNMP
  - CUC
  - Cisco Unity
  - Cisco Unified Communications Manager
  - Callmanager
  - UC VOS
  - UC
  - snmpwalk
  - snmptable
  - UCCX
  - Unified Communications
  - Cisco UC
  - Cisco
  - Contact Center Express
  - Virtual Memory
---

<head>
    <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-7351461893377144"
     crossorigin="anonymous">
     </script>
</head>

So if you’re here you’re likely aware that there are multiple ways that we can review system resource utilization on a Cisco UC VOS appliance — we’ll use Cisco Unified Communications Manager for this example. Of course we can utilize RTMT to take a look at graphs showing resource utilization over time, we can review CLI based commands such as ```show process using-most cpu|memory```, ```show process load cpu|memory```, or even ```show perf query class Memory```. We can also poll usage remotely using SNMP, and I’d like to show you how we can calculate Virtual Memory utilization as a percentage using data returned by SNMP, then verify it in the CLI.

<!--more-->

Now in my capacity as a ‘Day 2’ Engineer at a Managed Services Provider, and having the MSP I work for design it’s own scripts, tests, methods, and platform for monitoring a myriad of devices, UC included, I at times am assisting in the creation of a new test method, assisting in modifying existing monitoring for more accurate reporting, or looking at possibly older or defunct scripts that are no longer required, are an old method that will be deprecated, or tests that simply don’t provide the value they were intended to provide. It’s all part of the life cycle.

One such example is calculating Virtual Memory utilization in UC VOS Appliances. There is a difference in monitoring this resource using SNMP from Cisco’s perspective as opposed to a standard linux method. For standard Linux distributions I’ll explain a standard way to do this. It would be to essentially perform an snmpwalk against the desired host for the Virtual Memory OID (or could be pulled using an snmptable command). You take the Used Value and divide it by the Total Value and get your percentage. However, in Cisco UC VOS the device views Virtual Memory as a combination of the Physical and Virtual Memory (SWAP) values, so it gets slightly trickier to accurately report this. Let’s put some math and command output to that and it will all become clear.

For Cisco UC, my preferred way to verify Virtual Memory usage on a system is ‘show perf query class Memory’. This command provides us, among other things, an indication of how much Memory, Paging file, and Virtual Memory is used. Notice how all 3 of those are separate values.

```text
admin:show perf query class Memory
==>query class :

 - Perf class (Memory) has instances and values:
                    -> % Mem Used                     = 53
                    -> % Page Usage                   = 62
                    -> % VM Used                      = 61
                    -> Buffers KBytes                 = 545440
                    -> Cached KBytes                  = 2148412
                    -> Free KBytes                    = 116360
                    -> Free Swap KBytes               = 202084
                    -> Page Faults Per Sec            = 0
                    -> Page Major Faults Per Sec      = 2
                    -> Pages                          = 170414537
                    -> Pages Input                    = 170414538
                    -> Pages Input Per Sec            = 259
                    -> Pages Output                   = -1
                    -> Pages Output Per Sec           = 0
                    -> Shared KBytes                  = 106544
                    -> SlabCache                      = 377888
                    -> SwapCached                     = 0
                    -> Total KBytes                   = 5993924
                    -> Total Swap KBytes              = 2031512
                    -> Total VM KBytes                = 8025436
                    -> Used KBytes                    = 3290256
                    -> Used Swap KBytes               = 1829428
                    -> Used VM KBytes                 = 5119684
```

Now the reason this becomes tricky is that, if one of the two requisite memory values is high, namely ‘% Page Usage’ (also stated as virtual memory/SWAP — the verbiage usage gets sloppy, I know. Blame Cisco.) and the other usage is low, ‘% Mem Used’ we can end up with a low ‘% VM Used’ value in this output, but SNMP reporting on the Virtual Memory value will be high, as it’s a correlation to the Page File, not true Virtual Memory as calculated by Cisco.

So now from the SNMP Side, for this, we perform an snmptable command with a few options selected. We parse the HOST-RESOURCES-MIB for the hrStorageTable contents and start doing some math. When we run this against the node in question we’ll need the SNMP RO String, and target IP. The rest of the command can be left alone.

```text
user@linuxbox:~$ snmptable -v2c -c '********' -O0b -Cil -Ln -m HOST-RESOURCES-MIB 1.2.3.4 hrStorageTable
SNMP table: HOST-RESOURCES-MIB::hrStorageTable

index hrStorageIndex hrStorageType                        hrStorageDescr                       hrStorageAllocationUnits hrStorageSize hrStorageUsed hrStorageAllocationFailures
1     1              HOST-RESOURCES-MIB::hrStorageTypes.2 Physical RAM                         4096 Bytes               1498481       778450        0                   
2     2              HOST-RESOURCES-MIB::hrStorageTypes.3 Virtual Memory                       4096 Bytes               507878        457353        0                   
3     3              HOST-RESOURCES-MIB::hrStorageTypes.4 /                                    4096 Bytes               5079873       3167883       0                   
4     4              HOST-RESOURCES-MIB::hrStorageTypes.1 /proc                                4096 Bytes               0             0             0                   
5     5              HOST-RESOURCES-MIB::hrStorageTypes.1 /sys                                 4096 Bytes               0             0             0                   
6     6              HOST-RESOURCES-MIB::hrStorageTypes.1 /dev/pts                             4096 Bytes               0             0             0                   
7     7              HOST-RESOURCES-MIB::hrStorageTypes.4 /partB                               4096 Bytes               5071823       3164926       0                   
8     8              HOST-RESOURCES-MIB::hrStorageTypes.4 /grub                                1024 Bytes               253871        45623         0                   
9     9              HOST-RESOURCES-MIB::hrStorageTypes.4 /common                              4096 Bytes               17385172      6851898       0                   
10    10             HOST-RESOURCES-MIB::hrStorageTypes.1 /dev/shm                             4096 Bytes               749240        26636         0                   
11    11             HOST-RESOURCES-MIB::hrStorageTypes.1 /proc/sys/fs/binfmt_misc             4096 Bytes               0             0             0                   
12    12             HOST-RESOURCES-MIB::hrStorageTypes.1 /var/log/ramfs/cm/trace/ccm/sdi      4096 Bytes               32768         0             0                   
13    13             HOST-RESOURCES-MIB::hrStorageTypes.1 /var/log/ramfs/cm/trace/ccm/sdl      4096 Bytes               32768         251           0                   
14    14             HOST-RESOURCES-MIB::hrStorageTypes.1 /var/log/ramfs/cm/trace/ccm/calllogs 4096 Bytes               32768         15            0                   
15    15             HOST-RESOURCES-MIB::hrStorageTypes.1 /var/log/ramfs/cm/trace/ccm/dntrace  4096 Bytes               32768         0             0                   
16    16             HOST-RESOURCES-MIB::hrStorageTypes.1 /var/log/ramfs/cm/trace/lbm/sdl      4096 Bytes               32768         654           0                   
17    17             HOST-RESOURCES-MIB::hrStorageTypes.1 /var/log/ramfs/cm/trace/cti/sdi      4096 Bytes               32768         0             0                   
18    18             HOST-RESOURCES-MIB::hrStorageTypes.1 /var/log/ramfs/cm/trace/cti/sdl      4096 Bytes               32768         199           0                   
```

Now what we end up calculating here is effectively the ‘% VM Used’ value provided in the ‘show perf query class Memory’ output. This calculation and the requisite steps to pull this data is important primarily when trying to automate review of system utilization, or to verify the command output is correct via an alternate source - SNMP Agent.

For step 1, gathering the relevant data from the snmptable output, I group the required data for physical, and virtual memory values.

## Step 1: Gather the following values for Physical RAM and Virtual Memory

```text
hrStorageAllocationUnits (phys) 4096
hrStorageSize (phys) 1498481       
hrStorageUsed (phys) 778450        

hrStorageAllocationUnits (vmem) 4096
hrStorageSize (vmem) 507878        
hrStorageUsed (vmem) 457353       
```

For step 2, we’re concerned with two values — TotalRAMBytes (total RAM available, in bytes) and RAM Usage (current RAM usage, in bytes).

## Step 2: Calculate Physical Memory

```text
hrStorageAllocationUnits * hrStorageSize = TotalRAMBytes
hrStorageAllocationUnits * hrStorageUsed = RAM Usage

4096 * 1498481 = 6137778176 = TotalRAMBytes
4096 * 778450 = 3188531200 = RAM Usage
```

Step 3 is the same as Step 2, except for SWAP/Virtual/Paging memory. TotalSWAPBytes (total SWAP available, in bytes) and SWAP Usage (current SWAP usage, in bytes).

## Step 3: Calculate SWAP Memory

```text
hrStorageAllocationUnits * hrStorageSize = TotalSWAPBytes
hrStorageAllocationUnits * hrStorageUsed = SWAP Usage

4096 * 507878 = 2080268288 = TotalSWAPBytes
4096 * 457353 = 1873317888 = SWAP Usage
```

And in comes the formula. We add the two values for current usage together, divide it by the two values for total available added together and we get our virtual memory value as a decimal value. We multiply it by 100 to receive the usage as a percent value.

## Step 4: Calculate VMEM usage

```text
(RAM current usage + SWAP current usage) / (TotalRAMBytes + TotalSWAPBytes) = VMEM usage

(3188531200 + 1873317888) / (6137778176 + 2080268288) = (5061849088) / (8218046464)

(5061849088) / (8218046464) = 0.6159431088852992

0.6159431088852992 * 100 = 61%
```

There we go. To get to the same value that ‘% VM Used’ shows in the ‘show perf query class Memory’ output, we need to combine the two memory types, Physical and SWAP/Paging, not just calculate SWAP itself. Weird, but if you’re only looking at the SWAP/Paging file you won’t be able to reconcile the SNMP and device command output and it may leave you wondering why the reported values are off.

I hope this post is useful, and if not, at least informative as it relates to system resource utilization and reporting for Cisco UC VOS. If you have any post requests, other suggestions or want to chat, find me on Twitter (@kperryuc, @thoughtsnoc) or on LinkedIn, using the social buttons in the header. And remember, have a great day!
