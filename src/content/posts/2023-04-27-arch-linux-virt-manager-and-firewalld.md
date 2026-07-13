---
title: "Virt-Manager, Firewalld, & Missing libvirt Zone"
layout: single
classes: wide
date: 2023-04-26T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Linux
  - Arch
tags:
  - Linux
  - Arch
  - EndeavorOS
  - General
---

## What Are We Doing Here

Well, that's a good question. As part of a "30 day challenge" that may just end up being permanent, I've challenged myself to switch my daily driver PC from Windows 11 to Linux.<!--more--> My daily driver is the machine I play games on with my son, do lab work with virtual machines, python coding, manage the NOCThoughts website, and use for virtually anything else. Ultimately what I wanted to see was whether or not Linux was viable, or if the programs I used, games I wanted to reliably play, and peripherals I use would all be supported without spending days on a single issue to get something functional that should "just work". So far, about 7 days in, it's been mostly smooth. Let's talk about it.

## A Little Preparation, And A Little Context

As part of the preparations to switch to linux I did what most would do - took note of what games I wanted reinstalled on Steam and other launchers, took note of what programs were 'must haves' at a 1:1 feature ratio, and what I could use alternative applications for. And finally I went about moving anything I wanted to keep to secondary storage.

I also started looking at what distro I wanted to run. I started with [Arch Linux](https://archlinux.org/) and, after getting annoyed with the tedious setup of trying to get Wayland/Hyprland set up with a greeter and having absolutely no fun doing it, I switched over to a more "user ready" distro of [Garuda Linux](https://garudalinux.org/). Though I didn't stick with this distro, I did keep the "fish", "konsole" and "starship" configurations as I really enjoyed the terminal layout and functionality. I didn't really run into any issues, but I was having an issue getting the system to boot after installing a custom kernel and rebuilding initramfs, so I switched again.

The last install, and what I have been running since, is [EndeavorOS](https://endeavouros.com/), also an Arch Linux variant. I was able to install the [Liquorix](https://liquorix.net/) kernel and have had not had the issues I was having on Garuda. You can see the major feature list on Liquorix's website.

## The Problem

This leads me into Virt Manager and Firewalld. Firewalld is installed, and enabled, by default on EndeavorOS. Just a fun fact. As part of setting my programs back up, I chose virt-manager and virt-viewer along with qemu. After installing the packages and attempting to make a virtual machine I was met with an error similar to "A "libvirt" zone does not exist. Firewalld is using nftables on the backend, please switch to iptables or rebuild libvirt with --allow-libvirt-zone.". Not exact, but pretty close to what I saw.

This prevented me from creating a virtual machine and kept me stumped for about 30 minutes. I did some googling based on the suggestions I saw and did not think switching from nftables to iptables was really something I wanted to undertake, and I couldn't find much information in my hasty searching about rebuilding libvirt with the right flags. What I did do, however, was poke around the file system. While looking around I found that the zone information for Firewalld is held within "/etc/firewalld/" in the "zones" folder.

## The Solution

Inside the "zones" folder was a public.xml file that contained the configuration for the public zone within the firewall. Looked interesting. After finding, in my google search, what the contents of the libvirt.xml file should be, I performed the following steps to resolve my issue:

```
1. Open terminal of choice
2. Change directory to the zones folder
    a. cd /etc/firewalld/zones/
3. Create a file named libvirt.xml using your preferred command line text editor
    a. sudo nano libvirt.xml
4. Paste contents of the libvirt.xml file noted below. Read the description.

____COPY STARTING AT THE LINE BELOW____
<?xml version="1.0" encoding="utf-8"?>
<zone target="ACCEPT">
  <short>libvirt</short>

  <description>
    The default policy of "ACCEPT" allows all packets to/from
    interfaces in the zone to be forwarded, while the (*low priority*)
    reject rule blocks any traffic destined for the host, except those
    services explicitly listed (that list can be modified as required
    by the local admin). This zone is intended to be used only by
    libvirt virtual networks - libvirt will add the bridge devices for
    all new virtual networks to this zone by default.
  </description>

<rule priority='32767'>
  <reject/>
</rule>
<protocol value='icmp'/>
<protocol value='ipv6-icmp'/>
<service name='dhcp'/>
<service name='dhcpv6'/>
<service name='dns'/>
<service name='ssh'/>
<service name='tftp'/>
</zone>
_____STOP COPYING AT THE LINE ABOVE_____


5. Save and write out
    a. ctrl+x
    b. y
    c. Enter
```

At this point switching back to the Firewall program's GUI should show the libvirt zone. Issuing the command "virsh net-start default" returns successfully and a virtual machine can be created. To make the virtual network autostart, the command "virsh net-autostart default" will make it start at boot.

## Lesson Learned

The lesson learned here, at least in my opinion, is that when general searches for error messages don't lead you to a viable answer (I ended up on a lot of posts/pages that were generic and not specific to my issue with virt manager, or specific error message), it may be a good idea to fire out some pointed google searches based on what you're seeing in the errors or what you know. For instance, I performed some searches about the libvirt.xml file name and contents, confirmed the location was what I thought it should be, and proceeded to test.

Coming from the land of Cisco where most of what I need in terms of search results to my queries are found in the first 3 links, searching for answers to Linux questions just seems to lead me to 8 generic posts that are copy/paste from the last, 12 out of date posts with command syntaxes that are incorrect or that point to unavailable resources online, a few people with the same issue and no noted solution, an article for a bug that points to another duplicate article that points to another duplicate article that... you get the idea.

The information's there, clearly, as I was able to find it to help resolve my issue. But boy is it buried.

Hopefully this post is able to help someone else that comes across the same error and doesn't end up in the pile of endless linux blog posts... who am I kidding, I know it will. Thanks for reading! If you'd like to suggest post topics, discuss a post with the author or be a part of the community you can join the NOC Thoughts Discord! Have a good one!