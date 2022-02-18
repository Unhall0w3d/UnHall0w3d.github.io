---
title: "Cisco Call Manager - Checking Device Registration using Python"
date: 2021-06-01T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Cisco
  - Python
tags:
  - CUCM
  - Python
  - Python3
  - Cisco Unified Communications Manager
  - Callmanager
  - AXL
  - automation
  - scripting
  - Unified Communications
  - Cisco UC
  - Cisco
---

Hey! You there! Yes, you! Are you sick of only checking Cisco Phone registration in Cisco Unified Communications Manager through the GUI, having to take the time to log in, wait for web pages to load, have a maximum pagination of 250 phones and having to search strictly by defined search parameters in the GUI? Want to be able to search for a custom list of phones and verify their registration state? What about by device pool, or all phones? Boy, do I have a script for you.

<!--more-->

Now to start, scripting for me isn't necessarily about creating the most efficient, the most feature complete script in the world. It is, however, about creating a purpose built tool (and readme file!) that can be digested, understood, and used by both Junior and Senior engineers alike and produces the expected results reliably. Could I make some changes and remove a function? Probably. Could I condense down some of the lines and loops? Certainly. There is always room for optimization, however, premature optimization can lead you down a rabbit hole and lead to you never completing your script or program at all.

The way I handle this is by creating a 'proof of concept' version of the script, something that just works and does exactly what I want it to do even if it might take a few too many lines of code. (And trust me, I've learned that scripts do exactly what you tell them to, even if that isn't what you want them to do.) From there I start optimizing, drawing out reusable code into their own functions, adding reach-ability checks and nice-to-haves. With that out of the way, and without further adieu, let me introduce the phoneRegCheck.py script I've been working on.

### UPDATE

This script was deprecated and lost over time. A more recent version with more options can be found on my [Github](https://github.com/Unhall0w3d/mind-enigma/blob/master/phoneRegCheck.py).

### UPDATE

As the script is rather long to include in a blog post I highly advise you to click over to the github link if you'd like to download the script, or view the code itself. What I'll do here is explain the intent of the script (from the perspective of the person creating it, using it, and advocating for its use) as well as how to use the script.

Intent: The intention behind the script is to be able to verify, against UCM's applicable APIs, if a given set of devices is registered or not. This may be by device pool, it may be against all devices configured in the system (useful for pre/post CUCM upgrade health checks!!) or by a pre-defined list where the group of phones is not dictated by Device Pool. I will often need to search for a random group of devices that deregistered within a certain time frame and are one-off network issues (keep alive timeouts, connectivity errors) and are not grouped in a way that makes them easily searchable in bulk.

Usage: The script does not use an argparse method, so input is collected through input(). On first start the script will verify if the 'tmp/' folder exists in the current directory. If not, we'll print a message to inform the user that the tmp folder was created, and generated reports will be stored there. The script will prompt to search by option 1, 2, or 3 -- Device Pool, Text File, or All Devices.

## Option 1

Prompts for user input, performs a DB Dip on UCM via SOAP to determine available Device Pools on the system, asks which one you want, then performs a second DB Dip to pull devices associated with the provided device pool. These returned devices are parsed and fed into a loop to query against the AST interface for real time registration data.

## Option 2

Prompts for user input, for the text file containing the device names, one per line, then parses that file and constructs a comma separated string that is fed into a loop to query against the AST interface for real time registration data.

## Option 3

Prompts for user input, performs a DB Dip on UCM via SOAP to pull all devices configured in the system. These returned devices are parsed and fed into a loop to query against the AST interface for real time registration data.

Reporting output is stored as two .txt files with one device's status per line. The two files are named Registered* and Unregistered* and contain the devices that are, you guessed it, registered or unregistered. They are stored in the ///tmp/ folder.

## Invoking the Script and Selecting an Option

<span class="image fit"><img src="{{ "/assets/images/phoneregcheck1.png" | absolute_url }}" alt="" /></span>

## User Input Collection

<span class="image fit"><img src="{{ "/assets/images/phoneregcheck2.png" | absolute_url }}" alt="" /></span>

## Option 1 Only - Device Pool Selection

<span class="image fit"><img src="{{ "/assets/images/phoneregcheck3.png" | absolute_url }}" alt="" /></span>

## Informational...

<span class="image fit"><img src="{{ "/assets/images/phoneregcheck4.png" | absolute_url }}" alt="" /></span>

## Status Report

<span class="image fit"><img src="{{ "/assets/images/phoneregcheck5.png" | absolute_url }}" alt="" /></span>

And there we go. Looking at the contents of the file we can see some of the data related to the phones if registered. For unregistered devices we simply state that the device isn't registered.

Example RegisteredDevicesReport contents are below; excess output was omitted as file contents can be lengthy depending on device count.

```text
10.1.1.2 SEPBC16F517F626 VPN Phone - Summer Smith - 7962 Registered
10.1.1.3 SEP00A289FAA96E VPN Phone - Rick Sanchez - 8851 Registered
10.1.1.4 CIPCRSANCHEZ Rick Sanchez - CIPC Registered
10.1.1.5 SEP1C1D862F6808 VPN Phone - Morty Smith - 7962 Registered
```

Example UnregisteredDevicesReport contents are below; excess output was omitted as file contents can be lengthy depending on device count.

```text
Device RSANCHEZ_RDP is not registered.
Device CUCIRSANCHEZ is not registered.
Device CUCIMSMITH is not registered.
Device CIPCMSMITH is not registered.
```

Boom. We now have the data we need to determine if devices are registered or deregistered in bulk through a few different search methods, and state-of-registration reports if pulled for all devices. You could use this data to confirm the devices registered/unregistered during your system pre-change health checks, such as when performing an upgrade, intrusive cop file install, or quarterly reboots.

Is it perfect? Nah. Is it pretty? Only in a certain light. Does it get the job done? You bet. Now I hope this script can be useful in trimming down the amount of time required to validate device status after an impactful event, or even as a pre-change check. Issues can be raised against the script on GitHub, as well as feature requests. I thank you for reading, you can find me on LinkedIn (@kperryuc) and on Twitter (@kperryuc, @thoughtsnoc). Have some feedback? Join our Discord!
