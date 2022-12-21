---
title: "Cisco UCSyslogParser Script"
layout: single
classes: wide
date: 2022-12-20T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Cisco
  - Unified Communications
  - Python
tags:
  - Cisco
  - Callmanager
  - CUCM
  - Unified Communications
  - Python
---

## The Nail That Stands Out Gets Hammered Down

If you're an administrator for a Cisco Unified Communications Manager (UCM) server, you know how important it is to keep track of syslog messages. Syslogs can provide valuable information about the health and performance of your UCM environment, but sifting through them can be a time-consuming and tedious task. That's where the UCSyslogParser script comes in. <!--more-->

This python script is designed to parse syslog files from a UCM server and analyze them for known syslog messages. It then generates a report in an Excel Workbook, categorizing the syslog messages by type and listing the 10 top talker devices for each matched syslog. This can save administrators a lot of time and effort when trying to identify problematic devices or track down issues in the UCM environment.

### Why Use The Script
Using the UCSyslogParser script has several benefits. First and foremost, it can significantly reduce the time required to identify problematic devices. Instead of manually searching through syslog files, the script does the work for you, providing a clear and concise report of the top talker devices and the syslog messages they generated. This can help you quickly zero in on any issues and take action to resolve them.

In addition to saving time, using the UCSyslogParser script can help create a more stable UCM environment. By identifying and addressing issues early on, you can prevent them from becoming bigger problems down the road. This can reduce downtime and improve the overall reliability of your UCM system.

Finally, the UCSyslogParser script can free up administrators to focus on more important tasks. Instead of spending hours sifting through syslog files, you can use the script to pull and parse the logs for you, allowing you to spend more time fixing issues and less time finding them.

In conclusion, the UCSyslogParser script is a valuable tool for any administrator responsible for managing a UCM server. By parsing and analyzing syslog files, it can help identify problematic devices, create a more stable UCM environment, and save administrators time and effort. If you're not already using this script, it's definitely worth giving it a try.

### What Does It Do - Behind The Scenes

Sorry to interrupt, but I found an open document with what appears to be this blog post and, now that I've read the intro and outro planned by the writer, and the GitHub page open with code he seemed to be describing on a second monitor... I... well I had a chance to talk to the blog writer. I assume it's him as he's holed up in a room and... well.

This is going to be a doozy, so hold on to your hat. I'm going to tell you a story of a guy that writes blog posts on a website called NOC Thoughts. He had this *fun* idea of rewriting a [script](https://github.com/Unhall0w3d/mind-enigma/blob/master/Reporting%20Scripts/old_UCTopTalkers.py) that was working just fine, but this time he decided to mess around with a few new modules. He didn't know what this would mean... he only knew it would be *fun*.

The modules he was interested in were **pyparsing**, **pandas**, and **xlsxwriter**. You see, this guy's a glutton for punishment and really, really tedious code writing. He wanted (read: did not know he'd have to) to write out a variable for every syslog message he wanted to capture. Not only that, he'd be writing multiple variations based on how a syslog would present in Cisco Unified Communications Manager versions 9 through 14. Not only that, but if some of the fields that he needed data from were optional, he had to have another variation for each. and. every. variation. of. every. syslog. for. most. versions. You see... this man was a fool. Though a fool, he was also persistent and came up with this magnificent beast of a script.

To start off, this guy ended up importing a lot of modules, and overcomplicated the process because of his choice of modules to work with.

```text
import re
from pyparsing import Word, alphas, Suppress, Combine, nums, string, alphanums, OneOrMore, \
    White, Optional, alphas8bit, ZeroOrMore
import itertools
import os
import shutil
import time
import pandas as pd
import xlsxwriter
import glob

from getpass import getpass

import paramiko
import requests
import urllib3
from requests.auth import HTTPBasicAuth
```

Nevertheless, he set out defining some variables that would be needed without total regard for scope. There are some variables that could be moved to their associated function and passed if needed... but he didn't optimize the code yet. He may never. This was just that annoying to work on.

```text
# Disablement of HTTPS Insecure Request error message.
# noinspection PyUnresolvedReferences
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# DateTime String
timestr = time.strftime("%Y%m%d-%H%M%S")

# Exit text
infoexit = "Info: Exiting ... "

# Directory and File Vars
syslogstore = 'CiscoSyslogs'
toptalkersstore = 'TopTalkersReports'
tempstore = 'temp'
fnametstring = (timestr + '\\')
dir_path = os.getcwd()
syslogpath = os.path.join(dir_path, syslogstore)
downloaddir = os.path.join(syslogpath, fnametstring)
toptalkerspath = os.path.join(dir_path, toptalkersstore)
temppath = os.path.join(dir_path, tempstore)
```

As he writes his code in a logical order, whenever possible, he starts of with checking if directories required for the script to function exist, and if not, create them. Easy enough.

```text
# Check if required directories exist and create if needed
def setup():
    print("Info: Checking if required directories exist, if not, creating them.")
    syslogpathcheck = os.path.exists(syslogpath)
    toptalkerspathcheck = os.path.exists(toptalkerspath)
    downloaddirpathcheck = os.path.exists(downloaddir)
    temppathcheck = os.path.exists(temppath)
    if not syslogpathcheck:
        os.makedirs(syslogpath)
        print("Info: Creating folder CiscoSyslogs in " + dir_path)
    if not downloaddirpathcheck:
        os.makedirs(downloaddir)
        print("Info: Creating folder " + fnametstring + " in " + syslogpath)
    if not toptalkerspathcheck:
        os.makedirs(toptalkerspath)
        print("Info: Creating folder TopTalkersReports in " + dir_path)
    if not temppathcheck:
        os.makedirs(temppath)
        print("Info: Creating folder temp in " + dir_path)
```

