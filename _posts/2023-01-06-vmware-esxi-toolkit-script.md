---
title: "VMWare ESXi Toolkit Script"
layout: single
classes: wide
date: 2023-01-06T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - VMWare
  - Python
tags:
  - VMWare ESXi
  - Python
---

## Trying Something New In The New Year

Well... 2023 is here and with it a rush to ban [ChatGPT](https://chat.openai.com) from being used in academia, [MidJourney](https://midjourney.com/home/) causing controversy with its use in [creating AI generated artwork](https://time.com/6240569/ai-childrens-book-alice-and-sparkle-artists-unhappy/#:~:text=But%20the%20book%2C%20Alice%20and,the%20specter%20of%20replacing%20them) for a Children's book that was sold on Amazon, and Kanye West still being... well... Kanye West. I guess some things are just the same as 2022.<!--more--> 

And just like 2022 my curiosity hasn't changed. Although I tend to stay within my realm of Cisco UC when it comes to blog posts and Python scripting, I decided that in 2023 I wanted to start messing with a new API (VMWare's vAPI)... and so naturally I started off the new year using ChatGPT as a creation and research tool to query vAPI for usable data, and to perform actions on the vAPI endpoint. 

### What I Used ChatGPT For

ChatGPT was used, as an experiment, to help generate one-off Python scripts to perform various tasks/requests. The experiment was in seeing how much faster I was able to accomplish a fully working script using an API and modules that I had no familiarity with. 

Generally speaking the query sent to ChatGPT was along these lines:

"Can you create a python script using pyvim and pyvmomi modules to connect to a VMware ESXi host and <perform a function here>, potentially <prompt the user for some kind of decision> and <perform the proper thing based on the users decision>, then <recheck the value and confirm it changed>". Something of this sort.

