---
title: "Verify Trace Levels using SQL on Cisco UC"
layout: single
date: 2020-10-22T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - SQL
  - Cisco
  - Unified Communications
tags:
  - CUCM
  - CER
  - CUC
  - Cisco Unity
  - Cisco Unified Communications Manager
  - Callmanager
  - UC VOS
  - UC
  - Informix
  - SQL
  - UCCX
  - Unified Communications
  - Cisco UC
  - Cisco
---

## Elevated Traces are Risky

Hey there! I bet you’ve got experience troubleshooting issues in a UC VOS device, like CallManager, UCCX, CER or otherwise… and you’ve likely had to increase trace levels to Detailed because of a request from Cisco TAC or because you know that the detailed tracing is needed to diagnose the issue and see what’s causing it.<!--more--> And I bet you always lower those trace levels back to what they were when you started, right? Well… we might tell ourselves we do, but we’re all human and we all forget things from time to time.

<span class="image fit"><img src="{{ "/assets/images/verifytracelevels.png" | absolute_url }}" alt="Example output of the verification sql query." /></span>

And because we all forget things from time to time I think it’s a great idea to check our environment(s) to ensure that there aren’t any debugs running that aren’t needed, or increased trace levels where they aren’t needed. For me, it’s not an arbitrary thing… you see… in my younger years while troubleshooting an issue on an IM&P Cluster where presence statuses weren’t updating or displaying correctly, I elevated a few traces to Detailed level. One of which was the Cisco XCP Router process. Captured the issue in tracing, downloaded it locally but never set the trace levels back to their default level. This was on a Saturday afternoon. I don’t work Sunday… Monday… or Tuesday. And boy, was Monday morning fun for the folks working.

Now elevated trace levels aren’t inherently bad, but when you have a large company with thousands of users all attempting to log in to Jabber, set their statuses, and perform any number of tasks all at roughly the same time, you might see some adverse impact from those increased trace levels. For me, that adverse impact was an actual crash and hang of the CUCM nodes requiring a reboot from the hypervisor and trace levels to be lowered somewhere in that process before the system became overwhelmed again. I’m unsure of the specifics of the work performed that Monday morning, thankfully I did not have to deal with the fallout. I did, however, receive a phone call promptly upon logging in to the VPN and setting my phone up for my shift the Wednesday immediately following the issue.

You see, I like to joke sometimes with junior engineers about some of the processes they now have to follow (such as lowering trace levels to original values no longer being sage wisdom, but mandatory, necessary, and documented) are because I made a mistake. Now, it’s not as many as I say when joking around, but this was definitely something born of a lessons learned write-up following the RCA. So, yeah, it’s important.

And now we get to the meat of the post, how we can quickly validate trace levels across the cluster on a per node, per service basis. Of course navigating through the GUI as you traditionally would is far less efficient, but it does provide you the ability to modify the trace level and apply it to all nodes or individually. My SQL query is only a “what is it”, not a “make it so”. I use it to check what the levels are and confirm if I even need to log in to the GUI to make changes. Yes, you can update certain tables directly using SQL but unless I’m doing a lot of work and need to trim the time down, I usually don’t to avoid making mistakes in syntax or introducing issues poking around where I only half know what I’m doing (as I have said in a few posts, I am no SQL expert. I dabble.)

So to check, I would either send this as a SOAP request against the AXL API, or more commonly I would log in to the CUCM, UCCX, CER, CUC, IM&P Publisher and issue the following SQL query:

```text
run sql select ts.nameforcontrol as service, ttlg.name as trace_level, pns.enable, pns.servername from typeservice as ts, typetracelevelgrouping as ttlg, processnodeservice as pns where ts.enum=pns.tkservice and ttlg.tktracelevelgroups=ts.tktracelevelgroups and pns.tracelevel=ttlg.value
```

This query reports back the individual service names (e.g. Cisco CallManager, Cisco Extension Mobility, Cisco Extended Functions), the trace level (e.g. Detailed, Error, Significant, Informational), whether tracing is enabled at all (e.g. [t]rue, [f]alse), and what the name of the individual node is (e.g. labcucmpub, labcucmsub1, labcucmsub2). I normally take this output, slap it into Notepad++ and ctrl+f my way through the services I am concerned with, or the server I am concerned with, or I just review line by line if the need is there. 

Now we’ll see what the output looks like. Pretty quick, and in my eyes very handy to make sure all is in order when I am done troubleshooting, or even as a spot check if I see the common/logging partition filling quickly on a client environment, or think of a reason to audit this.