The blog writer then moves on to collecting some key device details that will be needed to access the target systems and grab the syslog data for review. In his mind, so far so good.

```text
# Collect IP Address, Username and Password for CCM Publisher
def infocollect():
    ipaddr = str(input("Collect: CCM Pub IP? : "))
    username = str(input("Collect: GUI Username? : "))
    password = getpass("Collect: GUI Password? : ")
    usernameos = str(input("Collect: OS Username? : "))
    passwordos = getpass("Collect: OS Password? : ")
    return ipaddr, username, password, usernameos, passwordos
```

He then proceeds to create some jankery to handle SSH buffers and input for Cisco Unified Communications Manager because functioning like any other standard command line would be too much to ask for. He should have known this was starting to go sideways right here, but he paid no mind.

```text
# Processing command input, needed in netrequests()
def receivestr(sshconn, cmd):
    buffer = ''
    prompt = 'admin:'
    if cmd != '':
        sshconn.send(cmd)
    while not sshconn.recv_ready():
        time.sleep(.5)
        buffer += str(sshconn.recv(65535), 'utf-8')
        if buffer.endswith(prompt):
            break
    return buffer
```

Ever the one to overcomplicate a simple task, a book of a function is created to connect to Cisco Unified Communications Manager via SSH, identify syslog files to download, perform a download of each file from each server in the cluster and write them locally. He thought to himself, "There must be a way to break these out into smaller functions... there is... but I'm busy dealing with script test runs for the parser function troubleshooting to deal with it.". And not another thought went into this part of the code. Not one.

```text
# Connect to UCM Pub on port 22|Collect output from show network cluster to construct ip list for log download
# Connect to each ip and download identified logs
def netrequests():
    print('Info: Setting up SSH Session ... ')
    _sshconn = paramiko.SSHClient()
    _sshconn.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    ucnodes = []
    headers = {
        'SOAPAction': 'http://schemas.cisco.com/ast/soap/action/#LogCollectionPort#GetOneFile',
        'Content-Type': 'text/plain'
    }
    try:
        _sshconn.connect(hostname=ipaddr, port=22, username=usernameos, password=passwordos, timeout=300,
                         banner_timeout=300)
        invokeshell = _sshconn.invoke_shell()
        receivestr(invokeshell, '')
        print('Info: Connected to Publisher ... ')
        buffer = receivestr(invokeshell, 'show network cluster\n')
        networkinfo = buffer.split('\r\n')
        regexip = re.compile('((25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(25[0-5]|2[0-4][0-9]|1[0-9][0-9]|['
                             '1-9]?[0-9])')
        for node in networkinfo:
            if 'callmanager' in node and re.search(regexip, node):
                iplist = re.search(regexip, node)
                if iplist.group(0) not in ucnodes:
                    ucnodes.append(iplist.group(0))
        _sshconn.close()
        print('Info: CUCM Servers Found')
        print('Servers: ' + ', '.join(ucnodes))
        for ip in ucnodes:
            files = []
            url = "https://" + ip + ":8443/logcollectionservice/services/DimeGetFileService"
            _sshconn.connect(hostname=ip, port=22, username=usernameos, password=passwordos,
                             timeout=300, banner_timeout=300)
            invokeshell = _sshconn.invoke_shell()
            receivestr(invokeshell, '')
            print('Info: Setting up SSH Session to ' + ip + ' ... ')
            buffer2 = receivestr(invokeshell, 'file list activelog /syslog/ detail \n')
            output = buffer2.split('\r\n')
            searchterm = re.compile('.*Syslo.*')
            for line in output:
                check = re.search(searchterm, line)
                if check is not None:
                    files.append(check.group(0))
            flist = [filename[35:] for filename in files]
            print('Info: Found files for download on ' + ip)
            print('Files: ' + ', '.join(flist))
            _sshconn.close()
            for fname in flist:
                payload = "<soapenv:Envelope xmlns:xsi=\"http://www.w3.org/2001/XMLSchema-instance\" " \
                          "xmlns:xsd=\"http://www.w3.org/2001/XMLSchema\" " \
                          "xmlns:soapenv=\"http://schemas.xmlsoap.org/soap/envelope/\" " \
                          "xmlns:soap=\"http://schemas.cisco.com/ast/soap/\">\n<soapenv:Header/>\n<soapenv:Body>\n<soap" \
                          ":GetOneFile soapenv:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\">\n<FileName>/var" \
                          "/log" \
                          "/active/syslog/" + fname + "</FileName>\n</soap:GetOneFile>\n</soapenv:Body>\n</soapenv:Envelope> "
                response = requests.request("POST", url, headers=headers, data=payload,
                                            auth=HTTPBasicAuth(username, password), verify=False, timeout=10)
                print('Info: Downloading ' + fname + ' from ' + ip + ' ... ')
                dnldfile = (ip + '_' + fname)
                with open(os.path.join(downloaddir, dnldfile), 'w+', encoding='utf-8') as file:
                    file.write(response.text)
                    file.close()
        print('Info: Syslogs downloaded to ' + downloaddir)
    except Exception as z:
        print('Error: Failed to establish connection to UCM Server: ', z)
        _sshconn.close()
```

