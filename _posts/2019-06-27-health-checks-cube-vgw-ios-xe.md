---
title: "Health Checks - CUBE/VGW - IOS/XE"
layout: single
classes: wide
date: 2019-06-27T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Cisco
  - IOS
  - Unified Communications
tags:
  - IOS-XE
  - Health Checks
  - Action Plan
  - Gateway
  - Reboot
  - Cisco
  - CUBE
  - Cisco Unified Border Element
  - IOS
  - VGW
---

## 𝄞 This Is How We Do It 𝄞

As mentioned on the blog, I work for a Managed Services Provider. As such I am not a prototypical System Admin that knows a particular environment in and out, backwards and sideways. Often times I am injected into environments and issues that have been ongoing for hours, or days, with only the notes from the previous engineers to go off of.<!--more--> Other times I'm tasked with performing software upgrades or configuration changes based on recommendations from another engineer. There's no quick reference or dashboard that I can check in the environment to say "YEP, we're all good, let's move ahead!". I have to log in to the devices manually and pull a set of output to verify the health of a device before I want to proceed.

Now over time I've built out Bash scripts to perform the work for me based on a set of credentials and IPs passed through the script, and I'll mostly need to concern myself with simply reviewing the output once the script has finished piping the output out to a file. The problem with this method is that when new engineers are on-boarded or promoted and need to follow a similar process I find that it is counter-intuitive to first point them to the script. I want the engineers to understand what output we are pulling from, where are we pulling it from, and why.

That all said, I'd like to detail the commands I use across applicable Cisco VGW/CUBE platforms to gauge the health of a device in order to;

Create a baseline for the device's health and functionality to understand if there are any reasons to halt the work to be performed and reschedule.

Have a defined list of commands to run when the change is done to compare against the baseline and verify that nothing broke in the process of upgrading, reloading, or changing the config. If we see something odd (e.g. previously "up" T1 is now "down") we can verify the behavior and work to isolate the cause and rectify it.

Documentation to "COA" (cover our ass) in the event that something does break, we can verify that the condition did not exist prior to enacting the change and thus was not a known but ignored issue. (These concerns do come up -- trust me.)

In the environments I manage we typically have a mixture of Cisco Routers, VGs and CUBEs -- from Cisco 2800/2900 to 3800/3900 to 4300/4400 to vCube. These commands aren't universal -- they may not apply to one hardware platform or another. What's important is crafting a list of commands for your environment and your devices -- and this may help to start that list.

If any of my readers feel a companion video with sample output would be useful, please let me know! I've been toying with this idea... it's one thing to know what commands to run, it's another thing to know what to look for in the output. And without further adieu, this is my personal list:

## Health Check Commands [IOS]

### show version

Verify device up-time, running IOS image, DRAM/FLASH (to confirm we meet the requirements in the event of an upgrade). Also we want to verify our config register is set properly.

### show running-config

This should be copied out or piped to a file in flash. We need this in the event we need to revert a change, or, a device doesn't come back up and we need to restore it's configuration. Don't only trust your automated backups. Always take a manual copy.

### show environment

This helps check environmental stats on the device. Fans, PSU, Temperatures, Sensors.

### show inventory

What components, modules, etc. do we have in the chassis? Is the chassis a c3900 or c3900e (so we can get the right image for an upgrade, etc.)

### show flash

What files do we have in flash? Do we have 6 IOS bin images from 2012 that could be deleted and free up space? Do we have TCL/Survivability scripts that should be backed up?

### show interfaces

Here I like to verify interface statuses. If a Serial interface d-channel doesn't come back up we want to be able to verify what state it was in before the change started.

### show controller t1/e1

What do the controller stats look like? Are we actively taking errors/slip secs? Do we have active Remote Alarm Indicator (RAI)?

### show isdn status/service

Do we have any channels out of service or busied out?

### show voice call summary || show call active voice brief || show sip calls || show cube calls

Depending on your environment and protocols at use, some commands may not show you that there's active calls on your gateway. I typically include each of these commands to verify that if, for example, "show voice call summary" gives no return, we might see those calls instead under the "show sip calls" command.

### show voice dsp group all || show dsp farm all

Here we want to verify the status of our DSPs, confirm we don't have any stuck in an "APP_DNLDNG" state or other undesired state.

### show ccm-manager || show mgcp || show mgcp endpoint

When using MGCP to control a gateway and it's endpoints we want to verify IF we are using ccm-manager config that we have a good registration to the primary CUCM node, we aren't constantly failing over and aren't failing TFTP config downloads for our managed endpoints. We also want to confirm MGCP itself shows active/active and that the endpoints we want managed are in fact managed by mgcpapp. Lastly I verify the device hostname+domain (if configured) to verify it matches what is configured in CUCM as the device won't register if there's a mismatch.

### show sccp all || show stcapp device summary

Are our SCCP resources, potentially analog ports, conference bridge, transcoder, etc. resources registered?

### show gateway || show gatekeeper status

It's few and far between that I need to check in on a strictly h.323 gateway, especially one that is gatekeeper controlled. Mostly I deal with MGCP/SCCP and SIP, but in the event an h.323 gateway comes my way I need to keep an eye on it's relevant protocol status.

### show sip-ua status || show sip-ua register status

And here we verify our SIP specific detail. If we're looking at Trunks we can verify those from the CUCM page provided we have SIP Options Ping enabled. In fact, I'll be adding a post in the near future on a query to verify a specific trunk's status via AXL!

### show redundancy || show redundancy states || show standby brief || show voice high-availability summary

Last but not least - RRPs. It's not often I deal with router redundancy protocols, I still have commands that are on standby to verify redundancy state, members, and configuration. These can be tuned to your specific redundancy protocol, as mentioned this list isn't an end-all be-all but more a starting point for following a better process when performing our scheduled (and sometimes not scheduled) changes.

### show log

Verify there are no issues in logging that haven't been dealt with that could impact our change. Also good to keep the old logging as, if we're not piping it out to a Syslog server, we'll lose that data after a reload.

These commands are usually used in conjunction with screenshots, SQL output and manual verification against the relevant CUCM nodes for the device. We typically don't just want to trust the IOS device, we also want to verify the devices that are associated with the change and may be indirectly impacted.

So what do you look for when you perform scheduled work? Are you the run-and-gun type that just types "wr" and reboots, or do you verify against your own personal check list of commands? I'd love to hear it! Think I forgot something important? Let me know! We can all benefit from getting in the habit of defining and following better practices and documentation strategies!

That's it for now! Make sure to follow the blog to get alerts on new posts, check out my Twitter (@kperryuc) where you can also ask UC and DC related questions, suggest post topics, or talk about anything!
