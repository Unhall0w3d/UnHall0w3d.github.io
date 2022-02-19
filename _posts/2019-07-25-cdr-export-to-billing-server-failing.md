---
title: "CDR Export to Billing Server Failing"
layout: post
date: 2019-07-25T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Cisco
  - Unified Communications
  - Linux
tags:
  - CUCM
  - Cisco Unified Communications Manager
  - Callmanager
  - UC VOS
  - UC
  - SFTP
  - CDR
  - Call Detail Record
  - Unified Communications
  - Cisco UC
  - Cisco
---

Billing servers are used in UC environments to collect CDR/CMR data and display them (ideally in a much better fashion than CDR Analysis & Reporting), make them searchable and provide insights into cause codes, call durations, endpoint utilization and more. And when they work, they typically work great. Could be Variphy, Splunk, a custom billing server you're developing. Doesn't really matter which it is, but typically as long as the user account has permissions for SFTP, proper access to the desired directory, and the IP is reachable on Port 22 it all just works. Until it doesn't.

<!--more-->

In our configuration for the Billing Servers we operate on an Active/Standby config with a Virtual IP that is shared between the two. When a failover occurs the Secondary becomes active on the VIP and takes over. We just so happen to have had a failover on 7/15/2019 and have not received CDRs since.

## Review and Troubleshooting

The first thing I do is check out the "preserve" folder on the Cisco Callmanager server. I connect to the CLI using SSH and issue the command "file list activelog /cm/cdr_repository/preserve/MMDDYYYY/" and confirm that the CDR/CMR data exists in the Preserve Folder waiting to be sent (as it has been failing). To get us back to today, I manually transfer the files over to the Billing Server using "file get activelog" commands on a per-date basis.

Next I look at the traces. For this I issue the command "file list activelog /cm/trace/cdrrep/log4j/ detail" to confirm the latest file name so I can review.

```text
admin:file list activelog /cm/trace/cdrrep/log4j/ detail

 25 Jul,2019 13:12:01            0  cdrrepThreadDump.log

 25 Jul,2019 13:12:02           36  cdrrepmgr.bin

 25 Jul,2019 13:11:53      133,772  cdrrepmgr00072.log

 25 Jul,2019 15:12:40      559,502  cdrrepmgr00073.log

 dir count = 0, file count = 4
```

Next I issue the command "file view activelog /cm/trace/cdrrep/log4j/cdrrepmgr00073.log" to take a look at the log file, and specifically I want to find data relating to the billing server IP I'm concerned with. What I find is two different sections showing the failure. Most importantly we find out why.

```text
2019-07-25 13:12:11,889 INFO  [main] cdrrep.CDRRepClass (CDRRepClass.java:179) - CDRSender 1 is created

2019-07-25 13:12:11,889 INFO  [main] cdrrep.CDRRepClass (CDRRepClass.java:181) - CDRSender 1 is started

2019-07-25 13:12:11,889 INFO  [Thread-11] cdrrep.CDRSender (CDRSender.java:85) - CDRSender for destination 1 is running...

2019-07-25 13:12:11,971 ERROR [main] sftpapi.SFTPConnection (SFTPConnection.java:252) - error Making SFTP connectionAlgorithm negotiation fail

2019-07-25 13:12:11,971 ERROR [main] sftpapi.ftpClient (ftpClient.java:246) - connect(): Failed connect to 1.1.1.1

2019-07-25 13:12:11,971 ERROR [main] cdrrep.FtpManager (FtpManager.java:75) - FtpManager constructor 1: Establish server connection to host [1.1.1.1] failed!

2019-07-25 13:12:18,996 ERROR [Thread-13] cdrrep.FtpManager (FtpManager.java:223) - SFTP/FTP failed: cmr_StandAloneCluster_03_201907231317_844004 to 1.1.1.1

2019-07-25 13:12:18,996 ERROR [Thread-13] cdrrep.LogConfig (LogConfig.java:157) - Java Exception happened in my CDRSender, with Exception:

 java.lang.Exception: SFTP/FTP failed: cmr_StandAloneCluster_03_201907231317_844004 to 1.1.1.1

         at com.cisco.ccm.cdrdlv.cdrrep.FtpManager.sendFile(FtpManager.java:225)

         at com.cisco.ccm.cdrdlv.cdrrep.CDRSender.run(CDRSender.java:358)

2019-07-25 13:12:18,996 INFO  [Thread-13] cdrrep.CDRSender (CDRSender.java:373) - sendSuccess=false, numOfFailure=1

2019-07-25 13:12:18,996 ERROR [Thread-13] cdrrep.CDRSender (CDRSender.java:374) - java.lang.Exception: SFTP/FTP failed: cmr_StandAloneCluster_03_201907231317_844004 to 1.1.1.1

2019-07-25 13:12:18,996 ERROR [Thread-13] cdrrep.CDRSender (CDRSender.java:375) - Unable to successfully send file to outside billing server 1.1.1.1

2019-07-25 13:12:18,997 INFO  [Thread-13] cdrrep.CDRSender (CDRSender.java:379) - First time failure, not to raise alarm
```

So we know that it's failing to send to the billing server, and we know it's due to an algorithm negotiation failure. The next part is compliments of my colleague Mark (Really, thanks Mark!) and in his review and testing he found that we can utilize NMAP to query against the billing servers NAT IP (as they aren't local) and confirm what algorithms are being provided.

## Using NMAP to Port Scan

1. Navigate to [NMAP's Website](https://nmap.org/download.html) and download the latest stable Windows release.
2. Install the program in the default location
3. Open Powershell
4. Issue the command "*cd 'C:\Program Files (x86)\nmap\'*"
5. Issue the command "*nmap --script ssh2-enum-algos -sV -p 22 ipaddr*" -- do this twice, once for the Primary and once for the Secondary

### Primary

<span class="image fit"><img src="{{ "/assets/images/cdrexport1.png" | absolute_url }}" alt="" /></span>

### Secondary

<span class="image fit"><img src="{{ "/assets/images/cdrexport2.png" | absolute_url }}" alt="" /></span>

I copied out the output regarding the ssh2-enum-algos into notepad++ and compared. What I found is that the secondary server was only offering a small set of algorithms and the one CUCM's CDR Repository Manager wanted to use was not included.

<span class="image fit"><img src="{{ "/assets/images/cdrexport3.png" | absolute_url }}" alt="" /></span>

From here it was out of my hands, this was sent back to the appropriate team that manages the billing server to perform remediation against the secondary server to get CDRs back up and running!

Follow me on Twitter @kperryuc, [LinkedIn](https://www.linkedin.com/in/kperryuc/), drop a comment, or share the blog if you've found this useful!