Now... this... this next part is something you'd see on https://www.reddit.com/r/programminghorror ... It's not for the faint of heart and honestly gave this man nightmares as, in his pursuit of using **pyparsing** because of how *fun* it would be, he created an absolute *abomination* of a function. When I asked him what he had done, only the screams of some cthulhu-esque nature could be heard. As far as I understand it creates static variables to match everything from the way the date to syslog contents appear in a given message and evaluates what exists within the message and what doesn't, slaps it all together into a payload, and passes it on. I think.

```text
class Parser(object):
    def __init__(self):
        ints = Word(nums)
        punc = "_.;+:()€“,*-=–/\\'#\xa0"

        # Timestamp
        month = Word(string.ascii_uppercase, string.ascii_lowercase, exact=3)
        day = ints
        hour = Combine(ints + ":" + ints + ":" + ints)
        exhour = Combine(ints + ":" + ints + ":" + ints + Optional("." + ints))
        year = ints

        timestamp = month + day + hour
        extimestamp = month + day + year + exhour
        tzdata = Word(string.ascii_uppercase, exact=3)

        # Hostname
        hostname = Word(alphanums + "-_.:")

        # Local Syslog
        local = Word(alphanums)

        # Priority
        priority = ints

        # Server Type
        srvtype = Combine(ZeroOrMore(Word(string.ascii_lowercase, exact=3)) + Suppress(":"))

        # Message Number
        msgnum = Combine(ints + Suppress(":"))

        # Separator
        separator = ": "

        # Message Type
        msgtype = Word(":%-_" + alphanums)

        # Device Name
        devval = Combine(OneOrMore(Word(alphanums + punc) | White(' ', max=3) + ~White()))
        devname = Suppress(Word("%[")) + Combine("DeviceName=" + ZeroOrMore(devval)) + Suppress("]")

        # UnavailableRemotePeers
        peerval = Combine(OneOrMore(Word(alphanums + punc) | White(' ', max=1) + ~White()))
        peers = Suppress("[") + Combine("UnavailableRemotePeersWithReasonCode=" + ZeroOrMore(peerval)) + Suppress("]")

        # Device IP
        ip4 = Suppress("[") + Combine("IPAddress=" + Word(nums + ".")) + Suppress("]")
        ip6 = Suppress("[") + Combine("IPV6Address=" + Word(alphanums + punc)) + Suppress("]")

        # Port Number
        port = Suppress("%[") + Combine("ConnectingPort=" + Word(nums)) + Suppress("]")

        # MAC Address
        macaddr = Suppress("[") + Combine("MACAddress=" + Word(alphanums)) + Suppress("]")

        # Protocol
        protocol = Suppress("[") + Combine("Protocol=" + Word(alphas)) + Suppress("]")

        # Device Type
        devtype = Suppress("[") + Combine("DeviceType=" + ints) + Suppress("]")

        # Product Type
        prodval = Combine(OneOrMore(Word(alphanums + punc) | White(' ', max=1) + ~White()))
        prodtype = Suppress("[") + Combine("ProductType=" + OneOrMore(prodval)) + Suppress("]")

        # Description
        descval = Combine(OneOrMore(Word(alphanums + punc + alphas8bit) | White(' ', max=2) + ~White()))
        desc = Suppress("[") + OneOrMore(descval) + Suppress("]")

        # MRA -- CCM 14
        mra = Suppress("[") + Combine("MRAStatus=" + Word(alphanums)) + Suppress("]")

        # Reason Code
        reason = Suppress("[") + Combine("Reason=" + ints) + Suppress("]")
        reasoncode = Suppress("[") + Combine("ReasonCode=" + ints) + Suppress("]")

        # IP Attributes
        ipattrib = Suppress("[") + Combine("IPAddrAttributes=" + Word(nums + punc)) + Suppress("]")
        ipattrib6 = Suppress("[") + Combine("IPV6AddrAttributes=" + Word(alphanums)) + Suppress("]")

        # Misc. Shared Fields
        lastsig = Suppress("[") + Combine("LastSignalReceived=" + Word(alphanums)) + Suppress("]")
        callstate = Suppress("[") + Combine("CallState=" + Word(alphanums + punc)) + Suppress("]")
        sstate = Suppress("[") + Combine("StationState=" + Word(alphanums + punc)) + Suppress("]")

        # CDR Vars
        cdrrepo = Suppress("%[") + Combine("CDRRepositoryNodeAddress=" + Word(alphanums + punc)) + Suppress("]")
        cdrnode = Suppress("[") + Combine("CDRAgentNodeAddress=" + Word(alphanums + punc)) + Suppress("]")
        billingsrv = Suppress("%[") + Combine("BillingServerAddress=" + Word(alphanums+punc)) + Suppress("]")

        # App ID
        appidval = Combine(OneOrMore(Word(alphas) | White(' ', max=1) + ~White()))
        appid = Suppress("[") + Combine("AppID=" + OneOrMore(appidval)) + Suppress("]")

        # Cluster ID
        cluster = Suppress("[") + Combine("ClusterID=" + Optional(Word(alphanums + punc))) + Suppress("]")

        # Node ID
        node = Suppress("[") + Combine("NodeID=" + Word(alphanums + punc)) + Suppress("]:")

        # Info Text
        infoval = Combine(OneOrMore(Word(alphanums + punc) | White(' ', max=1) + ~White()))
        info = OneOrMore(infoval)

        # Search Patterns - EndpointUnregistered
        self.__epdefault = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + devname + ip4 + protocol + devtype + desc + reason \
            + ipattrib + lastsig + appid + cluster + node + info
        self.__epnodesc = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + devname + ip4 + protocol + devtype + reason \
            + ipattrib + lastsig + appid + cluster + node + info
        self.__epnosig = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + devname + ip4 + protocol + devtype + desc + reason \
            + ipattrib + callstate + appid + cluster + node + info
        self.__epnosignodesc = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + devname + ip4 + protocol + devtype + reason \
            + ipattrib + appid + cluster + node + info
        self.__epnosignocall = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + devname + ip4 + protocol + devtype + desc + reason \
            + ipattrib + appid + cluster + node + info
        self.__epnosignocallyesmac = timestamp + hostname + local + priority + srvtype + msgnum + hostname +\
            extimestamp + tzdata + separator + msgtype + devname + ip4 + protocol + devtype + desc + reason + \
            macaddr + ipattrib + appid + cluster + node + info
        self.__epnosigyescallyesmac = timestamp + hostname + local + priority + srvtype + msgnum + hostname +\
            extimestamp + tzdata + separator + msgtype + devname + ip4 + protocol + devtype + desc + reason + \
            macaddr + ipattrib + callstate + appid + cluster + node + info
        self.__epallbutmac = timestamp + hostname + local + priority + srvtype + msgnum + hostname +\
            extimestamp + tzdata + separator + msgtype + devname + ip4 + protocol + devtype + desc + reason + \
            ipattrib + lastsig + callstate + appid + cluster + node + info
        self.__mranosignocall = timestamp + hostname + local + priority + srvtype + msgnum + hostname + \
            extimestamp + tzdata + separator + msgtype + devname + ip4 + protocol + devtype + desc + reason + ipattrib \
            + mra + appid + cluster + node + info
        self.__mrasignocall = timestamp + hostname + local + priority + srvtype + msgnum + hostname + \
            extimestamp + tzdata + separator + msgtype + devname + ip4 + protocol + devtype + desc + reason + ipattrib \
            + lastsig + mra + appid + cluster + node + info
        self.__mrasigcall = timestamp + hostname + local + priority + srvtype + msgnum + hostname + \
            extimestamp + tzdata + separator + msgtype + devname + ip4 + protocol + devtype + desc + reason + ipattrib \
            + lastsig + callstate + mra + appid + cluster + node + info
        self.__mranosigcall = timestamp + hostname + local + priority + srvtype + msgnum + hostname + \
            extimestamp + tzdata + separator + msgtype + devname + ip4 + protocol + devtype + desc + reason + ipattrib \
            + callstate + mra + appid + cluster + node + info
        self.__mranosignodesc = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + devname + ip4 + protocol + devtype + reason + macaddr \
            + ipattrib + mra + appid + cluster + node + info
        self.__mranosignocallyesmac = timestamp + hostname + local + priority + srvtype + msgnum + hostname +\
            extimestamp + tzdata + separator + msgtype + devname + ip4 + protocol + devtype + desc + reason + \
            macaddr + ipattrib + mra + appid + cluster + node + info

        # Search Patterns - StationConnectionError
        self.__stationall = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp +\
            tzdata + separator + msgtype + devname + reasoncode + appid + cluster + node + info

        # Search Patterns - EndPointRestartInitiated
        self.__eprestart = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp +\
            tzdata + separator + msgtype + devname + devtype + prodtype + appid + cluster + node + info

        # Search Patterns - DeviceUnregistered
        self.__devunreg6desc = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + devname + ip4 + protocol + devtype + desc + reason + ip6 + ipattrib + \
            ipattrib6 + appid + cluster + node + info
        self.__devunregdesc = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + devname + ip4 + protocol + devtype + desc + reason + ipattrib + \
                appid + cluster + node + info
        self.__devunreg6nodesc = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + devname + ip4 + protocol + devtype + reason + ip6 + ipattrib + \
            ipattrib6 + appid + cluster + node + info
        self.__devunregnodesc = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + devname + ip4 + protocol + devtype + reason + ipattrib + \
                appid + cluster + node + info

        # Search Patterns - SIPTrunkOOS
        self.__siptrunk = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + devname + peers + appid + cluster + node + info

        # Search Patterns - TransientConnection
        self.__dtransient = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + port + devname + ip4 + devtype + reason + protocol + ipattrib + appid + \
            cluster + node + info
        self.__eptransientall = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + port + devname + ip4 + devtype + reason + protocol + macaddr + ipattrib + \
            lastsig + sstate + appid + cluster + node + info
        self.__eptrannomac = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + port + devname + ip4 + devtype + reason + protocol + ipattrib + \
            lastsig + sstate + appid + cluster + node + info
        self.__eptrannoip = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + port + devname + devtype + reason + protocol + macaddr + ipattrib + \
            lastsig + sstate + appid + cluster + node + info
        self.__eptrannnoipa = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + port + devname + devtype + reason + protocol + macaddr + \
            lastsig + sstate + appid + cluster + node + info
        self.__eptnosignoss = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + port + devname + ip4 + devtype + reason + protocol + ipattrib + \
            appid + cluster + node + info

        # Search Patterns - CDR
        self.__sendfilefailed = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + cdrrepo + cdrnode + appid + cluster + node + info
        self.__cdrfilefailed = timestamp + hostname + local + priority + srvtype + msgnum + hostname + extimestamp + \
            tzdata + separator + msgtype + billingsrv + appid + cluster + node + info

    def endpointparse(self, line):
        sigkywd = "LastSignalReceived"
        searching = re.compile(r'{}'.format(sigkywd))
        dosearch = searching.search(line)
        if dosearch is None:
            descsigkywd = "Description"
            descsearching = re.compile(r'{}'.format(descsigkywd))
            descsearch = descsearching.search(line)
            if descsearch is None:
                mrakywd = "MRAStatus"
                mrasearching = re.compile(r'{}'.format(mrakywd))
                mrasearch = mrasearching.search(line)
                if mrasearch is None:
                    parsed = self.__epnosignodesc.parseString(line)
                    payload = {"device": parsed[16], "ip": parsed[17], "description": "Description=", "reason": parsed[21],
                        "node": parsed[26], "lastsignal": "LastSignalReceived=", "callstate": "CallState="}
                    return payload
                if mrasearch is not None:
                    parsed = self.__mranosignodesc.parseString(line)
                    payload = {"device": parsed[16], "ip": parsed[17], "description": "Description=",
                        "reason": parsed[21],
                        "node": parsed[26], "lastsignal": "LastSignalReceived=", "callstate": "CallState="}
                    return payload
            elif descsearch is not None:
                callkywd = "CallState"
                callsearching = re.compile(r'{}'.format(callkywd))
                callsearch = callsearching.search(line)
                if callsearch is None:
                    mackywd = "MACAddress"
                    macsearching = re.compile(r'{}'.format(mackywd))
                    macsearch = macsearching.search(line)
                    if macsearch is None:
                        mrakywd = "MRAStatus"
                        mrasearching = re.compile(r'{}'.format(mrakywd))
                        mrasearch = mrasearching.search(line)
                        if mrasearch is None:
                            parsed = self.__epnosignocall.parseString(line)
                            payload = {"device": parsed[16], "ip": parsed[17], "description": parsed[20], "reason": parsed[21],
                                "node": parsed[25], "lastsignal": "LastSignalReceived=", "callstate": "CallState="}
                            return payload
                        elif mrasearch is not None:
                            parsed = self.__mranosignocall.parseString(line)
                            payload = {"device": parsed[16], "ip": parsed[17], "description": parsed[20], "reason": parsed[21],
                                "node": parsed[26], "lastsignal": "LastSignalReceived=", "callstate": "CallState="}
                            return payload
                    elif macsearch is not None:
                        mrakywd = "MRAStatus"
                        mrasearching = re.compile(r'{}'.format(mrakywd))
                        mrasearch = mrasearching.search(line)
                        if mrasearch is None:
                            parsed = self.__epnosignocallyesmac.parseString(line)
                            payload = {"device": parsed[16], "ip": parsed[17], "description": parsed[20],
                                "reason": parsed[21], "node": parsed[26], "lastsignal": "LastSignalReceived=",
                                "callstate": "CallState="}
                            return payload
                        if mrasearch is not None:
                            parsed = self.__mranosignocallyesmac.parseString(line)
                            payload = {"device": parsed[16], "ip": parsed[17], "description": parsed[20],
                                "reason": parsed[21], "node": parsed[27], "lastsignal": "LastSignalReceived=",
                                "callstate": "CallState="}
                            return payload
                elif callsearch is not None:
                    mackywd = "MACAddress"
                    macsearching = re.compile(r'{}'.format(mackywd))
                    macsearch = macsearching.search(line)
                    if macsearch is None:
                        mrakywd = "MRAStatus"
                        mrasearching = re.compile(r'{}'.format(mrakywd))
                        mrasearch = mrasearching.search(line)
                        if mrasearch is None:
                            parsed = self.__epnosig.parseString(line)
                            payload = {"device": parsed[16], "ip": parsed[17], "description": parsed[20],
                                "reason": parsed[21],
                                "node": parsed[25], "lastsignal": "LastSignalReceived=", "callstate": parsed[23]}
                            return payload
                        elif mrasearch is not None:
                            parsed = self.__mranosigcall.parseString(line)
                            payload = {"device": parsed[16], "ip": parsed[17], "description": parsed[20],
                                "reason": parsed[21],
                                "node": parsed[27], "lastsignal": "LastSignalReceived=", "callstate": parsed[23]}
                            return payload
                    elif macsearch is not None:
                        parsed = self.__epnosigyescallyesmac.parseString(line)
                        payload = {"device": parsed[16], "ip": parsed[17], "description": parsed[20],
                            "reason": parsed[21],
                            "node": parsed[27], "lastsignal": "LastSignalReceived=", "callstate": parsed[24]}
                        return payload
        elif dosearch is not None:
            descsigkywd = "Description"
            descsearching = re.compile(r'{}'.format(descsigkywd))
            descsearch = descsearching.search(line)
            if descsearch is None:
                mackywd = "MACAddress"
                macsearching = re.compile(r'{}'.format(mackywd))
                macsearch = macsearching.search(line)
                if macsearch is None:
                    parsed = self.__epnodesc.parseString(line)
                    payload = {"device": parsed[16], "ip": parsed[17], "description": "Description=",
                        "reason": parsed[20], "node": parsed[25], "lastsignal": parsed[22], "callstate": "CallState="}
                    return payload
                elif macsearch is not None:
                    parsed = self.__epnosignocallyesmac.parseString(line)
                    payload = {"device": parsed[16], "ip": parsed[17], "description": parsed[20], "reason": parsed[21],
                        "node": parsed[26], "lastsignal": "LastSignalReceived=", "callstate": "CallState="}
                    return payload
            elif descsearch is not None:
                callkywd = "CallState"
                callsearching = re.compile(r'{}'.format(callkywd))
                callsearch = callsearching.search(line)
                if callsearch is None:
                    mrakywd = "MRAStatus"
                    mrasearching = re.compile(r'{}'.format(mrakywd))
                    mrasearch = mrasearching.search(line)
                    if mrasearch is None:
                        parsed = self.__epdefault.parseString(line)
                        payload = {"device": parsed[16], "ip": parsed[17], "description": parsed[20], "reason": parsed[21],
                            "node": parsed[26], "lastsignal": parsed[22], "callstate": "CallState="}
                        return payload
                    elif mrasearch is not None:
                        parsed = self.__mrasignocall.parseString(line)
                        payload = {"device": parsed[16], "ip": parsed[17], "description": parsed[20],
                        "reason": parsed[21], "node": parsed[27], "lastsignal": parsed[23], "callstate": "CallState="}
                        return payload
                elif callsearch is not None:
                    mrakywd = "MRAStatus"
                    mrasearching = re.compile(r'{}'.format(mrakywd))
                    mrasearch = mrasearching.search(line)
                    if mrasearch is None:
                        parsed = self.__epallbutmac.parseString(line)
                        payload = {"device": parsed[16], "ip": parsed[17], "description": parsed[20], "reason": parsed[21],
                            "node": parsed[26], "lastsignal": parsed[23], "callstate": parsed[24]}
                        return payload
                    elif mrasearch is not None:
                        parsed = self.__mrasigcall.parseString(line)
                        payload = {"device": parsed[16], "ip": parsed[17], "description": parsed[20], "reason": parsed[21],
                            "node": parsed[28], "lastsignal": parsed[23], "callstate": parsed[24]}
                        return payload

    def stationparse(self, line):
        parsed = self.__stationall.parseString(line)
        payload = {"device": parsed[16], "reason": parsed[17], "node": parsed[20]}
        return payload

    def eprestartparse(self, line):
        parsed = self.__eprestart.parseString(line)
        payload = {"device": parsed[16], "product": parsed[18], "node": parsed[21], "info": parsed[22]}
        return payload

    def devunregparse(self, line):
        ip6kywd = "IPV6Address"
        ip6searching = re.compile(r'{}'.format(ip6kywd))
        ip6search = ip6searching.search(line)
        if ip6search is None:
            descsigkywd = "Description"
            descsearching = re.compile(r'{}'.format(descsigkywd))
            descsearch = descsearching.search(line)
            if descsearch is None:
                parsed = self.__devunregnodesc.parseString(line)
                payload = {"device": parsed[16], "ip": parsed[17], "description": "Description=", "reason": parsed[20],
                    "node": parsed[24]}
                return payload
            elif descsearch is not None:
                parsed = self.__devunregdesc.parseString(line)
                payload = {"device": parsed[16], "ip": parsed[17], "description": parsed[20], "reason": parsed[21],
                    "node": parsed[25]}
                return payload
        elif ip6search is not None:
            descsigkywd = "Description"
            descsearching = re.compile(r'{}'.format(descsigkywd))
            descsearch = descsearching.search(line)
            if descsearch is None:
                parsed = self.__devunreg6nodesc.parseString(line)
                payload = {"device": parsed[16], "ip": parsed[17], "description": "Description=", "reason": parsed[20],
                    "node": parsed[26]}
                return payload
            elif descsearch is not None:
                parsed = self.__devunreg6desc.parseString(line)
                payload = {"device": parsed[16], "ip": parsed[17], "description": parsed[20], "reason": parsed[21],
                    "node": parsed[27]}
                return payload

    def siptrunkparse(self, line):
        parsed = self.__siptrunk.parseString(line)
        peers = parsed[17]
        _peers = peers.replace(',', '')
        payload = {"device": parsed[16], "peers": _peers, "node": parsed[20]}
        return payload

    def transientparse(self, line):
        msgkywd = "-DeviceTransientConnection"
        msgsearching = re.compile(r'{}'.format(msgkywd))
        msgsearch = msgsearching.search(line)
        if msgsearch is None:
            mackywd = "MACAddress"
            macsearching = re.compile(r'{}'.format(mackywd))
            macsearch = macsearching.search(line)
            if macsearch is None:
                ipkywd = "IPAddress"
                ipsearching = re.compile(r'{}'.format(ipkywd))
                ipsearch = ipsearching.search(line)
                if ipsearch is None:
                    pass
                elif ipsearch is not None:
                    sigkywd = "LastSignalReceived"
                    sigsearching = re.compile(r'{}'.format(sigkywd))
                    sigsearch = sigsearching.search(line)
                    if sigsearch is None:
                        parsed = self.__eptnosignoss.parseString(line)
                        payload = {"device": parsed[17], "ip": parsed[18], "reason": parsed[20], "node": parsed[25],
                            "mac": "MACAddress=", "lastsig": "LastSignalReceived=", "sstate": "StationState="}
                        return payload
                    elif sigsearch is not None:
                        parsed = self.__eptrannomac.parseString(line)
                        payload = {"device": parsed[17], "ip": parsed[18], "reason": parsed[20], "node": parsed[28],
                            "mac": "MACAddress=", "lastsig": parsed[23], "sstate": parsed[24]}
                        return payload
            elif macsearch is not None:
                ipkywd = "IPAddress"
                ipsearching = re.compile(r'{}'.format(ipkywd))
                ipsearch = ipsearching.search(line)
                if ipsearch is None:
                    ipattribkywd = "IPAddrAttributes"
                    ipasearching = re.compile(r'{}'.format(ipattribkywd))
                    ipasearch = ipasearching.search(line)
                    if ipasearch is None:
                        parsed = self.__eptrannnoipa.parseString(line)
                        payload = {"device": parsed[17], "ip": "IPAddress=", "reason": parsed[19], "node": parsed[26],
                            "mac": parsed[21], "lastsig": parsed[22], "sstate": parsed[23]}
                        return payload
                    elif ipasearch is not None:
                        parsed = self.__eptrannoip.parseString(line)
                        payload = {"device": parsed[17], "ip": "IPAddress=", "reason": parsed[19], "node": parsed[27],
                            "mac": parsed[21], "lastsig": parsed[23], "sstate": parsed[24]}
                        return payload
                elif ipsearch is not None:
                    parsed = self.__eptransientall.parseString(line)
                    payload = {"device": parsed[17], "ip": parsed[18], "reason": parsed[20], "node": parsed[28],
                        "mac": parsed[22], "lastsig": parsed[24], "sstate": parsed[25]}
                    return payload
        elif msgsearch is not None:
            parsed = self.__dtransient.parseString(line)
            payload = {"device": parsed[17], "ip": parsed[18], "reason": parsed[20], "node": parsed[25],
                "mac": "MACAddress=", "lastsig": "LastSignalReceived=", "sstate": "StationState="}
            return payload

    def cdragentparse(self, line):
        parsed = self.__sendfilefailed.parseString(line)
        payload = {"month": parsed[0], "repo": parsed[16], "cdrnode": parsed[17], "node": parsed[20]}
        return payload

    def cdrfileparse(self, line):
        parsed = self.__cdrfilefailed.parseString(line)
        payload = {"month": parsed[0], "billingsrv": parsed[16], "node": parsed[19]}
        return payload
```

