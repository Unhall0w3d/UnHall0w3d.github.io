---
title: "Automating Memory Checks on Cisco VCS using Python"
layout: single
date: 2021-02-12T08:00:00-05:00
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

## Relevance

As a follow-up to my prior post [Verifying Memory Usage on VCS using Python](https://www.nocthoughts.com/blog/verifying-memory-usage-on-cisco-vcsexpressway-using-python-paramiko) I’d like to spotlight some changes that were made to the script on GitHub, why the changes were made, point out the readme file and also provide some examples of the output/emails that serve as notifications to the engineers responsible for monitoring the VCS/Expressway’s memory utilization.

<!--more-->

I’ll start by recapping the issue. On certain versions of VCS/Expressway x8.#.# there exists a memory leak that, if left unchecked, will cause the VCS/Expressway server to become unresponsive not only to GUI/CLI access but also for MRA logins or other typical Expressway functions. After working with Cisco TAC to confirm the memory leak, they recommended that we perform regular reboots of the affected servers until we are able to upgrade to x12.#.#. This upgrade will go through (eventually) for many reasons — UC Platform in it’s entirely will be upgraded to 12.x, Apple’s APN changes will also require the upgrade (see this link for more details on that [Apple APN Changes](https://www.cisco.com/c/dam/en/us/td/docs/voice_ip_comm/cucm/push_notifications/APNSUpdates.pdf), and simply to move away from a bugged version.

But as we all know these things take time, whether it’s budgetary constraints, slow moving approval processes, you name it. So in the meantime we end up needing to perform proactive regular reboots. To help limit the reboots to “only when they’re needed” I stumbled upon the following [Cisco Support Forum Post](https://community.cisco.com/t5/telepresence-and-video/expressway-memory-usage/td-p/3743732) in which it is explained that the SNMP OID of .1.3.6.1.2.1.25.2.2.0 returns the physical memory size of the system, and rough memory usage can be calculated by using the values of OIDs 1.3.6.1.2.1.25.2.3.1.6.1 (hrStorageUsed) and 1.3.6.1.2.1.25.2.3.1.5.1 (hrStorageSize) and calculating usage: (hrStorageUsed/hrStorageSize)x100. However, VCS/Expressway also utilizes SWAP which is not reported there.

So what we did was, first identify the command provided in the post that can allow us to monitor committed memory: “cat /proc/meminfo" and look for the "Committed_AS" value. Optionally you can use a pipe then "grep Committed_AS" to only see that value. Next is to poll the server using this command right up until we see it go unresponsive again, dial it back a bit and decide “This is when we should reboot”. For us, that was 6.5GB memory showing under the above command output. This helps, but we still had the requirement of logging into the environment to validate these values across an entire Expressway cluster. 

This is where my initial script came in, we still had to log in but the data collection was sped up. It helps, but isn’t as efficient as it could be. This is where the true “automation” takes place. Utilizing a Linux machine with SMTP set up and the “mail” command available, we are able to collect the data to a timestamped file and store it for the long term (in case we miss a required reboot we can see when it was identified as “above the threshold” and who was responsible for missing it if necessary), as well as notification of the output being collected via email. The script loops, sleeping for 12 hours before running again. Though the script hasn’t hit an exception, I do expect an email out to indicate an exception was hit if it happens. Through the email notifications we are able to drive down the required time to review the output and respond to the client of “everything checks out” or “we need to reboot X node, when can this be done?” to about 2 minutes, provided you don’t type like a hen pecking at grain on the ground — one finger, one letter at a time. 

So let’s get into the changes. As always, the script is available on my [GitHub](https://github.com/Unhall0w3d/mind-enigma/blob/master/expresswayMemoryCheck.py) - as well as the [ReadMe](https://github.com/Unhall0w3d/mind-enigma/blob/master/expresswayMemoryCheck_ReadMe.txt). Do note that there are commented out lines (explained in the ReadMe file) that allow for email notification provided the pre-requisites are set up. I do not cover these, but please ensure that the command “mail -s email@domain.com < test.txt” works, wherein the test.txt file should be in the same directory you are initiating the email from, and contain some data such as “This is a test”. 

## Important Points

1) We now append to a generic “ExpresswayHC.txt” file and, once all data is collected, we email the file, copy it (to change the name to include the timestamp), then delete the original file. This prevents us from sending old data in the email and having an ever-growing list of output.

2) We now collect username/password from user input. This is due to how I chose to start the script (described in the readme). You can modify this to use environment variables or some other method if you so choose.

3) Static assignments for file locations, file names, etc. were swapped out for variables.

4) Should some failure occur (unable to login to a device) the script will not stop, rather, it will report that an exception occurred via email and try again in 12 hours.

5) When successfully completed, prior to sleeping, the data is emailed out for review.

{% highlight Python linenos %}
#
# Script created by Ken Perry
# Script purpose is to verify memory util on Expressway Servers
# Script method is SSH to pull output of 'cat /proc/meminfo | grep Committed_AS'
# Script is set to run every 12 hours to provide feedback.
# If you need this script to check your expressway memory in this manner, you likely need to do it 1-2 times daily.
#

import time
import paramiko
import os
from getpass import getpass

