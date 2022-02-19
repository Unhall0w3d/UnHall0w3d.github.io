---
title: "Building a Toolbelt for UC w/ Python"
layout: post
date: 2020-05-14T08:00:00-05:00
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

<span class="image fit"><img src="{{ "/assets/images/nocthoughtstb1.png" | absolute_url }}" alt="" /></span>

In my last post I share a script that I created with the help and guidance of some current and former colleagues. It used BeautifulSoup and regular expression to parse html code and return some data to determine the Device Name, Registration State and Model Number of a given phone regardless of the phone type, it just needed to be http accessible and not require a login. Though that last requirement hasn't changed (yet), I had issues appropriately searching for regular expressions using BS4.

<!--more-->

What's funny, or perhaps not funny, is that every Stack Overflow post and nearly every conversation with my colleagues lead to the same comment being made, even if we were able to work on the script and 'make it better' or 'make it do more'... that comment was "Don't use regular expressions with BeautifulSoup, do this instead." The this was different depending on who I was talking to but it primarily boiled down to pulling down the data as XML and parsing that instead... so that's what I did.

Not only did I change the mechanism that we use to search the data returned from a Cisco Phone, we also changed the URLs being hit. Instead of having to hunt down the individual URL structures for the Console Logs page, or the Network Setup page, or the Device Information page (which is different on almost every series of phone -- thanks Cisco) we are now utilizing the /DeviceInformationX and /NetworkConfigurationX URLs that present the data from those respective pages as XML code.

This allows us to parse for specific xml tags (e.g. serialNumber) and if it exists, assign a variable to the return of the xml tag's contained text. We gather the device name, model, serialnumber, and registration state and when tested against a few devices, we had good valid returns against phones such as ATA187, Cisco IP Communicator, Cisco 8851, Cisco 7960, Cisco 7937G, and a CCM Registered DX650.

In addition to this I explored adding a very basic menu in order to merge in another script that I had worked on which hits various console log URLs and if we get an HTTP 200 back, perform a wget -r and pull the log files in the /FS/ directory. We also pass through an allow statement for messages*, *.log and *.tar.gz files to pull historical logs and crash data where available.

To see the live version of the script which continues to get updated as I fix issues and add functionality, visit my GitHub repo here:

