---
title: "Verifying Memory Usage on Cisco VCS"
layout: single
date: 2021-01-08T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Telepresence
  - Cisco
  - Python
tags:
  - Cisco VCS
  - Cisco Expressway
  - Expressway
  - VCS
  - Python
  - Paramiko
  - Scripts
  - Unified Communications
  - Cisco UC
  - Cisco
  - Telepresence
---

## Gotta Do It Faster

Today I had the same question that many, many people have had throughout history: “How do I do *this particular thing* better, or faster?” or, in the IT space, how do I automate this? What is this exactly, you might ask? Well, it’s in the title... but to explain what I was doing we’re going to need a bit of story time.

<!--more-->

<a href="#" class="image main"><img src="{{ "/assets/images/scriptss1.PNG" | absolute_url }}" alt="The script!" /></a>

Recently I was tasked with performing health checks against Cisco VCS/Expressway devices due to a bug in one of the x8.x.x versions that results in a memory leak leading to an unresponsive Expressway server. This came about due to a Sev 1 event in which the client had an unresponsive, but otherwise healthy (good, healthy data coming back for relevant monitoring, system resource utilization, etc.)… however… at one point or another I stumbled upon a [Cisco Support Forum](https://community.cisco.com/t5/telepresence-and-video/expressway-memory-usage/td-p/3743732) post while looking at SNMP polling and specifically OIDs for Expressway where it was discussed that there is a better way to review memory utilization, and that’s directly in the CLI.

Now, specifically what we are supposed to do is log in to the device’s CLI using the ‘root’ credentials and run a basic cat command from it’s Linux underpinnings. The command being ‘cat /proc/meminfo ' and pipe to ' grep Committed_AS’. It only takes a second or so to run, and that’s fair enough, but some Expressway Clusters can be rather large and require multiple SSH sessions to gather the data… and that’s all well and good… but when you’re told that this check needs to be done daily, and your method of access to the devices to do it manually is via screen share (inherently slower)… you might see where I went with this. There had to be a better way to do it. 

The first thing I did was start working through a simple script using Paramiko to SSH in to a list of device IPs (a simple ‘for x in y:’ where y is the list of IP Addresses) using defined credentials, issue the one command ‘cat /proc/meminfo ' and pipe to 'grep Committed_AS’, and report back the output to the shell. Simple enough, and it worked too. Now, this changed how our health checks would go: The engineer would still have to have access facilitated for them, manually connect and issue commands, decipher output via PuTTY terminal screen, then circle back to their main desktop to send an email giving the all clear, or looking for authorization to reboot the node(s) proactively off hours. Okay… but we still need to fix all the slow parts. I received feedback from a colleague regarding ways to get my script to work in cron (including changes to the code itself) as well as considerations for scalability, and I thank him for the help!

First was the need to run the script automatically without any manual intervention. For this we utilized an Ubuntu box and a cron job to run the script at a given time every day. This introduced a few issues with how I had the script set up. First of all is requiring user input for the username and password for the Expressway devices, as that’s not an option with cron. For this I would refer you to the following Ubuntu help page discussing [Environment Variables](https://help.ubuntu.com/community/EnvironmentVariables). They were set by modifying the ~/.pam_environment file to establish the environment variables ‘expwyun’ for the username and ‘expwypw’ for the password. I then had to modify the script to look at the environment variable keyword using the “os” module.

Another big issue was the device output and how it was presented. Because I was really just testing initially I sent the device output to shell with print() statements. This wouldn’t be necessary as there’s no one seeing the response back when the cron job runs. For this, I just commented out the print statements in the event I need them for debugging later on. The most convenient way to get the output was to have it stored as a file locally on the Ubuntu box, but also emailed out for review as an attachment. To facilitate portions of this within the script I established a datetimestring, folder to store the output in, the current working directory, a way to verify if the desired output folder exists or not and create it if it does not… just a few things. With those variables and statements established I added in lines to, rather than print output to shell, append the output to a file with headers defining what device the output belonged to, and the command that was run. This file is stored in the current working directory inside a folder labeled ‘temp’, with the file name containing ‘ExpresswayHC+datetimestring+.txt’.

All that’s left to do is set up the cron job to execute the script, and have the output of the newest file in the directory  emailed out for review. This cuts down an affair that, at times, can last 30+ minutes down to around 2. Open an email, open an attachment, confirm Committed_AS value is <6.5GB and move on. If it’s >6.5GB used, move to reboot the node at the next approved change window. Much, much faster to execute on from an Admin/Engineer perspective, giving you the option of increasing the health check frequency to every 12 or even 6 hours if the need is there, and it will still be faster than manually doing it once.

As with all the scripts I create they can be found on my [GitHub](https://github.com/Unhall0w3d/mind-enigma/blob/master/expresswayMemoryCheck.py). I hope that the story and walkthrough that I provided makes it a little easier for those that don’t know or understand the Python language, I am by no means an expert I just make scripts for very specific requests, when the need is there or I’m generally interested in the use case, which means doing it however I can. But, it works. The username and password variables can be modified to a static entry or user input fairly easily if you don’t want to use an environment variable, and the print statements can have their comment mark removed to restore output to the shell. Similarly to remove logging to a file, comment out the rdr.write lines. I hope this helps someone, though I hope few people are still dealing with VCS/Expressway X8.x.x. The basic format of the script will be useful to me in creating more robust health check scripts against more devices.

Before we get to the script itself, here’s an example of the output when reported to the shell (when using the lines that are currently commented out).

```text
C:/Users/kperry/PycharmProjects/pythonProject/expresswayMemoryCheck.py
What is the username?: root
What is the password?:

[!] Cannot connect to the Expressway Server 1.2.3.4. Please manually verify access.

++++++++++ 2.3.4.5 ++++++++++
========== cat /proc/meminfo | grep Committed_AS ==========
Committed_AS: 4555384 kB

Process finished with exit code 0
```

The above demonstrates that even if a node is unresponsive we are still able to progress to the others on the list and successfully pull the stats. We then convert from KB to GB, assess if it’s < or > 6.5GB and react accordingly! Do note that the output will look similar within the file. The output was formatted suitably enough for me, though it may not be for you, so before you run the script: 1) Make sure you understand what it does, don’t just trust me. 2) Modify the values that are statically defined, such as the ‘hostname’ array contents, the username/password collection (leave it as an Env Var or modify to use input or other method per your needs), and the desired destination folder  (if you don’t like using “temp”) and finally 3) Have fun with it. If you have lab devices, use the skeleton of the script and modify it to pull commands from an IOS device, or maybe a callmanager? Would need some testing but even if it’s still for an Expressway server you could certainly add more commands by making the command variable an array, similar to the hostname var!

