---
title: "VCS/Expressway 8.7 & Old Host Keys"
date: 2019-06-24T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Telepresence
  - Cisco
tags:
  - Cisco VCS
  - Cisco Expressway
  - Expressway
  - VCS
  - Unified Communications
  - Cisco UC
  - Cisco
  - Telepresence
---

<head>
    <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-7351461893377144"
     crossorigin="anonymous">
     </script>
</head>

## A Wild Permission Denied Has Appeared
So here I am trying to access a VCS-C/VCS-E pair using SSH like I would for any other device any other day. I load up PuTTY and jump to a linux box (proxy) and attempt to SSH to the VCS.  Imagine my dismay when attempting to log in to the VCS server I am greeted with a permission denied error.

```text
ken@ubuntu:~$ ssh admin@10.10.10.10
Permission denied (publickey,keyboard-interactive).
```

Now I could add a -v into my SSH statement and attempt to get verbose output, troubleshoot from Ubuntu's perspective and (potentially) go down a rabbit hole of a potentially Ubuntu specific issue. I didn't want that. I figured, OK. If I can't get in through Ubuntu, let's check if it's the source or the destination device (by logging in from elsewhere). I already had OpenSSH installed on Windows 10 for a time but will describe the steps to install the OpenSSH Client below;

### Find and Install OpenSSH

Find OpenSSH for install. This can be done through the “Settings” GUI in Win10 but I could only find the server, not client version. So my next step was to query the WindowsCapability for OpenSSH.

```text
PS C:\Windows\system32> Get-WindowsCapability -Online | ? Name -like 'OpenSSH*'                                         
Name  : OpenSSH.Client~~~~0.0.1.0
State : NotPresent
Name  : OpenSSH.Server~~~~0.0.1.0
State : NotPresent
```

### Install OpenSSH

Perform an install command to add the OpenSSH Client functionality to PowerShell utilizing the Name provided in the command from Step 1.

```text
PS C:\Windows\system32> Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0
Path          :
Online        : True
RestartNeeded : False
```
 
### SSH on over

Perform an SSH from PowerShell on Windows 10. And here's where I got a tip as to what was happening (now that I've tested from two machines and the second provided more actionable output up front). We're failing to connect because the ssh-dss key type was deprecated. [Details Here](https://www.openssh.com/legacy.html)

```text
PS C:\Windows\system32> ssh admin@10.16.10.100
Unable to negotiate with 10.16.10.100 port 22: no matching host key type found. Their offer: ssh-dss 
```

### The Documentation Has What We Need

Relevant data has been copied out here, and is thanks to the folks at OpenSSH for documenting this.

```text
Another example, this time where the client and server fail to agree on a public key algorithm for host authentication:

Unable to negotiate with legacyhost: no matching host key type found. Their offer: ssh-dss
OpenSSH 7.0 and greater similarly disable the ssh-dss (DSA) public key algorithm. 
It too is weak and we recommend against its use. 
It can be re-enabled using the HostKeyAlgorithms configuration option: ssh -oHostKeyAlgorithms=+ssh-dss user@legacyhost or in the ~/.ssh/config file:Host somehost.example.orgHostKeyAlgorithms +ssh-dss
```

### This Time With Feeling

Utilizing this new information I was able to modify my SSH statement by adding the -oHostKeyAlgorithms=+ssh-dss command and voila! We have a password prompt!

```text
PS C:\Windows\system32> ssh -oHostKeyAlgorithms=+ssh-dss admin@10.10.10.10
Password:
```

Success! Now, you might be wondering why I didn't know about this already. Well, it's because of how old the VCS version is coupled with never having accessed the device via SSH prior to this. Given that I work for an MSP I could work on the same client every day for two weeks, and conversely it could be 3 months between engagements with the client. A lot changes, new devices are brought on, etc. So this is how I tackled my VCS access issue. Was it the most straight forward? Maybe not. Did it work? Yeah it did. And hopefully this will help you, either with the same or similar issue, or even when thinking about the most efficient way to go about working around the issues we encounter on a day to day basis.

Make sure to follow the blog to get alerts on new posts, check out my Twitter (@kperryuc) where you can also ask UC and DC related questions, suggest post topics, or talk about anything!