## Device Output from Single Node Cluster

```text
admin:run sql select ts.nameforcontrol as service, ttlg.name as trace_level, pns.enable, pns.servername from typeservice as ts, typetracelevelgrouping as ttlg, processnodeservice as pns where ts.enum=pns.tkservice and ttlg.tktracelevelgroups=ts.tktracelevelgroups and pns.tracelevel=ttlg.value
service                                           trace_level   enable servername
================================================= ============= ====== ==========
Cisco CallManager                                 Detailed      t      IPTBUCMPUB
Cisco Tftp                                        Error         t      IPTBUCMPUB
Cisco Messaging Interface                         Error         t      IPTBUCMPUB
Cisco IP Voice Media Streaming App                Detailed      t      IPTBUCMPUB
Cisco CTIManager                                  Detailed      t      IPTBUCMPUB
Cisco RIS Data Collector                          Significant   t      IPTBUCMPUB
Cisco Extension Mobility                          Informational t      IPTBUCMPUB
Aupair                                            Significant   t      IPTBUCMPUB
Cisco IP Manager Assistant                        Informational t      IPTBUCMPUB
Cisco Extended Functions                          Significant   t      IPTBUCMPUB
Cisco CTL Provider                                Error         t      IPTBUCMPUB
Cisco WebDialer Web Service                       Error         t      IPTBUCMPUB
Cisco Dialed Number Analyzer                      Informational t      IPTBUCMPUB
Cisco CDR Repository Manager                      Informational t      IPTBUCMPUB
Cisco CAPF                                        Error         t      IPTBUCMPUB
Cisco CDR Agent                                   Informational t      IPTBUCMPUB
Cisco CAR Scheduler                               Informational t      IPTBUCMPUB
Cisco CAR Web Service                             Informational t      IPTBUCMPUB
Cisco AMC Service                                 Informational t      IPTBUCMPUB
Cisco Log Partition Monitoring Tool               Significant   t      IPTBUCMPUB
Cisco CCM SNMP Service                            Significant   t      IPTBUCMPUB
Cisco DirSync                                     Informational t      IPTBUCMPUB
Cisco AXL Web Service                             Informational t      IPTBUCMPUB
Cisco DRF Master                                  Detailed      t      IPTBUCMPUB
Cisco DRF Local                                   Detailed      t      IPTBUCMPUB
Cisco CallManager Cisco IP Phone Services         Informational t      IPTBUCMPUB
Cisco CCMAdmin Web Service                        Informational t      IPTBUCMPUB
Cisco CCMRealm Web Service                        Informational t      IPTBUCMPUB
Cisco CCMService Web Service                      Informational t      IPTBUCMPUB
Cisco SOAP Web Service                            Informational t      IPTBUCMPUB
Cisco RTMT Web Service                            Informational t      IPTBUCMPUB
Cisco CCM PD Web Service                          Informational t      IPTBUCMPUB
Cisco CCM DBL Web Library                         Informational t      IPTBUCMPUB
Cisco CCM NCS Web Library                         Informational t      IPTBUCMPUB
Cisco Bulk Provisioning Service                   Informational t      IPTBUCMPUB
Cisco Extension Mobility Application              Informational t      IPTBUCMPUB
Cisco License Manager                             Informational t      IPTBUCMPUB
Cisco Role-based Security                         Informational t      IPTBUCMPUB
Cisco Trace Collection Service                    Informational t      IPTBUCMPUB
Cisco TVS                                         Error         t      IPTBUCMPUB
Cisco DHCP Monitor Service                        Informational t      IPTBUCMPUB
Cisco TAPS Service                                Informational t      IPTBUCMPUB
Cisco Tomcat                                      Informational t      IPTBUCMPUB
Cisco Unified OS Admin Web Service                Informational t      IPTBUCMPUB
Cisco GRT Communication Web Service               Informational t      IPTBUCMPUB
Cisco Unified Reporting Web Service               Informational t      IPTBUCMPUB
Cisco RisBean Library                             Informational t      IPTBUCMPUB
Cisco SOAPMessage Service                         Informational t      IPTBUCMPUB
Platform Administrative Web Service               Informational t      IPTBUCMPUB
Cisco Change Credential Application               Informational t      IPTBUCMPUB
Cisco CCMUser Web Service                         Informational t      IPTBUCMPUB
Cisco Audit Event Service                         Significant   t      IPTBUCMPUB
Cisco DP SOAP Web Service                         Informational t      IPTBUCMPUB
Cisco UXL Web Service                             Informational t      IPTBUCMPUB
Cisco Common User Interface                       Informational t      IPTBUCMPUB
Cisco User Data Services                          Informational t      IPTBUCMPUB
Cisco External Call Control Service               Informational t      IPTBUCMPUB
Cisco E911 Service                                Warning       t      IPTBUCMPUB
Cisco LBM                                         Detailed      t      IPTBUCMPUB
Cisco Dialed Number Analyzer Server               Arbitrary     t      IPTBUCMPUB
Cisco Unified Mobile Voice Access Service         Informational t      IPTBUCMPUB
Cisco Intercluster Lookup Service                 Significant   t      IPTBUCMPUB
Cisco Directory Number Alias Sync                 Informational t      IPTBUCMPUB
Cisco Directory Number Alias Lookup               Informational t      IPTBUCMPUB
Self Provisioning IVR                             Informational t      IPTBUCMPUB
Cisco CTLCli for moving cluster to secure mode    Fatal         t      IPTBUCMPUB
Cisco Certificate Change Notification Service     Detailed      t      IPTBUCMPUB
Cisco Wireless Controller Synchronization Service Informational t      IPTBUCMPUB
Cisco Smart License Manager                       Informational t      IPTBUCMPUB
Cisco Upgrade Agent Service                       Informational t      IPTBUCMPUB
Cisco Management Agent Service                    Informational t      IPTBUCMPUB
Cisco Push Notification Service                   Informational t      IPTBUCMPUB
Cisco Certificate Enrollment Service              Informational t      IPTBUCMPUB
Platform Communication Web Service                Informational t      IPTBUCMPUB
Cisco Device Activation Service                   Informational t      IPTBUCMPUB
```

