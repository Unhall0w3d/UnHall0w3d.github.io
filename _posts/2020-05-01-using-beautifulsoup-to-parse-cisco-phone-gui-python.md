---
title: "Using BS4 To Parse Cisco Phone WebGUI"
layout: single
date: 2020-05-01T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Python
  - Cisco
tags:
  - Automation
  - Cisco Callmanager
  - Cisco
  - Cisco UC
  - Call Manager
  - Script
  - Python
  - Python3
  - Unified Communications
  - Reports
  - Cisco Phone
  - Status Report
  - Cisco Jabber
  - Database
---

## When You Just Want Some BeautifulSoup

I want to start this blog post off by prefacing the below script I'm providing by stating that I am not formally trained, nor have I studied at length Python or coding in general. I completed a Visual Basic VB.Net 2005 college level course back in highschool (11 years ago, as of 2020). From there I did absolutely nothing related to coding.

<!--more-->

<span class="image fit"><img src="{{ "/assets/images/beautifulsoup.png" | absolute_url }}" alt="It's just a sample image." /></span>

About 3-4 years ago I had a small hand in producing a sample script (in bash) that would log into a Cisco Unified Communications Manager (or IM&P, or CUC, or CER... you get the deal. Any VOS appliance) and run a list of commands against the server CLI and pipe all output to a text file. Not only was it shoddy, but it ran commands against a server even if we knew there would be no output. For example, "show cuc cluster status" against a CUCM is going to error out as a command... but that was my first attempt at automating pulling health check data. Later on this project was picked up by my colleagues and converted first to PHP, then Python -- and then expanded to include a whole host of UC related technologies.

Since then I've sat around watching the wonderful automation of simple/time consuming tasks and thought "why can't I do that?"... well it turns out I can. With a whole heaping dose of frustration, relearning programming terms and conventions and a whole new language, and these things called modules that add functionality to Python. I've written 3 scripts since I've started learning Python. I haven't progressed into error handling or much of the advanced work one might expect from a script you'd use in production, but, I have created what I believe to be some useful scripts -- that I intend on iterating on to make them as good as I can.

That said, let's move on to why we're here.

## Use Case

The intention in creating this script and what I hoped to accomplish was to aid in data collection and identifying Cisco IP Phones model/mac address and active registered node information from the GUI of the phone itself.

## What Made Me Want To Do This?

Cisco Unified Communications Manager creates syslogs for many, many events. One of which is the DeviceTransientConnection syslog. This generates for a single reason with quite a few different causes. Let's review [Cisco Documentation](https://www.cisco.com/c/en/us/td/docs/voice_ip_comm/cucm/err_msgs/8_x/ccmalarms802.html).

```text
CCM_CALLMANAGER-CALLMANAGER-4-DeviceTransientConnection : A device attempted to register but did not complete registration  Device IP Address [String] Device Name [String] Device MAC Address [String] Protocol [String] Device type [Enum]Reason Code [Enum]Connecting Port [UInt] Registering SIP User [String] IPv6Address [String] IPAddressAttributes [Enum]IPv6AddressAttributes [Enum]Explanation   A connection was established and immediately dropped before completing registration. Incomplete registration may indicate that a device is rehoming in the middle of registration. The alarm could also indicate a device misconfiguration, database error, or an illegal/unknown device trying to attempt a connection. Network connectivity problems can affect device registration, or the restoration of a primary Unified CM may interrupt registration.
```

The difficulty is that, in my experience, this syslog likes to provide the IP Address of the device that prompted the syslog to generate, but not the MAC address/device name. Now if you've worked in UCM you know that you can't search by IP address within the GUI, typically we would search based on Device Name (SEP<MAC>, CIPC<MAC>, CSF<MAC>.. etc). So in order to find those missing details we would normally need to browse to the phone using lynx (text based browser), Chrome/IE/FF/etc. and gather those details... here enters the script.

## The Script

The script is written in Python 3 syntax with a few modules -- re (Regular Expression), requests, collections (OrderedDict) and bs4 (BeautifulSoup -- html parser). Previous iterations of the script used a subprocess to run a curl command but parsing html using traditional awk/sed/grep tools just wasn't what I wanted and felt like a cheap way out of using python... by using python to run typical Linux commands. We did away with that. The script and any future works can be found on my [Github Repo](https://github.com/Unhall0w3d/mind-enigma).

{% highlight Python linenos %}

#!/usr/var/python
# -*- code:UTF-8 -*-

#####################################
# Script created by Ken Perry, 2020 #
#####################################

# Modules Imported for Script Functionality
import re
import requests
from bs4 import BeautifulSoup
from collections import OrderedDict