{% highlight Python linenos %}
#
# Script created by Ken Perry
# Script purpose is to verify memory util on Expressway Servers
# Script method is SSH to pull output of 'cat /proc/meminfo | grep Committed_AS'
#

import time
import paramiko
import os
import sys

# Define list of IP Addresses to SSH to
hostname = [
    "ip-addr1",
    "ip-addr2"
]

# Define Variables required for file creation
timestr = time.strftime("%Y%m%d-%H%M%S")
dirname = 'temp'
dir_path = os.getcwd()
path = os.path.join(dir_path, dirname)

# Check if desired directory exists, create it otherwise
if os.path.exists(dirname) is False:
    os.mkdir(dirname)

# Input Requirements taken from Env Variables
try:
    username = os.environ['expwyun']
    password = os.environ['expwypw']
except:
    sys.exit()

# Command to execute
command = "cat /proc/meminfo | grep Committed_AS"

# Initialize SSH Client
client = paramiko.SSHClient()

# Add to Known Hosts
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

# For each ip address in our list, SSH to the device.
# Run the defined command and log the output to a text file
# One text file per script run, script checks all required devices.

for ipaddr in hostname:
    try:
        client.connect(hostname=ipaddr, username=username, password=password)
        # print("+" * 10, ipaddr, "+" * 10)
        # print("=" * 10, command, "=" * 10)
        stdin, stdout, stderr = client.exec_command(command)
        # print(stdout.read().decode())
        err = stderr.read().decode()
        # if err:
            # print(err)
        with open(os.path.join(path, 'ExpresswayHC' + timestr + '.txt'), 'a+') as rdr:
            rdr.write("+" * 10 + ipaddr + "+" * 10 + '\n')
            rdr.write("=" * 10 + command + "=" * 10 + '\n')
            rdr.write(stdout.read().decode() + '\n')
            if err:
                # print(err)
                rdr.write(stderr.read().decode() + '\n')
        client.close()
    except:
        # print("[!] Cannot connect to the Expressway Server " + ipaddr + ". Please manually verify access.")
        with open(os.path.join(path, 'ExpresswayHC' + timestr + '.txt'), 'a+') as rdr:
            rdr.write("[!] Cannot connect to the Expressway Server " + ipaddr + ". Please manually verify access." + '\n')

{% endhighlight %}

I hope this has been informative, and encourage you to follow the @ThoughtsNoc Twitter page for post announcements, to suggest future posts or discuss UC topics! Check out my
GitHub repository or other socials if that's your thing. Until next time!