# Define list of IP Addresses to SSH to.
# Replace the ip-addr# in quotes with an IP address (e.g. 10.161.1.133), one per line.
# Follow the syntax below to add additional entries

hostname = [
    "ip-addr1",
    "ip-addr2"
]

# Define Variables required for file handling
timestr = time.strftime("%Y%m%d-%H%M%S")
dirname = 'temp'
dir_path = os.getcwd()
path = os.path.join(dir_path, dirname)
filename = 'ExpresswayHC.txt'
timestampedfn = 'ExpresswayHC' + timestr + '.txt'

# Check if desired directory exists, create it otherwise
if os.path.exists(dirname) is False:
    os.mkdir(dirname)

# Input Requirements taken from User Input
username = input("Username: ")
password = getpass("Password: ")


# Command to execute
command = "cat /proc/meminfo | grep Committed_AS"

# Initialize SSH Client & Add to Known Hosts
client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())

# For each ip address in our list, SSH to the device.
# Run the defined command and log the output to a text file
# One text file per script run, script checks all required devices.


def healthcheck():
    for ipaddr in hostname:
        try:
            client.connect(hostname=ipaddr, username=username, password=password)
            stdin, stdout, stderr = client.exec_command(command)
            err = stderr.read().decode()
            with open(os.path.join(path, filename), 'a+') as rdr:
                rdr.write("+" * 5 + ipaddr + "+" * 5 + '\r')
                rdr.write(command + '\r')
                rdr.write(stdout.read().decode() + '\r')
                if err:
                    rdr.write(stderr.read().decode() + '\r')
        except:
            with open(os.path.join(path, filename), 'a+') as rdr:
                rdr.write('[!] Cannot connect to ' + ipaddr + '. Please verify reachability & Credentials.' + '\r')


def filehandling():
    # The below allows you to email the file to your email, or a distro list if you have smtp configured on your linux machine.
    # "mail" command should work before trying to use it through this script.
    # os.system('mail -s "Expressway Healthchecks" email@domain.com < ' + path + filename + '')
    os.system('cp ' + path + filename + ' ' + path + timestampedfn + '')
    os.system('rm ' + path + filename)


while True:
    try:
        healthcheck()
        filehandling()
        # Uncomment the line below if you use the email function above.
        # print("Email has been sent.")
    except:
        print("Oh no! We failed somewhere. We'll try again in 6 hours. Use Email function for better notifications.")
        # os.system('mail -s "Script Stopped" email@domain.com')
    finally:
        time.sleep(43200)

{% endhighlight %}

## Things to know

I'd like to provide some data from the ReadMe for those that are not native Linux users, in my example we’ll need to use “Screen” to keep the script running 24/7 without being connected to the Linux terminal, but still be able to access and stop/rerun the script as needed. If you require invoking a virtual environment before running the script, we account for that, or, you can run the script directly if you so choose. Once the script is invoked it will prompt for Username/Password and should report back shortly that an email was sent. As mentioned in the ReadMe, if this check is something you need to do due to the bug, it’s likely you’ll need to check it regularly and this is where the script really shines.

### How To Run

If you require invoking a virtual environment you likely already know how to do this, however, to run this script in a Screen and detatch after providing required input, do the below:

### Run Directly

    screen bash -c 'python expresswayMemoryCheck.py'

### Invoke venv and run (edit as needed)

    screen bash -c 'cd /home/user/foldercontainingvenv/; source venv/bin/activate; cd /home/user/scriptlocation/; python expresswayMemorycheck.py'

### To Detach from Screen

    ctrl+A --> "d"

### To Attach to Screen

    screen -list

         verify the process id. The screen name will be something like "22016.something". The number will change.

    screen -r 22016

Finally, we’ll want to take a look at how the data is reported. The email should comain in from “name@domain.com” as configured on your Linux/SMTP — e.g. (LinuxVM1@voip.local), the subject should be “Expressway Healthchecks” and the body will contain the below data. It could be sent as an attachment, however, I did not want to deal with encoding/constructing/composing the email - if a more secure method is desired you may want to do this another way. I was able to set up a rule in Outlook for “Subject Contains” and “Sender Is” to direct it to a new folder.

<span class="image fit"><img src="{{ "/assets/images/sanitizedemail.png" | absolute_url }}" alt="" /></span>

Example Email sent by the Script containing output from Expressway/VCS

And there we go. The engineer’s responsibility was modified to no longer require access to the environment, connect to devices, run commands, review output, document it, then send an email. They now just review output that came in through email, copy/paste the data to a new email to inform the concerned stakeholders of what they’re seeing and make recommendations to reboot if/as needed. In my personal testing a “one daily” notification is sufficient, however, if you are finding that memory utilization is rising rapidly you may want to modify the sleep timer to a lower value (in seconds). The script is currently set to loop every 12hrs.

Well, I hope this is useful in a few ways, either to provide a useful tool for your toolbelt, to shine some light on an issue in some x8 versions of VCS/Expressway, or even to just see how other engineers tackle the issues that they face. If you have any situations like this I would love to hear about it! Leave me a comment, or get at me on Twitter or LinkedIn. You can find the social buttons in the top right hand corner of the page. Stay positive and keep on keepin' on, until next time!