# Phone Collection function that asks for a number for how many phones we'll check, then their IP addresses.
# TO DO: Modify phonecollection function to utilize input from file.
def phonecollection():
    num_phones = int(input('How many phones?: '))
    if type(num_phones) != int:
        print('Error: Expected Integer.')
        exit(1)
    ip_list = []
    for i in range(num_phones):
        ip_list.append(input('What is the phone IP address?: '))
    return ip_list


# Web Scrape function that uses requests to get webpage content.
# Content is then parsed by lxml (or html.parser) and BeautifulSoup is used to extract data based on regular expression.
def phoneregcheck(ip_addr):
    uris = OrderedDict({
        '/CGI/Java/Serviceability?adapter=device.statistics.configuration': ['SEP*|CIPC*', 'Active'],
        '/localmenus.cgi?func=219': ['SEP*', 'Active'],
        '/NetworkConfiguration': ['SEP*', 'Active'],
        '/Network_Setup.htm': ['ATA*|SEP*', 'Active'],
        '/Network_Setup.html': ['SEP*', 'Active'],
        '/?adapter=device.statistics.configuration': ['DX*', 'Active'],
    })
    for uri, regex_list in uris.items():
        try:
            response = requests.get(f'http://', timeout=6)
            if response.status_code == 200:
                parser = BeautifulSoup(response.content, 'lxml')
                for regex in regex_list:
                    data = parser.find(text=re.compile(regex))
                    if data:
                        print(data)
                break
        except requests.exceptions.Timeout:
            print('Connection to ' + ip_addr + ' timed out. Trying next.')
        except Exception as e:
            print('The script failed. Contact script dev with details from your attempt and failure.')
            print(e)


# Run collection for how many phones we will connect to, as well as the IP Addresses.
# TO DO: Create prompt with options, based on option selected (e.g. 1), run function tied to (1)
phone_ips = phonecollection()

# Now loop for each appended IP Address and run webScrape function
[phoneregcheck(ip_addr) for ip_addr in phone_ips]

{% endhighlight %}

## Noted Caveat

This works on Cisco Conference Phones (7937G style) and newer IP Phones (CIPC, 9951, 8851, 7960, etc). If the URL structures unique to these phones does not work, we provide an exception to indicate this back to the user.

## Example Run
Here's an example of the script run against a local Cisco IP Communicator and 8851. The output was sanitized. Notice how we get a good clean return for both devices. Nice. Not only do I know what kind of phone it is I also have it's device name (as it registers to CCM) as well as the Active node FQDN/IP, if one is active. 

```text
kenneth@ubuntu:~/Scripts/CiscoScripts$ python transientPhones_v2.py
How many phones?: 2
What is the phone IP address?: 1.1.1.1
What is the phone IP address?: 2.2.2.2
Cisco Unified IP Phone Cisco Communicator ( CIPCKPERRY ) 
['SERVER-FQDN   Active']
Cisco IP Phone CP-8851 ( SEPAABBCCDDEEFF ) 
['SERVER-FQDN  Active']
```

Now, what if there is no active UCM? What if the phone is up and cycling due to a lack of config, for example? Well, this is what we'll get back:

```text
kenneth@ubuntu:~/Scripts/CiscoScripts$ python transientPhones_v2.py
How many phones?: 2
What is the phone IP address?: 1.1.1.1
What is the phone IP address?: 2.2.2.2
Cisco Unified IP Phone Cisco Communicator ( CIPCKPERRY ) 
['SERVER-FQDN   Active']
Cisco IP Phone CP-8851 ( SEPAABBCCDDEEFF ) 
['SERVER-FQDN  Active']
```

Not bad. It requires the user of the script to understand that the empty set [] means that it's not registered at the time the script was run. Now, if you run into an issue where the web GUI isn't up, you're going to get an exception in the shell that indicates this. If the script fails due to another reason it will exit and tell the user it's not related to the url timeout.

This script has sped up review of bulk DeviceTransientConnection events, allowing us to verify those devices have a configuration in UCM (due to being actively registered, or not -- and we begin troubleshooting from there), the model type in UCM matches the actual phone model, etc... you might even have another script you can feed device names returned into and query the RIS Port/AST interface on UCM. Whatever you want to do with the data... but at least you have it -- quickly.

Now it's back to learning more python and stack overflowing every question I have to learn what's necessary to build out these tools. I hope this has been informative (in the sense that it opens up some eyes into what we can do -- even as I wrote this I thought of including a pull for the device's Serial Number (e.g. FCHXXXXXX) for audits. Thanks for reading! 