[NOCThoughts GitHub Repo](https://github.com/Unhall0w3d/mind-enigma/blob/)

Specific script I am referencing can be found here; please see the ReadMe for caveats, phone coverage and other details.

[NOCThoughts Toolbelt Script](https://github.com/Unhall0w3d/mind-enigma/blob/master/NOCThoughtsToolbelt.py)

{% highlight Python linenos %}
#!/usr/var/python
# -*- code:UTF-8 -*-

#####################################
# Script created by Ken Perry, 2020 #
#       NOC THOUGHTS BLOG           #
# https://nocthoughts.wordpress.com #
#####################################

# Modules Imported for Script Functionality
import subprocess
import time
import xml.etree.ElementTree
from io import BytesIO

import pycurl
import requests

# Define Variables
timestr = time.strftime("%Y%m%d-%H%M%S")


# Define Main Menu
def menu():
    print()
    choice = input("""
                      1: Pull Cisco Phone Info
                      2: Pull Cisco Phone Logs
                      3: Not Implemented
                      Q: Quit

                      Selection: """)

    if choice == "1":
        serialnumpull()
        menu()
    elif choice == "2":
        ips = phonecollection()
        [logcollect(ip_addr) for ip_addr in ips]
        print('############# Files have been stored in ~/ in an IP specific folder #############')
        menu()
    elif choice == "3":
        print("Not Implemented")
        exit()
    elif choice == "q" or choice == "Q":
        exit()
    else:
        print("You must select an option on the menu.")
        print("Please try again")
        menu()


# Log collection function that runs wget against consolelog url to pull recursively.
def logcollect(ip_addr):
    destfolder = str('~/')
    uris = list({
        '/CGI/Java/Serviceability?adapter=device.statistics.consolelog',
        '/localmenus.cgi?func=603',
        # '/NetworkConfiguration', Waiting on updated URL structure for phone models I don't have access to.
        '/Console_Logs.htm',
        '/Console_Logs.html',
        '/?adapter=device.statistics.consolelog',
    })
    for uri in uris:
        try:
            response = requests.get(f'http://', timeout=6)
            if response.status_code == 200:
                subprocess.call(
                    'wget -T 5 --tries=2 -r --accept "*.log, messages*, *.tar.gz" http://' + ip_addr +
                    uri + ' -P ' + destfolder,
                    shell=True)
        except requests.exceptions.ConnectionError:
            print('Far end ' + ip_addr + 'has closed the connection.')
        except requests.exceptions.Timeout:
            print('Connection to ' + ip_addr + ' timed out. Trying next.')
        except Exception as e:
            print('The script failed. Contact script dev with details from your attempt and failure.')
            print(e)


# Phone Collection function that asks for a number for how many phones we'll check, then their IP addresses.
def phonecollection():
    num_phones = int(input('How many phones?: '))
    if type(num_phones) != int:
        print('Error: Expected Integer.')
        exit(1)
    ips = []
    for phonecount in range(num_phones):
        ips.append(input('What is the phone IP address?: '))
    return ips


def getxmldata(ip_addr, _act):
    buffer = BytesIO()
    curl = pycurl.Curl()
    _url = f'http://'
    curl.setopt(pycurl.CONNECTTIMEOUT, 5)
    curl.setopt(curl.URL, _url)
    curl.setopt(curl.WRITEDATA, buffer)
    try:
        curl.perform()
        curl.close()
        return xml.etree.ElementTree.fromstring((buffer.getvalue()))
    except pycurl.error:
        print('Connection Timed Out. No response after 5 seconds for ' + ip_addr + '. Trying next.')
        exit(1)


def serialnumpull():
    xmluris = ['/NetworkConfigurationX', '/DeviceInformationX']
    inputfile = input('What is the name of the input text file? (e.g. iplist.txt): ')
    with open(inputfile) as txtfile:
        lines = [line.rstrip() for line in txtfile]
        for line in txtfile:
            lines.append(line)
    for ipaddy in lines:
        try:
            for uri in xmluris:
                root = getxmldata(ipaddy, uri)
                if root == -1:
                    break
                _root = uri.strip('/X')
                for xmltag in root.iter(_root):
                    if xmltag.find('HostName') is not None:
                        macaddr = xmltag.find('HostName').text
                    if xmltag.find('modelNumber') is not None:
                        modelnum = xmltag.find('modelNumber').text
                    if xmltag.find('serialNumber') is not None:
                        serialnum = xmltag.find('serialNumber').text
                    else:
                        serialnum = "n/a"

                    for i in range(2):
                        if xmltag.find('CallManager%s' % (i + 1)) is not None:
                            if xmltag.find('CallManager%s' % (i + 1)).text.find('Active') != -1:
                                cucmreg = xmltag.find('CallManager%s' % (i + 1)).text

            if root == -1:
                continue
            print()
            print("IP:", ipaddy, "DeviceName:", macaddr, "Model:", modelnum, "Serial Number:", serialnum, "Reg State:", cucmreg)
        except Exception as m:
            print(m)
            exit(2)
    return


# Call Menu
menu()
{% endhighlight %}

And it wouldn't be nice of me to leave out what good returns would look like, so I've included that below. Output has been sanitized.

```text
/home/kenneth/PycharmProjects/mind-enigma/NOCThoughtsToolbelt.py
                      1: Pull Cisco Phone Info                      
                      2: Pull Cisco Phone Logs                     
                       3: Not Implemented                      
                       Q: Quit                      
                       Selection: 1
What is the name of the input text file? (e.g. iplist.txt): iplist.txt

IP: 192.168.1.241 DeviceName: SEP123456789100 Model: CP-8851 Serial Number: FCH12345678 Reg State: cucm-fqdn.voip.local  Active
IP: 192.168.1.220 DeviceName: CIPCKPERRY Model: Cisco Communicator Serial Number: None Reg State: cucm-fqdn.voip.local   Active
IP: 10.25.200.172 DeviceName: SEP123456789101 Model: CP-DX650 Serial Number: FCH12345678Q Reg State: cucm-fqdn.voip.local Active
IP: 10.9.110.95 DeviceName: SEP123456789102 Model: CP-7832 Serial Number: FCH12345678 Reg State: cucm-fqdn.voip.local  Active
IP: 10.5.110.41 DeviceName: SEP123456789103 Model: CP-7937 Serial Number: n/a Reg State: cucm-fqdn.voip.local Active
IP: 10.5.110.21 DeviceName: SEP123456789104 Model: CP-7960G Serial Number: FCH12345678 Reg State: cucm-fqdn.voip.local  Active
```

Now for the log pull portion, as we're using the subprocess module to spawn a subprocess and pipe the wget command output to the shell, we get the typical wget visuals that show each file being downloaded. I won't post that here as it's a whole lot of junk, however, this shows an example of the output pulled and it only took a few seconds.

```text
/home/kenneth/PycharmProjects/mind-enigma/NOCThoughtsToolbelt.py

                      1: Pull Cisco Phone Info                      
                      2: Pull Cisco Phone Logs                      
                      3: Not Implemented                      
                      Q: Quit                      
                      Selection: 2
How many phones?: 1
What is the phone IP address?: 192.168.1.241

<wget output ommitted>
############# Files have been stored in ~/ in an IP specific folder #############
```

FS Directory is where the logs are held;

```text
kenneth@UbuntuDDEVM:~/192.168.1.241$ lsCGI  FS  robots.txt.tmp
kenneth@UbuntuDDEVM:~/192.168.1.241$ cd FS
kenneth@UbuntuDDEVM:~/192.168.1.241/FS$ ls
crash_20170530_201642.tar.gz
main_20200511_153002.tar.gz  
main_20200512_043001.tar.gz  
main_20200512_173001.tar.gz  
main_20200513_063001.tar.gz  
main_20200513_193001.tar.gz  
main_20200514_080002.tar.gz
lastimage_20190330_175533.tar.gz  
main_20200511_163002.tar.gz  
main_20200512_053001.tar.gz  
main_20200512_183001.tar.gz  
main_20200513_073001.tar.gz  
main_20200513_201501.tar.gz  
main_20200514_090002.tar.gz
ain_20200511_044502.tar.gz
main_20200511_173002.tar.gz  
main_20200512_063001.tar.gz  
main_20200512_193001.tar.gz  
main_20200513_083001.tar.gz  
main_20200513_210001.tar.gz  
main_20200514_100001.tar.gz
main_20200511_054502.tar.gz       
main_20200511_183001.tar.gz  
main_20200512_073001.tar.gz  
main_20200512_203001.tar.gz  
main_20200513_093001.tar.gz  
main_20200513_220001.tar.gz  
main_20200514_110002.tar.gz
main_20200511_064501.tar.gz       
main_20200511_193001.tar.gz  
main_20200512_083001.tar.gz  
main_20200512_213001.tar.gz  
main_20200513_103001.tar.gz  
main_20200513_230001.tar.gz  
main_20200514_120002.tar.gz
main_20200511_074502.tar.gz       
main_20200511_203001.tar.gz  
main_20200512_093001.tar.gz  
main_20200512_223001.tar.gz  
main_20200513_113001.tar.gz  
main_20200514_000001.tar.gz  
main_20200514_130002.tar.gz
main_20200511_084501.tar.gz       
main_20200511_213001.tar.gz  
main_20200512_103001.tar.gz  
main_20200512_233002.tar.gz  
main_20200513_123001.tar.gz  
main_20200514_010001.tar.gz  
main_20200514_140002.tar.gz
main_20200511_094501.tar.gz       
main_20200511_223001.tar.gz  
main_20200512_113001.tar.gz  
main_20200513_003002.tar.gz  
main_20200513_133001.tar.gz  
main_20200514_020001.tar.gz  
messagesmain_20200511_104502.tar.gz       
main_20200511_233001.tar.gz  
main_20200512_123001.tar.gz  
main_20200513_013002.tar.gz  
main_20200513_143001.tar.gz  
main_20200514_030001.tar.gz  
messages.0main_20200511_114502.tar.gz       
main_20200512_003001.tar.gz  
main_20200512_133001.tar.gz  
main_20200513_023002.tar.gz  
main_20200513_153001.tar.gz  
main_20200514_040001.tar.gz  
messages.1main_20200511_123002.tar.gz       
main_20200512_013001.tar.gz  
main_20200512_143001.tar.gz  
main_20200513_033002.tar.gz  
main_20200513_163001.tar.gz  
main_20200514_050001.tar.gz
main_20200511_133002.tar.gz       
main_20200512_023001.tar.gz  
main_20200512_153001.tar.gz  
main_20200513_043002.tar.gz  
main_20200513_173001.tar.gz  
main_20200514_060002.tar.gz
main_20200511_143002.tar.gz       
main_20200512_033001.tar.gz  
main_20200512_163001.tar.gz  
main_20200513_053001.tar.gz  
main_20200513_183001.tar.gz  
main_20200514_070001.tar.gz
```

And there we go. Two working tools we can improve, bugfix, work up proper exceptions for and.. a third, unimplemented option for whatever script I write up next. Some TODOs or ideas I have include exporting the device info pull's macaddr variable output into a file where we print the macaddr + '\n' to create a .txt file containing the device names one per line and using the function I've already built to pull those device names in to another script, such as hitting CUCMs API.

Thank you for stopping by the blog, you can follow my Twitter for post notifications @ThoughtsNOC, @kperryuc or follow me on LinkedIn @kperryuc. Post suggestions and feedback are welcome, and issues with the script should be raised against the GitHub repo! You can also join the Discord noted on the main page.