That accursed payload the function produces is fed into a parsing unction that creates (at times) large data sets of all the parsed syslogs sorted by type and occurrence count. I assume this was to prepare the data to be written to a report, but again, when asked the man only stared at me. Menacingly.

```text
def doparse():
    parser = Parser()
    searchlist = ['-EndPointUnregistered', '-StationConnectionError', '-EndPointRestartInitiated',
                  '-DeviceUnregistered', '-SIPTrunkOOS', 'TransientConnection', '-CDRAgentSendFileFailureContinues',
                  '-CDRFileDeliveryFailureContinues']
    disqualifier = 'SyslogSeverityMatchFound'
    epunregreport = {}
    stationsreport = {}
    eprestartreport = {}
    devunregreport = {}
    siptrunkreport = {}
    transientreport = {}
    cdragentreport = {}
    cdrfilereport = {}
    print("Info: Parsing downloaded syslog files ... please wait ... ")
    for syslog in os.listdir(downloaddir):
        with open(os.path.join(downloaddir, syslog), 'r', encoding='utf-8') as syslogfile:
            for line in syslogfile:
                if disqualifier in line:
                    continue
                for search in searchlist:
                    searchpattern = re.compile(r'{}'.format(search))
                    searchresult = searchpattern.search(line)
                    if searchresult is None:
                        continue
                    elif searchresult is not None:
                        if searchresult.group(0) == searchlist[0]:
                            epunreg = parser.endpointparse(line)
                            epunregdata = ','.join(str(x) for x in epunreg.values())
                            if epunregdata in epunregreport:
                                epunregreport[epunregdata] += 1
                            elif epunregdata not in epunregreport:
                                epunregreport[epunregdata] = 1
                        elif searchresult.group(0) == searchlist[1]:
                            stations = parser.stationparse(line)
                            stationsdata = ','.join(str(x) for x in stations.values())
                            if stationsdata in stationsreport:
                                stationsreport[stationsdata] += 1
                            elif stationsdata not in stationsreport:
                                stationsreport[stationsdata] = 1
                        elif searchresult.group(0) == searchlist[2]:
                            eprestart = parser.eprestartparse(line)
                            epdata = ','.join(str(x) for x in eprestart.values())
                            if epdata in eprestartreport:
                                eprestartreport[epdata] += 1
                            elif epdata not in eprestartreport:
                                eprestartreport[epdata] = 1
                        elif searchresult.group(0) == searchlist[3]:
                            devunreg = parser.devunregparse(line)
                            devunregdata = ','.join(str(x) for x in devunreg.values())
                            if devunregdata in devunregreport:
                                devunregreport[devunregdata] += 1
                            elif devunregdata not in devunregreport:
                                devunregreport[devunregdata] = 1
                        elif searchresult.group(0) == searchlist[4]:
                            sipoos = parser.siptrunkparse(line)
                            siptrunkdata = ','.join(str(x) for x in sipoos.values())
                            if siptrunkdata in siptrunkreport:
                                siptrunkreport[siptrunkdata] += 1
                            elif siptrunkdata not in siptrunkreport:
                                siptrunkreport[siptrunkdata] = 1
                        elif searchresult.group(0) == searchlist[5]:
                            tranparse = parser.transientparse(line)
                            if tranparse is None:
                                pass
                            else:
                                trandata = ','.join(str(x) for x in tranparse.values())
                                if trandata in transientreport:
                                    transientreport[trandata] += 1
                                elif trandata not in transientreport:
                                    transientreport[trandata] = 1
                        elif searchresult.group(0) == searchlist[6]:
                            cdragentparse = parser.cdragentparse(line)
                            agentdata = ','.join(str(x) for x in cdragentparse.values())
                            if agentdata in cdragentreport:
                                cdragentreport[agentdata] += 1
                            elif agentdata not in cdragentreport:
                                cdragentreport[agentdata] = 1
                        elif searchresult.group(0) == searchlist[7]:
                            cdrfileparse = parser.cdrfileparse(line)
                            filedata = ','.join(str(x) for x in cdrfileparse.values())
                            if filedata in cdrfilereport:
                                cdrfilereport[filedata] += 1
                            elif filedata not in cdrfilereport:
                                cdrfilereport[filedata] = 1
    return epunregreport, stationsreport, eprestartreport, devunregreport, siptrunkreport, transientreport, \
        cdragentreport, cdrfilereport
```

