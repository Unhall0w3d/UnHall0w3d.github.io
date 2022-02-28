---
title: "Check Phone and SIP Trunk using ZEEP"
layout: single
classes: wide
date: 2020-07-27T08:00:00-05:00
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

## Let's Try Out ZEEP

As I probe different ways to pull information from Cisco Unified Communications Manager I often run across other modules that I can try in the future. My last attempts at pulling phone registration status from CUCM utilized requests, XML storing/parsing, DB dips for targeted phone checks and a little more.<!--more--> This time I tried to take a more simple approach… simple in the sense that we don’t dip into the DB, we don’t use ASTSAPI (which has a 200 device limit), and we don’t statically define SOAP messages to send in requests.

Instead this time I still use requests, but in conjunction with [Zeep](https://docs.python-zeep.org/en/master/). Zeep is a SOAP client for Python. As per Zeep’s own quick introduction, “Zeep inspects the WSDL document and generates the corresponding code to use the services and types in the document. This provides an easy to use programmatic interface to a SOAP server.” Now, as a non-programmer writing very specific use-case scripts, I don’t find many of the modules particularly easy to use… but I presume that comes with time, skill, and training/experience. This wasn’t the case with Zeep. It took about an hour or two of trial and error utilizing the WSDL/Schema and looking at Zeep’s sample scripts to understand what I needed to do, and how.

Speaking of which, what’s nice about Zeep is that there’s existing examples that you can go off of if you’re doing adds/updates (device pools, sip trunks, devices, etc.) or executing SQL queries. They can be found at the [Zeep Examples Repo](https://github.com/CiscoDevNet/axl-python-zeep-samples). In addition to that there’s a few support forum and alternate blog posts that provide boiler plate “here’s your imports and skeleton for the script” simply to talk to axl/RISPort, which is helpful in getting started.

What the script does is perform some input collection then fetch device names from a file (one device name per line, carriage return is stripped during file parsing) and then run our check against the RISPort service URL. Typically with Zeep you would want to store the server tomcat certificate so that the connection can be trusted, but as I run my scripts in many, many environments against different clusters it’s rather cumbersome to do so. Instead, we don’t verify the SSL cert. Even better, we don’t have to store the WSDL (schema) file locally either. We can simply fetch it from it’s location on CUCM via [RISService70](https://<cucm-ip>:8443/realtimeservice2/services/RISService70?wsdl) or [RisPort](https://<cucm-ip>:8443/realtimeservice/services/RisPort?wsdl). Replace the <cucm-ip> value with your UCM Publisher's IP.

Now, when I pull data I try to tailor the returns/printed elements to specifically what I want, rather than everything. One thing I found is that you can’t pull attributes that don’t exist — which makes sense, right? However, the script will error out as the KeyValue for “DirNumber” doesn’t exist for SIP Trunks, but exists for Cisco Phones. So to check both a sip trunk and a phone in the same query you have to drop the DirNumber (or other phone specific attribute) print statements. So for this I broke out the script to prompt if it’s for a phone, a trunk, or if a mixed bag to select the trunk option for more generic reporting. I also retained soap message history logging and placed it behind a prompt, you can determine if you need to see the soap messages for troubleshooting purposes, or not.

As always the script is available on my [GitHub Repo](https://github.com/Unhall0w3d/mind-enigma/blob/master/ccmRisPortRegCheck.py). As this script is rudamentary and made redundant by my toolbelt script, I have not included some of the extra features those contain, such as piping output to a file in a temp directory, extra validations for API reachability, looping to exceed the API max device limit, etc.

## Base Script

{% highlight Python linenos %}
#!/usr/var/python
# -*- code:UTF-8 -*-

#####################################
# Script created by Ken Perry, 2020 #
#       NOC THOUGHTS BLOG           #
#    https://www.nocthoughts.com    #
#####################################

# Define script imports
from zeep import Client
from zeep.cache import SqliteCache
from zeep.transports import Transport
from zeep.plugins import HistoryPlugin
from requests import Session
from requests.auth import HTTPBasicAuth
from lxml import etree
import urllib3
from getpass import getpass

# Disable insecure warning
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


# Define Username/PW/CUCM IP
def infocollect():
    ipaddr = input("What is the CUCM IP?: ")
    username = input("What is the CUCM Username?: ")
    password = getpass("What is the CUCM Password?: ")
    return ipaddr, username, password


# Function that takes device names from a text file, strips carriage return and adds device names to array
def inputfetch():
    inputfile = input('What is the name of the input text file?: ')
    with open(inputfile) as txtfile:
        lines = [line.rstrip() for line in txtfile]
        for line in txtfile:
            lines.append(line)
    return lines


# Script to check against risport the status of specified phones. We check using different return parameters for
# Phone and SIP Trunk as we cannot pull Dir Number.
def regcheck(ccmip, ccmun, ccmpw):
    devtype = input("Are we looking for Phones or SIP Trunks? If both, select trunk. (phone|trunk): ")
    # Define WSDL location at http url, we do not store it locally
    macs = inputfetch()
    print()
    print('Collecting Data...')
    print()
    wsdl = 'https://' + ccmip + ':8443/realtimeservice2/services/RISService70?wsdl'
    session = Session()
    session.verify = False
    session.auth = HTTPBasicAuth(ccmun, ccmpw)
    transport = Transport(cache=SqliteCache(), session=session, timeout=20)
    history = HistoryPlugin()
    client = Client(wsdl=wsdl, transport=transport, plugins=[history])
    factory = client.type_factory('ns0')
    item = []
    for mac in macs:
        item.append(factory.SelectItem(Item=mac))
    devnames = factory.ArrayOfSelectItem(item)
    stateinfo = ''
    if devtype == "phone":
        criteria = factory.CmSelectionCriteria(
            MaxReturnedDevices=1000, DeviceClass='Phone', Model=255, Status='Any', NodeName='', SelectBy='Name',
            SelectItems=devnames, Protocol='Any', DownloadStatus='Any')
        result = client.service.selectCmDevice(stateinfo, criteria)
        for node in result.SelectCmDeviceResult.CmNodes.item:
            nodename = node.Name
            for device in node.CmDevices.item:
                print("Node: " + nodename, "Device Name: " + device.Name, "Status: " + device.Status,
                      "Description: " + device.Description, "Dir Number: " + device.DirNumber)
                print()
    if devtype == "trunk":
        print("SIP Trunks that are enabled to Run On All Nodes will report per node below.")
        print()
        criteria = factory.CmSelectionCriteria(
            MaxReturnedDevices=1000, DeviceClass='Any', Model=255, Status='Any', NodeName='', SelectBy='Name',
            SelectItems=devnames, Protocol='Any', DownloadStatus='Any')
        result = client.service.selectCmDevice(stateinfo, criteria)
        for node in result.SelectCmDeviceResult.CmNodes.item:
            nodename = node.Name
            for device in node.CmDevices.item:
                print("Node: " + nodename, "Device Name: " + device.Name, "Status: " + device.Status,
                      "Description: " + device.Description)
                print()
    checkhistory = input("Do you want to check the SOAP Message History?(y/n): ")
    if checkhistory == "y":
        for hist in [history.last_sent, history.last_received]:
            print(etree.tostring(hist["envelope"], encoding="unicode", pretty_print=True))
    elif checkhistory == "n":
        exit()


ccmip, ccmun, ccmpw = infocollect()
regcheck(ccmip, ccmun, ccmpw)

{% endhighlight %}

## Required Input

```text
CCM GUI Username
CCM GUI Password
CCM IP Address (Publisher)
input.txt file containing device/trunk names. One per line. File is expected to be in the working directory.
```

## Script Behavior - Phones

<span class="image fit"><img src="{{ "/assets/images/scriptbehavior_phones.png" | absolute_url }}" alt="Example of script run against Phones." /></span>

Example of script behavior, requested input, output formatting when checking phone registration.

## Script Behavior - Trunks

<span class="image fit"><img src="{{ "/assets/images/scriptbehavior_trunks.png" | absolute_url }}" alt="Example of script run against Trunks." /></span>

Example of script behavior, requested input, output formatting when checking trunk registration.

What I like about this version of the registration check script is the ease of checking SIP Trunk status. As the ASTSAPI version of the script performs similar phone/cti/mgcp registration statuses I could have neglected the phone check in my RISPORT script, but as part of the purpose of making these scripts is to learn I decided to build it out anyway.

One issue that I run into that this script is particularly useful for is when SIP Trunks are configured to ‘Run On All Nodes’, and the trunk deregisters from a single subscriber node, or multiple nodes in the same data center, but not from the others. This can help me identify which nodes it’s “up” on, and which nodes it’s “down” on. As seen in the screenshot, we have an “Unknown” (not registered) status coming back from IPTUCMSUB1 for IPTvCUBE2, but it is registered from the Publisher’s perspective. Neat. Good thing it’s in lab!

This script can be useful in pre and post change healthchecks, active issue investigation, or verification that the trunk is registered against each node it is set to run on once root cause has been identified and corrected. I know this will be useful for me, and I truly hope it is for you as well. I am always open to feedback so if there’s something I can do to make a better tool for myself, my team, and others I would love to hear it! Leave a comment, reach out on LinkedIn, GitHub, or Twitter and let me know! You can find the appropriate links at the top right of the page via the social buttons. I’d like to thank you for reading and wish you good luck and godspeed on your UC Journey.
