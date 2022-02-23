---
title: "Importance of Documentation - ESXi to VM"
layout: single
date: 2019-09-04T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - VMWare
tags:
  - ESXi
  - VMWare
  - Documentation
  - Excel
  - RVTools
---

## Preface

Now, if you're in an environment where you have access to vCenter, or, you have a small deployment in which you only have two ESXi hosts with a Primary and Secondary/DR site, this likely isn't going to help you. Similarly, if you're using a Network Monitoring service or product that has API polling capabilities, you may already have this visualized for you.

You have two sites, "SYR" and "BLD" and you name your devices accordingly, so simply having the list of IPs and Hostnames is sufficient to know what's where. However, there's still a scenario for small deployments where this may be a "nice to have", and in medium to large deployments this is a "must have".

<!--more-->

As an engineer at a Managed Services Provider (MSP), and with my scope of managed devices including the UCS-C/E/B Chassis, UCSM/CIMC, ESXi (5.x-6.x), and the UC VMs on top of them, and considering most of our clients are multinationals with clusters in the US/North America, EMEA, APAC, and auxilliary sites it's often an annoyance to try to track down where a VM is resident without access to vCenter. Is it on "ESXi1, 2 or 3" in Africa? Who knows. Likely unless a document such as what I will describe exists for your org, you probably don't know off hand. And it certainly takes longer to attempt logging into each of the hosts to validate what's resident rather than checking a document quickly.

And maybe you do know. But maybe you contract out to a service desk with engineers that only touch your devices if something breaks, say, once every few weeks (yeah, okay, things break more often than that I know). It's VERY nice to be able to drop a document on them and say "Here's what's where", as opposed to getting called at 2AM because the engaging engineer is feeling lazy and just doesn't want to log in everywhere, or is maybe green and doesn't know that they even can.

## Enter the "%ESXi_to_VM_Mapping%.xlsx" document

I typically name it "ClientName_ESXi_to_VM_Mapping_vX.y.xlsx", and I won't get into semantics when it comes to versioning and document naming, as your org will have its own standard.

This document allows us to organize per sheet the chassis that a given ESXi host sits on, as well as what VMs are on. Makes sense, that's what I've been going on about since I started the post. Really, it's quite a simple document, and you can utilize [RVTools](https://www.robware.net/rvtools/) to quickly gather the information for export.

## Pulling The Data

The information I've found most relevant, as some/most of it is subject to change, is listed below; do note you can pull more info if you wish.

### VM Name

The name of the virtual machine as assigned in ESXi

Example: CUCM Server

### DNS Name

The name of the virtual machine as it's known to the network

Example: BLDCCMPub

### IP Address

The device's IP address. Enough said.

Example: 10.10.10.1

### vCPU

How many virtual CPUs are assigned to the VM (for comparing against OVA template/requirements)

Example: 2 vCPU

### vMem

How much virtual Memory is assigned to the VM  (for comparing against OVA template/requirements) 

Example: 8GB

### vDisk

How many, and how much virtual disk space is assigned to the VM  (for comparing against OVA template/requirements) 

Example: 2x 500GB

### Datastore

The datastore where the VM files are located. This can be useful in the event a datastore goes out of service, it would explain a VM's inability to boot/function.

Example: datastore1

### vTools

VMWare Tools. Are they up to date with the host, or out of date?

Example: Out of Date, Up to Date, Not Running

## Optional Data To Pull (if on Cisco UCS)

### CIMC Name

Hostname given to the CIMC

Example: C240-FCH1999333SS

### Serial Number

Serial number assigned to the CIMC, for use with SmartNET when engaging Cisco TAC.

Example: FCH1999333SS

## Conclusion - Output Exported to CSV/Excel

With this data collected, we fill in our Excel sheet. The way I've found this easiest to understand and explain to fellow engineers is to name the worksheet the ESXi hostname, and include the CIMC/VM details within the worksheet. See the screenshot below.

<span class="image fit"><img src="{{ "/assets/images/importantdocumentation1.png" | absolute_url }}" alt="" /></span>

Bam. I've now got a document I can refer to quickly to determine what's where, that you can provide to any service desk or auxilliary support teams to reference (ideally at a centrally located Sharepoint or similar location. Treat it as a live doc and update as you go!)

These save lives... okay, maybe that's a bit of an over-exaggeration. But it definitely saves time in the long run, and only takes a few minutes (15+) to get the documentation set up, depending on the environment size. These have become a "must have" and is an audit task to create such documentation if it doesn't exist because of how useful it is to engineers that simply don't know the environment's device locations (logical) like the back of their hand.

I hope this is helpful to someone, I sure do fine a lot of use for these documents. Have any ideas for a blog post, or modifications you'd make to this document? Leave a comment! Follow me on twitter (@kperryuc), or join our Discord!