## Device Output from Multi-Node Cluster

```text
admin:run sql select ts.nameforcontrol as service, ttlg.name as trace_level, pns.enable, pns.servername from typeservice as ts, typetracelevelgrouping as ttlg, processnodeservice as pns where ts.enum=pns.tkservice and ttlg.tktracelevelgroups=ts.tktracelevelgroups and pns.tracelevel=ttlg.value
service                                           trace_level   enable servername
================================================= ============= ====== ============
Cisco CallManager                                 Detailed      t      NHUCMPUBCL1
Cisco Tftp                                        Error         t      NHUCMPUBCL1
Cisco Messaging Interface                         Error         t      NHUCMPUBCL1
Cisco IP Voice Media Streaming App                Detailed      t      NHUCMPUBCL1
Cisco CTIManager                                  Detailed      t      NHUCMPUBCL1
Cisco RIS Data Collector                          Significant   t      NHUCMPUBCL1
Aupair                                            Significant   t      NHUCMPUBCL1
Cisco CAPF                                        Error         t      NHUCMPUBCL1
Cisco Log Partition Monitoring Tool               Significant   t      NHUCMPUBCL1
Cisco CCM SNMP Service                            Significant   t      NHUCMPUBCL1
Cisco TVS                                         Error         t      NHUCMPUBCL1
Cisco CCMUser Web Service                         Informational t      NHUCMPUBCL1
Cisco Audit Event Service                         Significant   t      NHUCMPUBCL1
Cisco DP SOAP Web Service                         Informational t      NHUCMPUBCL1
Cisco User Data Services                          Informational t      NHUCMPUBCL1
Cisco External Call Control Service               Informational t      NHUCMPUBCL1
Cisco E911 Service                                Warning       t      NHUCMPUBCL1
Cisco LBM                                         Detailed      t      NHUCMPUBCL1
Cisco Intercluster Lookup Service                 Significant   t      NHUCMPUBCL1
Cisco Directory Number Alias Sync                 Informational t      NHUCMPUBCL1
Cisco Directory Number Alias Lookup               Informational t      NHUCMPUBCL1
Self Provisioning IVR                             Informational t      NHUCMPUBCL1
Cisco CTLCli for moving cluster to secure mode    Fatal         t      NHUCMPUBCL1
Cisco Certificate Change Notification Service     Detailed      t      NHUCMPUBCL1
Cisco Wireless Controller Synchronization Service Informational t      NHUCMPUBCL1
Cisco Upgrade Agent Service                       Informational t      NHUCMPUBCL1
Cisco Management Agent Service                    Informational t      NHUCMPUBCL1
Cisco Push Notification Service                   Informational t      NHUCMPUBCL1
Cisco Extended Functions                          Significant   t      NHUCMPUBCL1
Cisco IP Manager Assistant                        Informational t      NHUCMPUBCL1
Cisco GRT Communication Web Service               Informational t      NHUCMPUBCL1
Cisco Unified Reporting Web Service               Informational t      NHUCMPUBCL1
Cisco Trace Collection Service                    Informational t      NHUCMPUBCL1
Cisco TAPS Service                                Informational t      NHUCMPUBCL1
Cisco SOAPMessage Service                         Informational t      NHUCMPUBCL1
Cisco License Manager                             Informational t      NHUCMPUBCL1
Platform Administrative Web Service               Informational t      NHUCMPUBCL1
Cisco DRF Master                                  Detailed      t      NHUCMPUBCL1
Cisco DRF Local                                   Detailed      t      NHUCMPUBCL1
Cisco Change Credential Application               Informational t      NHUCMPUBCL1
Cisco RisBean Library                             Informational t      NHUCMPUBCL1
Cisco Unified Mobile Voice Access Service         Informational t      NHUCMPUBCL1
Cisco CAR Scheduler                               Informational t      NHUCMPUBCL1
Cisco CCMRealm Web Service                        Informational t      NHUCMPUBCL1
Cisco AMC Service                                 Informational t      NHUCMPUBCL1
Cisco WebDialer Web Service                       Error         t      NHUCMPUBCL1
Cisco CDR Agent                                   Informational t      NHUCMPUBCL1
Cisco UXL Web Service                             Informational t      NHUCMPUBCL1
Cisco CDR Repository Manager                      Informational t      NHUCMPUBCL1
Cisco Role-based Security                         Detailed      t      NHUCMPUBCL1
Cisco CCMService Web Service                      Informational t      NHUCMPUBCL1
Cisco Common User Interface                       Informational t      NHUCMPUBCL1
Cisco CallManager Cisco IP Phone Services         Informational t      NHUCMPUBCL1
Cisco Extension Mobility Application              Informational t      NHUCMPUBCL1
Cisco CAR Web Service                             Informational t      NHUCMPUBCL1
Cisco DHCP Monitor Service                        Informational t      NHUCMPUBCL1
Cisco CCMAdmin Web Service                        Informational t      NHUCMPUBCL1
Cisco SOAP Web Service                            Informational t      NHUCMPUBCL1
Cisco Dialed Number Analyzer                      Informational t      NHUCMPUBCL1
Cisco Dialed Number Analyzer Server               Arbitrary     t      NHUCMPUBCL1
Cisco CTL Provider                                Error         t      NHUCMPUBCL1
Cisco Extension Mobility                          Informational t      NHUCMPUBCL1
Cisco Bulk Provisioning Service                   Informational t      NHUCMPUBCL1
Cisco RTMT Web Service                            Informational t      NHUCMPUBCL1
Cisco DirSync                                     Informational t      NHUCMPUBCL1
Cisco CCM PD Web Service                          Informational t      NHUCMPUBCL1
Cisco Unified OS Admin Web Service                Informational t      NHUCMPUBCL1
Cisco Tomcat                                      Informational t      NHUCMPUBCL1
Cisco CCM NCS Web Library                         Informational t      NHUCMPUBCL1
Cisco CCM DBL Web Library                         Informational t      NHUCMPUBCL1
Cisco AXL Web Service                             Informational t      NHUCMPUBCL1
Cisco CallManager                                 Detailed      t      NHUCMSUB1CL1
Cisco Tftp                                        Error         t      NHUCMSUB1CL1
Cisco Messaging Interface                         Error         t      NHUCMSUB1CL1
Cisco IP Voice Media Streaming App                Detailed      t      NHUCMSUB1CL1
Cisco CTIManager                                  Detailed      t      NHUCMSUB1CL1
Cisco RIS Data Collector                          Significant   t      NHUCMSUB1CL1
Aupair                                            Significant   t      NHUCMSUB1CL1
Cisco CAPF                                        Error         t      NHUCMSUB1CL1
Cisco Log Partition Monitoring Tool               Significant   t      NHUCMSUB1CL1
Cisco CCM SNMP Service                            Significant   t      NHUCMSUB1CL1
Cisco TVS                                         Error         t      NHUCMSUB1CL1
Cisco CCMUser Web Service                         Informational t      NHUCMSUB1CL1
Cisco Audit Event Service                         Significant   t      NHUCMSUB1CL1
Cisco DP SOAP Web Service                         Informational t      NHUCMSUB1CL1
Cisco User Data Services                          Informational t      NHUCMSUB1CL1
Cisco External Call Control Service               Informational t      NHUCMSUB1CL1
Cisco E911 Service                                Warning       t      NHUCMSUB1CL1
Cisco LBM                                         Detailed      t      NHUCMSUB1CL1
Cisco Intercluster Lookup Service                 Significant   t      NHUCMSUB1CL1
Cisco Directory Number Alias Sync                 Informational t      NHUCMSUB1CL1
Cisco Directory Number Alias Lookup               Informational t      NHUCMSUB1CL1
Self Provisioning IVR                             Informational t      NHUCMSUB1CL1
Cisco CTLCli for moving cluster to secure mode    Fatal         t      NHUCMSUB1CL1
Cisco Certificate Change Notification Service     Detailed      t      NHUCMSUB1CL1
Cisco Wireless Controller Synchronization Service Informational t      NHUCMSUB1CL1
Cisco Upgrade Agent Service                       Informational t      NHUCMSUB1CL1
Cisco Management Agent Service                    Informational t      NHUCMSUB1CL1
Cisco Push Notification Service                   Informational t      NHUCMSUB1CL1
Cisco Extended Functions                          Significant   t      NHUCMSUB1CL1
Cisco IP Manager Assistant                        Informational t      NHUCMSUB1CL1
Cisco GRT Communication Web Service               Informational t      NHUCMSUB1CL1
Cisco Unified Reporting Web Service               Informational t      NHUCMSUB1CL1
Cisco Trace Collection Service                    Informational t      NHUCMSUB1CL1
Cisco TAPS Service                                Informational t      NHUCMSUB1CL1
Cisco SOAPMessage Service                         Informational t      NHUCMSUB1CL1
Cisco License Manager                             Informational t      NHUCMSUB1CL1
Platform Administrative Web Service               Informational t      NHUCMSUB1CL1
Cisco DRF Master                                  Detailed      t      NHUCMSUB1CL1
Cisco DRF Local                                   Detailed      t      NHUCMSUB1CL1
Cisco Change Credential Application               Informational t      NHUCMSUB1CL1
Cisco RisBean Library                             Informational t      NHUCMSUB1CL1
Cisco Unified Mobile Voice Access Service         Informational t      NHUCMSUB1CL1
Cisco CAR Scheduler                               Informational t      NHUCMSUB1CL1
Cisco CCMRealm Web Service                        Informational t      NHUCMSUB1CL1
Cisco AMC Service                                 Informational t      NHUCMSUB1CL1
Cisco WebDialer Web Service                       Error         t      NHUCMSUB1CL1
Cisco CDR Agent                                   Informational t      NHUCMSUB1CL1
Cisco UXL Web Service                             Informational t      NHUCMSUB1CL1
Cisco CDR Repository Manager                      Informational t      NHUCMSUB1CL1
Cisco Role-based Security                         Informational t      NHUCMSUB1CL1
Cisco CCMService Web Service                      Informational t      NHUCMSUB1CL1
Cisco Common User Interface                       Informational t      NHUCMSUB1CL1
Cisco CallManager Cisco IP Phone Services         Informational t      NHUCMSUB1CL1
Cisco Extension Mobility Application              Informational t      NHUCMSUB1CL1
Cisco CAR Web Service                             Informational t      NHUCMSUB1CL1
Cisco DHCP Monitor Service                        Informational t      NHUCMSUB1CL1
Cisco CCMAdmin Web Service                        Informational t      NHUCMSUB1CL1
Cisco SOAP Web Service                            Informational t      NHUCMSUB1CL1
Cisco Dialed Number Analyzer                      Informational t      NHUCMSUB1CL1
Cisco Dialed Number Analyzer Server               Arbitrary     t      NHUCMSUB1CL1
Cisco CTL Provider                                Error         t      NHUCMSUB1CL1
Cisco Extension Mobility                          Informational t      NHUCMSUB1CL1
Cisco Bulk Provisioning Service                   Informational t      NHUCMSUB1CL1
Cisco RTMT Web Service                            Informational t      NHUCMSUB1CL1
Cisco DirSync                                     Informational t      NHUCMSUB1CL1
Cisco CCM PD Web Service                          Informational t      NHUCMSUB1CL1
Cisco Unified OS Admin Web Service                Informational t      NHUCMSUB1CL1
Cisco Tomcat                                      Informational t      NHUCMSUB1CL1
Cisco CCM NCS Web Library                         Informational t      NHUCMSUB1CL1
Cisco CCM DBL Web Library                         Informational t      NHUCMSUB1CL1
Cisco AXL Web Service                             Informational t      NHUCMSUB1CL1
Cisco CallManager                                 Detailed      t      NHUCMSUB2CL1
Cisco Tftp                                        Error         t      NHUCMSUB2CL1
Cisco Messaging Interface                         Error         t      NHUCMSUB2CL1
Cisco IP Voice Media Streaming App                Detailed      t      NHUCMSUB2CL1
Cisco CTIManager                                  Detailed      t      NHUCMSUB2CL1
Cisco RIS Data Collector                          Significant   t      NHUCMSUB2CL1
Aupair                                            Significant   t      NHUCMSUB2CL1
Cisco CAPF                                        Error         t      NHUCMSUB2CL1
Cisco Log Partition Monitoring Tool               Significant   t      NHUCMSUB2CL1
Cisco CCM SNMP Service                            Significant   t      NHUCMSUB2CL1
Cisco TVS                                         Error         t      NHUCMSUB2CL1
Cisco CCMUser Web Service                         Informational t      NHUCMSUB2CL1
Cisco Audit Event Service                         Significant   t      NHUCMSUB2CL1
Cisco DP SOAP Web Service                         Informational t      NHUCMSUB2CL1
Cisco User Data Services                          Informational t      NHUCMSUB2CL1
Cisco External Call Control Service               Informational t      NHUCMSUB2CL1
Cisco E911 Service                                Warning       t      NHUCMSUB2CL1
Cisco LBM                                         Detailed      t      NHUCMSUB2CL1
Cisco Intercluster Lookup Service                 Significant   t      NHUCMSUB2CL1
Cisco Directory Number Alias Sync                 Informational t      NHUCMSUB2CL1
Cisco Directory Number Alias Lookup               Informational t      NHUCMSUB2CL1
Self Provisioning IVR                             Informational t      NHUCMSUB2CL1
Cisco CTLCli for moving cluster to secure mode    Fatal         t      NHUCMSUB2CL1
Cisco Certificate Change Notification Service     Detailed      t      NHUCMSUB2CL1
Cisco Wireless Controller Synchronization Service Informational t      NHUCMSUB2CL1
Cisco Upgrade Agent Service                       Informational t      NHUCMSUB2CL1
Cisco Management Agent Service                    Informational t      NHUCMSUB2CL1
Cisco Push Notification Service                   Informational t      NHUCMSUB2CL1
Cisco Extended Functions                          Significant   t      NHUCMSUB2CL1
Cisco IP Manager Assistant                        Informational t      NHUCMSUB2CL1
Cisco GRT Communication Web Service               Informational t      NHUCMSUB2CL1
Cisco Unified Reporting Web Service               Informational t      NHUCMSUB2CL1
Cisco Trace Collection Service                    Informational t      NHUCMSUB2CL1
Cisco TAPS Service                                Informational t      NHUCMSUB2CL1
Cisco SOAPMessage Service                         Informational t      NHUCMSUB2CL1
Cisco License Manager                             Informational t      NHUCMSUB2CL1
Platform Administrative Web Service               Informational t      NHUCMSUB2CL1
Cisco DRF Master                                  Detailed      t      NHUCMSUB2CL1
Cisco DRF Local                                   Detailed      t      NHUCMSUB2CL1
Cisco Change Credential Application               Informational t      NHUCMSUB2CL1
Cisco RisBean Library                             Informational t      NHUCMSUB2CL1
Cisco Unified Mobile Voice Access Service         Informational t      NHUCMSUB2CL1
Cisco CAR Scheduler                               Informational t      NHUCMSUB2CL1
Cisco CCMRealm Web Service                        Informational t      NHUCMSUB2CL1
Cisco AMC Service                                 Informational t      NHUCMSUB2CL1
Cisco WebDialer Web Service                       Error         t      NHUCMSUB2CL1
Cisco CDR Agent                                   Informational t      NHUCMSUB2CL1
Cisco UXL Web Service                             Informational t      NHUCMSUB2CL1
Cisco CDR Repository Manager                      Informational t      NHUCMSUB2CL1
Cisco Role-based Security                         Informational t      NHUCMSUB2CL1
Cisco CCMService Web Service                      Informational t      NHUCMSUB2CL1
Cisco Common User Interface                       Informational t      NHUCMSUB2CL1
Cisco CallManager Cisco IP Phone Services         Informational t      NHUCMSUB2CL1
Cisco Extension Mobility Application              Informational t      NHUCMSUB2CL1
Cisco CAR Web Service                             Informational t      NHUCMSUB2CL1
Cisco DHCP Monitor Service                        Informational t      NHUCMSUB2CL1
Cisco CCMAdmin Web Service                        Informational t      NHUCMSUB2CL1
Cisco SOAP Web Service                            Informational t      NHUCMSUB2CL1
Cisco Dialed Number Analyzer                      Informational t      NHUCMSUB2CL1
Cisco Dialed Number Analyzer Server               Arbitrary     t      NHUCMSUB2CL1
Cisco CTL Provider                                Error         t      NHUCMSUB2CL1
Cisco Extension Mobility                          Informational t      NHUCMSUB2CL1
Cisco Bulk Provisioning Service                   Informational t      NHUCMSUB2CL1
Cisco RTMT Web Service                            Informational t      NHUCMSUB2CL1
Cisco DirSync                                     Informational t      NHUCMSUB2CL1
Cisco CCM PD Web Service                          Informational t      NHUCMSUB2CL1
Cisco Unified OS Admin Web Service                Informational t      NHUCMSUB2CL1
Cisco Tomcat                                      Informational t      NHUCMSUB2CL1
Cisco CCM NCS Web Library                         Informational t      NHUCMSUB2CL1
Cisco CCM DBL Web Library                         Informational t      NHUCMSUB2CL1
Cisco AXL Web Service                             Informational t      NHUCMSUB2CL1
Cisco RIS Data Collector                          Significant   t      NHIMP1CL1
Aupair                                            Significant   t      NHIMP1CL1
Cisco Log Partition Monitoring Tool               Significant   t      NHIMP1CL1
Cisco Audit Event Service                         Significant   t      NHIMP1CL1
Cisco Management Agent Service                    Informational t      NHIMP1CL1
Cisco GRT Communication Web Service               Informational t      NHIMP1CL1
Cisco Unified Reporting Web Service               Informational t      NHIMP1CL1
Cisco Trace Collection Service                    Informational t      NHIMP1CL1
Cisco SOAPMessage Service                         Informational t      NHIMP1CL1
Cisco Intercluster Sync Agent                     Informational t      NHIMP1CL1
Cisco IM and Presence Admin                       Informational t      NHIMP1CL1
Platform Administrative Web Service               Informational t      NHIMP1CL1
Cisco DRF Local                                   Detailed      t      NHIMP1CL1
Cisco Client Profile Agent                        Informational t      NHIMP1CL1
Cisco RisBean Library                             Informational t      NHIMP1CL1
Cisco ReplicationWatcher                          Informational t      NHIMP1CL1
Cisco Server Recovery Manager                     Informational t      NHIMP1CL1
Cisco OAM Agent                                   Error         t      NHIMP1CL1
Cisco Presence Engine                             Detailed      t      NHIMP1CL1
Cisco AMC Service                                 Informational t      NHIMP1CL1
Cisco XCP Router                                  Informational t      NHIMP1CL1
Cisco XCP Text Conference Manager                 Detailed      t      NHIMP1CL1
Cisco XCP Web Connection Manager                  Informational t      NHIMP1CL1
Cisco XCP Connection Manager                      Detailed      t      NHIMP1CL1
Cisco XCP SIP Federation Connection Manager       Informational t      NHIMP1CL1
Cisco XCP XMPP Federation Connection Manager      Informational t      NHIMP1CL1
Cisco XCP Message Archiver                        Informational t      NHIMP1CL1
Cisco XCP Directory Service                       Informational t      NHIMP1CL1
Cisco XCP Authentication Service                  Detailed      t      NHIMP1CL1
Cisco XCP File Transfer Manager                   Informational t      NHIMP1CL1
Cisco CCMService Web Service                      Informational t      NHIMP1CL1
Cisco XCP Config Manager                          Informational t      NHIMP1CL1
Cisco SIP Proxy                                   Detailed      t      NHIMP1CL1
Cisco SIP Proxy Logger                            Detailed      t      NHIMP1CL1
Cisco SOAP Web Service                            Informational t      NHIMP1CL1
Cisco Bulk Provisioning Service                   Informational t      NHIMP1CL1
Cisco RTMT Web Service                            Informational t      NHIMP1CL1
Cisco Presence Datastore                          Detailed      t      NHIMP1CL1
Cisco Login Datastore                             Detailed      t      NHIMP1CL1
Cisco Route Datastore                             Error         t      NHIMP1CL1
Cisco SIP Registration Datastore                  Error         t      NHIMP1CL1
Cisco Config Agent                                Detailed      t      NHIMP1CL1
Cisco Unified OS Admin Web Service                Informational t      NHIMP1CL1
Cisco Tomcat                                      Informational t      NHIMP1CL1
Cisco Sync Agent                                  Informational t      NHIMP1CL1
Cisco RCC Device Selection Service                Informational t      NHIMP1CL1
Cisco AXL Web Service                             Informational t      NHIMP1CL1
Cisco RIS Data Collector                          Significant   t      NHIMP2CL1
Aupair                                            Significant   t      NHIMP2CL1
Cisco Log Partition Monitoring Tool               Significant   t      NHIMP2CL1
Cisco Audit Event Service                         Significant   t      NHIMP2CL1
Cisco Management Agent Service                    Informational t      NHIMP2CL1
Cisco GRT Communication Web Service               Informational t      NHIMP2CL1
Cisco Unified Reporting Web Service               Informational t      NHIMP2CL1
Cisco Trace Collection Service                    Informational t      NHIMP2CL1
Cisco SOAPMessage Service                         Informational t      NHIMP2CL1
Cisco Intercluster Sync Agent                     Informational t      NHIMP2CL1
Cisco IM and Presence Admin                       Informational t      NHIMP2CL1
Platform Administrative Web Service               Informational t      NHIMP2CL1
Cisco DRF Local                                   Detailed      t      NHIMP2CL1
Cisco Client Profile Agent                        Informational t      NHIMP2CL1
Cisco RisBean Library                             Informational t      NHIMP2CL1
Cisco ReplicationWatcher                          Informational t      NHIMP2CL1
Cisco Server Recovery Manager                     Informational t      NHIMP2CL1
Cisco OAM Agent                                   Error         t      NHIMP2CL1
Cisco Presence Engine                             Detailed      t      NHIMP2CL1
Cisco AMC Service                                 Informational t      NHIMP2CL1
Cisco XCP Router                                  Informational t      NHIMP2CL1
Cisco XCP Text Conference Manager                 Detailed      t      NHIMP2CL1
Cisco XCP Web Connection Manager                  Informational t      NHIMP2CL1
Cisco XCP Connection Manager                      Detailed      t      NHIMP2CL1
Cisco XCP SIP Federation Connection Manager       Informational t      NHIMP2CL1
Cisco XCP XMPP Federation Connection Manager      Informational t      NHIMP2CL1
Cisco XCP Message Archiver                        Informational t      NHIMP2CL1
Cisco XCP Directory Service                       Informational t      NHIMP2CL1
Cisco XCP Authentication Service                  Detailed      t      NHIMP2CL1
Cisco XCP File Transfer Manager                   Informational t      NHIMP2CL1
Cisco CCMService Web Service                      Informational t      NHIMP2CL1
Cisco XCP Config Manager                          Informational t      NHIMP2CL1
Cisco SIP Proxy                                   Detailed      t      NHIMP2CL1
Cisco SIP Proxy Logger                            Detailed      t      NHIMP2CL1
Cisco SOAP Web Service                            Informational t      NHIMP2CL1
Cisco Bulk Provisioning Service                   Informational t      NHIMP2CL1
Cisco RTMT Web Service                            Informational t      NHIMP2CL1
Cisco Presence Datastore                          Detailed      t      NHIMP2CL1
Cisco Login Datastore                             Detailed      t      NHIMP2CL1
Cisco Route Datastore                             Error         t      NHIMP2CL1
Cisco SIP Registration Datastore                  Error         t      NHIMP2CL1
Cisco Config Agent                                Detailed      t      NHIMP2CL1
Cisco Unified OS Admin Web Service                Informational t      NHIMP2CL1
Cisco Tomcat                                      Informational t      NHIMP2CL1
Cisco Sync Agent                                  Informational t      NHIMP2CL1
Cisco RCC Device Selection Service                Informational t      NHIMP2CL1
Cisco AXL Web Service                             Informational t      NHIMP2CL1
admin:
```

Well, I hope this is helpful and that you’ve learned something, if not from the SQL query itself than from my personal story of crashing a client environment because 
I didn’t spend the 2 and a half minutes changing the trace levels back.
We’re all human, we all make mistakes, but I try not to make the same mistake more than once if I can help it.
Hopefully I can help you avoid making that mistake at all!