Now, while I can say this was extremely useful in setting up the skeleton of the script, and at times generated code that worked right off the bat, with fairly verbose code comments, it often did not stick to its own conventions and code flow within the same script, or across scripts. It also, on more occasions than I can count, would provide [VMWare vAPI](https://docs.vmware.com/en/VMware-vSphere/6.7/com.vmware.vsphere.vcenterhost.doc/GUID-871CF0D0-5638-4AE3-BE17-55B91E3EEB61.html) calls that would only work on a vCenter Server that manages the ESXi host you're concerned with.

Errors can be handled by ChatGPT but just feeding them in as a "I ran the script and received this error: 'error here'", and would often apologize and explain that X API call was not valid on ESXi, but would then provide a replacement API call that has the exact same issue.

### How Much Did I Ultimately Use

It's hard to say exactly how much of the code I ended up using, but I would be generous and say about 50% of the code. It's been moved around and tinkered to accommodate the Class I built and was massaged by me. In many cases I had the script (such as in Option 1 of the script) report back a single value and I would manually run the API call, see all the possible data, then start adding in file write or print lines for specific data and built out a report that way. 

I also found myself sticking to the variables that were used by ChatGPT and coding in ITS "style", if it had one, within the given function that I generated a script for. That's one thing to mention, though it doesn't really affect the code. ChatGPT was all over the place with it's produced code in terms of styling and conventions used, and complexity of the code across similar tasks. 

### Would I Use It Again?

Absolutely. It's funny, part of me feels lazy for not learning or struggling through a problem the old way... and part of me loves how much time I am saving by using ChatGPT. Not always, sometimes it wastes my time. But mostly it's very useful and efficient. It helps that ChatGPT does its best to explain what the code does, critical variables, and how to use certain code features. You just have to be bothered to read it, instead of clicking "copy code" and moving on with your day.

## The VMWare ESXi Toolkit Script

Okay. So now that I'm done talking about ChatGPT I'll talk about the script. The script has 7 available options, triggered through a user input menu, to perform actions against a VMWare ESXi host (primarily stand-alone, but can be vCenter managed) that are useful to me in times of performing maintenance, or reviewing an issue. Unless a critical issue happens where use of the script doesn't make sense, or isn't possible, my intention was to allow the maintenance "set-up" work flow to be possible within the script. In my experience as a Cisco UC Engineer, UC related ESXi hosts often have fairly static configurations that rarely change.

### 1 - List ESXi & VM Details

Option 1 prompts an API call to gather various ESXi and VM data including, but not limited to: Vendor, Model, Serial Number, Power State, Connection State, Maintenance Mode, Boot Time, CPU details, Memory details, BIOS details for the ESXi host and Name, Power State, Description, VM Location, Guest OS, vHardware Version, VMTools Status/Up-to-Date, vNIC, vCPU, vMem, and vDisk configurations.

### 2 - List and Download Log Files

Option 2 lists all files in the *'/var/log/'* directory on the target ESXi host and prompts the user to indicate the log files they would like to download. The script then downloads the files to the user's Downloads directory with appropriate date/time and src host information in the file name. SCP and SFTP options are available.

### 3 - Collect ESXi HealthCheck

Option 3 performs a series of 'show' level commands and collects the output, writing it into an appropriately labeled file in the user's Downloads directory. This can be pulled before and after a maintenance window and referred to as needed. It can also be useful for reviewing general information about the ESXi host.

```text
'esxcli system hostname get',
'esxcli system version get',
'vim-cmd vimsvc/license --show',
'esxcfg-scsidevs -l | egrep -i "display name|vendor"',
'vim-cmd vmsvc/getallvms',
'esxcfg-vmknic -l', 
'esxcli hardware platform get', 
'esxcli hardware cpu global get',
'esxcli hardware memory get', 
'esxcli hardware clock get', 
'esxcli system time get',
'esxcli vm process list', 
'esxcli network vm list', 
'esxcli network vswitch standard list',
'esxcli storage vmfs extent list', 
'esxcli storage filesystem list',
'esxcli storage vmfs snapshot list', 
'esxcli storage core adapter list',
'esxcli storage core device list', 
'esxcli system boot device get',
'esxcfg-advcfg -j iovDisableIR', 
'cat /etc/chkconfig.db',
'vmkload_mod -s megaraid_sas | grep Version', 
'vmkload_mod -s igb | grep Version',
'vmkload_mod -s fnic', 'vmkload_mod -s enic', 
'vim-cmd hostsvc/hostsummary'
```

### 4 - Perform a VM Snapshot

Option 4 performs an API call to list out the VMs available on the ESXi host. The user is prompted to select a VM to perform a snapshot. The script confirms the choice and sends an API Task to the ESXi host to perform a snapshot.

### 5 - Perform an ESXi Config Backup

Option 5 sends the requisite commands to the ESXi CLI to perform a config sync, config backup, and finally downloads the tar file containing the backup data to the user's Downloads directory.

### 6 - Power Off/On VM

Option 6 performs an API call to query the current power state of all VMs on the ESXi host and reports a list of VMs IDs, Names, and Power States. It also verifies which VMs have VMTools or 'open-vm-tools' installed, and informs the user of VMs without applicable tools packages and warns them that power operations cannot be performed. The user selects a VM, current power state is checked and based on the result the user is offered to Power On or Off the VM. If a blacklisted VM is selected the user is warned and re-prompted. Power state is re-checked after 60 seconds.

### 7 - Enable/Disable Maintenance Mode

Option 7 performs an API call for the existing state of Maintenance Mode on the target ESXi host. The user is prompted to disable or enable maintenance mode based on the state of the node. It does not currently have verifications (e.g. CAN you perform an enable/disable based on VM states, etc.) but I will look to add that in the near future.

### 8 - Quit

Option 8... quits. Yeah. It also tears down the SSH and HTTPs connections that were established after credential collection.


### In Summary

Overall I think this was a very interesting script creation process and method. In total I think I spent about 30 hours when it came to ideation, creation, testing, iteration, retesting and preparations for 'release-ready' state. There's always ways to improve, and given my lack of vAPI/pyvim/pyvmomi usage prior to the creation of this script, I'd say I've learned quite a bit, though it doesn't directly translate into better code. Still working on that.

## Where To Get The Script

The [ESXi Toolbelt script](https://github.com/Unhall0w3d/mind-enigma/blob/master/VMWare%20Scripts/esxiToolkit.py) can be found on my [GitHub](https://github.com/Unhall0w3d/mind-enigma). Any errors or issues encountered can be lodged as Issues on GitHub and I will work on them at my earliest convenience. You can always join the NOC Thoughts Discord using the link in the side panel. Post recommendations, corrections, and comments can be posted in the *#improvements-requests* chat channel on our Discord server. 

I hope this was informative, and I'd like to thank you for reading! Best of luck in 2023!