As I provide the next snippet of code, a madman's attempt at creating an Excel Workbook with individual sheets for report data on a syslog type basis -- accounting for the top 10 chatty devices -- one thought comes to mind: The Devil's taxes must be less frustrating to figure out.

```text
# Create TopTalkers report by default with top 10 chatty syslogs
# Prompt user to create full report not filtered by top 10.
def createreport():
    data = '%s,%s\n'
    endpointout = list(itertools.islice(sorted(endpointreport.items(), key=lambda x: x[1], reverse=True), 30))
    stationsout = list(itertools.islice(sorted(stationsreport.items(), key=lambda x: x[1], reverse=True), 30))
    eprout = list(itertools.islice(sorted(eprestartreport.items(), key=lambda x: x[1], reverse=True), 30))
    devunregout = list(itertools.islice(sorted(devunregreport.items(), key=lambda x: x[1], reverse=True), 30))
    siptrunkout = list(itertools.islice(sorted(siptrunkreport.items(), key=lambda x: x[1], reverse=True), 30))
    transientout = list(itertools.islice(sorted(transientreport.items(), key=lambda x: x[1], reverse=True), 30))
    cdragentout = list(itertools.islice(sorted(cdragentreport.items(), key=lambda x: x[1], reverse=True), 20))
    cdrfileout = list(itertools.islice(sorted(cdrfilereport.items(), key=lambda x: x[1], reverse=True), 20))
    print("Info: Prepping report data ... ")
    with open(os.path.join(temppath, 'EndpointUnregistered.csv'), 'w+', encoding='utf-8') as eptemp:
        eptemp.write("count,device,ip,description,reason,node,lastsignal,callstate\n")
        for info, count in endpointout:
            eptemp.write(data % (count, info))
    with open(os.path.join(temppath, 'StationConnectionError.csv'), 'w+', encoding='utf-8') as sttemp:
        sttemp.write("count,device,reason,nodeid\n")
        for info, count in stationsout:
            sttemp.write(data % (count, info))
    with open(os.path.join(temppath, 'EndPointRestartInitiated.csv'), 'w+', encoding='utf-8') as eprtemp:
        eprtemp.write("count,device,product,nodeid,info\n")
        for info, count in eprout:
            eprtemp.write(data % (count, info))
    with open(os.path.join(temppath, 'DeviceUnregistered.csv'), 'w+', encoding='utf-8') as devtemp:
        devtemp.write("count,device,ip,description,reason,node\n")
        for info, count in devunregout:
            devtemp.write(data % (count, info))
    with open(os.path.join(temppath, 'SIPTrunkOOS.csv'), 'w+', encoding='utf-8') as siptemp:
        siptemp.write("count,device,peer_reasoncode,node\n")
        for info, count in siptrunkout:
            siptemp.write(data % (count, info))
    with open(os.path.join(temppath, 'TransientConnection.csv'), 'w+', encoding='utf-8') as trantemp:
        trantemp.write("count,device,ip,reason,node,mac,lastsignal,stationstate\n")
        for info, count in transientout:
            trantemp.write(data % (count, info))
    with open(os.path.join(temppath, 'CDRAgent.csv'), 'w+', encoding='utf-8') as cdragent:
        cdragent.write("count,month,cdr-repo-addr,cdr-node-addr,node\n")
        for info, count in cdragentout:
            cdragent.write(data % (count, info))
    with open(os.path.join(temppath, 'CDRFileDelivery.csv'), 'w+', encoding='utf-8') as cdrfile:
        cdrfile.write("count,month,billingsrv,node\n")
        for info, count in cdrfileout:
            cdrfile.write(data % (count, info))
    print("Info: Constructing TopTalkers report ... ")
    writer = pd.ExcelWriter(os.path.join(toptalkerspath, 'TopTalkersReport_' + timestr + '.xlsx'), engine='xlsxwriter')
    for tempfile in glob.glob(temppath + "\\*.csv"):
        filecombine = pd.read_csv(tempfile)
        (_, f_name) = os.path.split(tempfile)
        (f_shortname, _) = os.path.splitext(f_name)
        filecombine.to_excel(writer, f_shortname, index=False)
    writer.save()
```

I presume the writer was able to come to his senses, if only temporarily, to finish out his project as he was able to account for the files that were created earlier, account for OSError exceptions and tie it all together so the script actually runs. Based on the notes strewn around the room and the endless tabs opened in his web browser, it is clear this project was time-consuming. I would also dare to say it was soul consuming, given the state of our poor NOC Thoughts blog writer.

It is possible he will recover. Only time will tell.

### Where To Find It

You can find this ever-so-useful script on my [Github](https://github.com/Unhall0w3d/mind-enigma/blob/master/Reporting%20Scripts/UCSyslogParser.py)! It's easy to use, just provide the IP Address, Username, and Password for both OSadmin and GUIadmin and it does all the work! As always, PLEASE review all code and ensure it is safe to run before using in any production system. If you do not understand the code, and what it can/does do, it is generally advised not to run it. That said, if there are any issues found please report them as well as any related error messages, your Cisco Unified Communications Manager version and if possible, please retain a copy of your syslogs as there may be some syslog message format I didn't account for. These can be logged against Issues on Github. Join our Discord community using the invite link on the side navigation bar! I hope this is useful and I thank you for reading.
