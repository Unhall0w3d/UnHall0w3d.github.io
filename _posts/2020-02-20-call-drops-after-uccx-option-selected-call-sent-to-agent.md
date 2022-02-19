---
title: "Call Drops On Agent Delivery"
date: 2020-02-20T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Contact Center
  - Cisco
tags:
  - UCCX
  - Cisco Callmanager
  - Cisco
  - Cisco UC
  - Call Manager
  - Contact Center Express
  - Contact Center
  - Traces
  - Unified Communications
  - Logs
  - Log Review
---

<head>
    <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-7351461893377144"
     crossorigin="anonymous">
     </script>
</head>

<span class="image fit"><img src="{{ "/assets/images/uccxcalldrop1.png" | absolute_url }}" alt="" /></span>

This one's a bit of a mess, and I'll provide some context that I did not have the benefit of knowing going into it. The issue was reported as "Calling XXX XXX XXXX and pressing Option 2 for French results in the call dropping." I was given the 800 number to call to replicate the issue, which was nice. No known date for the last time it worked, no known changes to the UCCX script or environment that would impact this particular call flow. I've heard this a few times.

<!--more-->

Now something I want you to understand is that working in a multitude of environments, and typically only for a few hours at a time, I do not have the ability to memorize every change that takes place for our clients. All of the changes performed  are of course tracked internally with indicents/cases that we can refer to for documentation, however, the client also makes their own changes, and at times also contracts other companies to perform work (site moves, SIP migrations, etc.) if they feel they can get a better deal or have existing contracts that they can leverage.

This is cool and all, but in this particular instance a big mistake was made during the clients migration to a centralized SIP provider architecture with two CUBEs and major SIP connections. Site routers that were previously used for DSP resources (MTP, XCODE, CFB) were decommissioned. USUALLY this is considered during the migration and one would account for the loss of these resources. Well... they didn't. The result is many branch site regions forcing 8kbps/g729 in their relationship with centralized resources, and UCCX (which requires 64kbps/g711ulaw). The transcoding resources previously available were now not available, and the only resource available from the child and default MRGLs had insufficient sessions configured causing the call to outright drop.

I've included the Cisco CallManager trace review below in which we track down the media negotiation (caps), regions at play, what MRGL/MRG and thus transcoding resources we have available, and the ultimate result of this call attempt.

## MTP allocation due to xcoder requirement

REMOTE-REG to UCCX-Region is hard coded 8kbps

```text
33308539.004 |14:42:53.465 |AppInfo  |DET-MediaManager-(252214)::buildMtpXcoderAllocList, savedConnectionCount=0, QosType=0
33308539.005 |14:42:53.465 |AppInfo  |DET-RegionsServer::matchCapabilities-- savedOption=3, PREF_NONE, regionA=(null) regionB=(null) latentCaps(A=0, B=0) kbps=8, capACount=5, capBCount=2
33308539.006 |14:42:53.465 |AppInfo  |DET-MediaManager-(252214)::checkAudioPassThru, param(bPostMTPAllocation=0,chkTrp=1), capCount(5,2), mtpPT=1, aPT=2
33308539.007 |14:42:53.465 |AppInfo  |DET-MediaManager-(252214)::preCheckCapabilities, region1=REMOTE-REG, region2=UCCX-Region, Pty1 capCount=5 (Cap,ptime)= (4,20) (11,20) (12,20) (112,20) (114,20), Pty2 capCount=2 (Cap,ptime)= (2,30) (4,30)
33308539.008 |14:42:53.465 |AppInfo  |DET-RegionsServer::matchCapabilities-- savedOption=0, PREF_NONE, regionA=(null) regionB=(null) latentCaps(A=0, B=0) kbps=8, capACount=5, capBCount=2
33308539.009 |14:42:53.465 |AppInfo  |RegionsServer: applyCodecFilterIfNeeded - no codecs remained after filtering so restored original 0 caps
```

## Caps mismatch, xcoder required

8kbps hard coded as mentioned. xCoder is required, xcoding side=2

```text
33308539.010 |14:42:53.465 |AppInfo  |DET-MediaManager-(252214)::preCheckCapabilities, caps mismatch! Xcoder Reqd. kbps(8), filtered A[capCount=3 (Cap,ptime)= (11,20) (12,20) (114,20)], B[capCount=0 (Cap,ptime)=] allowMTP=0 numXcoderRequired=1 xcodingSide=2
33308539.011 |14:42:53.465 |AppInfo  |DET-MediaManager-(252214)::prepareInitialConnectionList, Party1CapCount=5 Party2CapCount=2 XcoderRequired=1 xcodingSide=2 allowMTP=0
33308539.012 |14:42:53.465 |AppInfo  |DET-MediaManager-(252214)::AllocateXcoderandMTPWithZeroSavedConnection
33308539.013 |14:42:53.465 |AppInfo  |DET-MediaManager-(252214) - isIpv6CapableMTPNeeded(0) ipAddrMode(0 0) mtpside(0)
```

## MTP is required

```text
33308539.014 |14:42:53.465 |AppInfo  |DET-MediaManager-(252214)::isMTPNeededForMismatchOrConfig, MTPNeededDueToDTMFCapMismatch(2833/OOB) mtpinsertionReason=1 dtmfMTPSide=1
33308539.015 |14:42:53.465 |AppInfo  |DET-MediaManager-(252214)::isMTPNeededForDTMF, isMTPNeeded for DTMF inection from OOB to 2833 party1MTPNeed=0 party1MTPNeed=0 mtpinsertionReason=1
33308539.016 |14:42:53.465 |AppInfo  |DET-MediaManager-(252214)::isMTPNeededForDTMFInjectionFromOOBTo2833 - MTPInsertionReason=1 DTMFSide=1 Party1XferMode=16 Party2XferMode=4 Party 1[DTMFConfig=1 DTMFMethod=2 wantDTMFReception=1 DTMFReception=0 MTPNeedForDTMFInject=0] Party 2[DTMFConfig=1 DTMFMethod=1 wantDTMFReception=1 DTMFReception=0 MTPNeedForDTMFInject=0]
33308539.017 |14:42:53.465 |AppInfo  |!!ERROR!! -MediaManager-(252214)::isMTPNeededForDTMFInjectionFromOOBTo2833 DTMFMTPSide=1, MTPInsertReason=1
33308539.018 |14:42:53.465 |AppInfo  |DET-MediaManager-(252214)::isMTPNeededForDTMF, after all MTP determinationMTPSide=1 mtpinsertionReason=1
```

## CCM compares device caps between affected regions for MTP/Xcoder and REMOTE region (Side A --> MTP) 8kbps

```text
33308546.001 |14:42:53.466 |AppInfo  |MediaTerminationPointControl(7)::waiting_AllocateMtpResourceReq - (capCount,region),A(5,REMOTE-REG),B(2,UCCX-Region), reqDevCap=0x9, reqMandatoryCaps=0x0, supDevCap=0x129, passthru=0, resourceCount=1
33308546.002 |14:42:53.466 |AppInfo  |MediaTerminationPointControl(7)::getResourcesAllocated -- DeviceName=XCODE_HLSD_ISR Ci=42684271 ResourceCount=1
33308546.003 |14:42:53.466 |AppInfo  |MediaTerminationPointControl(7)::getResourcesAllocated -- Logging RegionA=REMOTE-REG Caps and MTP/XCoder Region=HLSD-Region Caps
33308546.004 |14:42:53.466 |AppInfo  |MediaTerminationPointControl(7)::logCapabilitiesinTrace -- MTP/XCoder Device Caps = 4 2 12 16 257 259 261
33308546.005 |14:42:53.466 |AppInfo  |MediaTerminationPointControl(7)::logCapabilitiesinTrace -- Device Caps = 4 11 12 112 114
33308546.006 |14:42:53.466 |AppInfo  |DET-RegionsServer::matchCapabilities-- savedOption=0, PREF_LIST, regionA=HLSD-Region regionB=REMOTE-REG latentCaps(A=0, B=0) kbps=8, capACount=7, capBCount=5
```

## CCM then compares device caps between affected regions for MTP/Xcoder and UCCX region (MTP --> Side B) 64kbps

```text
33308546.007 |14:42:53.466 |AppInfo  |MediaTerminationPointControl(7)::getResourcesAllocated -- Logging RegionB=UCCX-Region Caps and MTP/XCoder Region=HLSD-Region Caps
33308546.008 |14:42:53.466 |AppInfo  |MediaTerminationPointControl(7)::logCapabilitiesinTrace -- MTP/XCoder Device Caps = 4 2 12 16 257 259 261
33308546.009 |14:42:53.466 |AppInfo  |MediaTerminationPointControl(7)::logCapabilitiesinTrace -- Device Caps = 2 4
33308546.010 |14:42:53.466 |AppInfo  |DET-RegionsServer::matchCapabilities-- savedOption=0, PREF_LIST, regionA=HLSD-Region regionB=UCCX-Region latentCaps(A=0, B=0) kbps=64, capACount=7, capBCount=2
```

## We attempt to create a list of XCODERS to use

XCODE_NROC_4351 is pulled from the MRG-NROC-Hardware:MRG-NROC-Software. It is unregistered, thus, cannot be allocated

```text
33308540.002 |14:42:53.466 |AppInfo  |MediaResourceManager::waiting_MrmAllocateXcoderResourceReq - CREATING CHILD USING MRGL LIST
33308540.003 |14:42:53.466 |AppInfo  |MRM::convertScmStringToStdString MRG-NROC-Hardware:MRG-NROC-Software 
33308540.004 |14:42:53.466 |AppInfo  |MRM::getXcodeDeviceGivenMrgl
33308540.005 |14:42:53.466 |AppInfo  |MRM::getXcodeDeviceGivenMrgl DeviceName=XCODE_NROC_4351 DeviceType=112 Group=0 Counter=0 Capability=0 MultiCast=0 MRGL=4196c76d-f834-8583-1df2-87314cfa78eb
```

## CCM then reviews default list (xCoders not assigned to MRG)

Only XCODE_HLSD_ISR is registered, thus, it is used

33308540.006 |14:42:53.466 |AppInfo  |MRM::getXcodeDeviceGivenMrgl GETTING XCODE FROM DEFAULT LIST
33308540.007 |14:42:53.466 |AppInfo  |MRM::getXcodeDeviceGivenMrgl DeviceName=XCD-LDN DeviceType=111 Group=2 Counter=0 Capability=0 MultiCast=0 MRGL=4196c76d-f834-8583-1df2-87314cfa78eb
33308540.008 |14:42:53.466 |AppInfo  |MRM::getXcodeDeviceGivenMrgl DeviceName=XCODE_CWUT_2821 DeviceType=112 Group=2 Counter=0 Capability=0 MultiCast=0 MRGL=4196c76d-f834-8583-1df2-87314cfa78eb
33308540.009 |14:42:53.466 |AppInfo  |MRM::getXcodeDeviceGivenMrgl DeviceName=XCODE_HLSD_ISR DeviceType=112 Group=2 Counter=0 Capability=0 MultiCast=0 MRGL=4196c76d-f834-8583-1df2-87314cfa78eb
33308540.010 |14:42:53.466 |AppInfo  |MediaResourceManager::waiting_MrmAllocateXcoderResourceReq - CREATED CHILD USING MRGL AND DEFAULT LIST33308540.011 |14:42:53.466 |AppInfo  |MediaResourceCdpc(0)::createTempDeviceTable - Entries copied in the Temp Device Table = 4
33308540.012 |14:42:53.466 |Create |MediaResourceCdpc(2,100,139,128507)|MediaResourceManager(2,100,138,)|NumOfCurrentInstances: 1
33308541.000 |14:42:53.466 |SdlSig |Start |start |MediaResourceCdpc(2,100,139,128507)|MediaResourceCdpc(2,100,139,128507) |1,200,13,55.213935^IPADDRESS^CTIP_7148047 |*TraceFlagOverrode
33308541.001 |14:42:53.466 |LnkState |LinkAdmin - registerLinkStatus - Pid: [2,139,128507], NodeId: 1 regCount: 1
33308541.002 |14:42:53.466 |AppInfo  |MediaResourceCdpc(128507) - Started
33308542.000 |14:42:53.466 |SdlSig   |MrmAllocateMtpResourceReq              |waiting                        |MediaResourceCdpc(2,100,139,128507) |MediaResourceManager(2,100,138,1) |1,200,13,55.213935^IPADDRESS^CTIP_7148047 |[R:N-H:0,N:1,L:0,V:0,Z:0,D:0]  CI=42684271 MRGLPkid=4196c76d-f834-8583-1df2-87314cfa78eb Kpbs=0 RegionA=REMOTE-REG CapA=5 RegionB=UCCX-Region CapB=2 SuppressFlag=0 DeviceCapReqd= [0x9 DETECT_2833 PT_2833] MandatoryCapabilities= [0x0] Type=3 Count=1 MTPRequired=F tryPassThru=F
33308542.001 |14:42:53.466 |AppInfo  |MediaResourceCdpc(128507)::waiting_MrmAllocateMtpResourceReq - CI=42684271 Count=1 TryPassThru=0

## Process id request is performed by CCM

No PID is found for any xcode resource except XCODE_HLSD_ISR, indicating they are not registered

```text
33308543.000 |14:42:53.466 |SdlSig   |DmMultiPidReq                          |initialized                    |DeviceManager(2,100,205,1)       |MediaResourceCdpc(2,100,139,128507) |1,200,13,55.213935^IPADDRESS^CTIP_7148047 |[T:N-H:0,N:0,L:0,V:0,Z:0,D:0]  Id=18036 Cepn=85589cf7-919d-42c6-d071-3b1dde989d87    Cepn=44428b40-4493-aab8-a7d4-46f9a0017077    Cepn=7276bed3-e1fe-e1f9-416a-6691875ea813    Cepn=c32bf383-9983-671c-38b3-1d88ce5a94c1
33308543.001 |14:42:53.466 |AppInfo  |DeviceManager::star_DmMultiPidReq - PID(s) Requested=4
33308543.002 |14:42:53.466 |AppInfo  |SMDMSharedData::findAliasRegInfo - AliasName = 85589cf7-919d-42c6-d071-3b1dde989d87 not in AliasInfo hashmap
33308543.003 |14:42:53.466 |AppInfo  |SMDMSharedData::findRemoteDeviceAny - Key=85589cf7-919d-42c6-d071-3b1dde989d87 not in RemoteDeviceInfo hashmap
33308543.004 |14:42:53.466 |AppInfo  |SMDMSharedData::findAliasRegInfo - AliasName = 44428b40-4493-aab8-a7d4-46f9a0017077 not in AliasInfo hashmap
33308543.005 |14:42:53.466 |AppInfo  |SMDMSharedData::findRemoteDeviceAny - Key=44428b40-4493-aab8-a7d4-46f9a0017077 not in RemoteDeviceInfo hashmap
33308543.006 |14:42:53.466 |AppInfo  |SMDMSharedData::findAliasRegInfo - AliasName = 7276bed3-e1fe-e1f9-416a-6691875ea813 not in AliasInfo hashmap
33308543.007 |14:42:53.466 |AppInfo  |SMDMSharedData::findRemoteDeviceAny - Key=7276bed3-e1fe-e1f9-416a-6691875ea813 not in RemoteDeviceInfo hashmap
33308543.008 |14:42:53.466 |AppInfo  |SMDMSharedData::findAliasRegInfo - AliasName = c32bf383-9983-671c-38b3-1d88ce5a94c1 not in AliasInfo hashmap
33308543.009 |14:42:53.466 |AppInfo  |SMDMSharedData::findLocalDevice - Name=XCODE_HLSD_ISR Key=c32bf383-9983-671c-38b3-1d88ce5a94c1 isActvie=1 Pid=(2,137,7) found
```

## XCODE_HLSD_ISR is selected as the assigned resource

Resource indicates MTP usage (1) is >= 95% of total resources (2) -  Allocation fails

```text
33308546.011 |14:42:53.466 |AppInfo  |MediaTerminationPointControl(7)::getResourcesAllocated -- match1=1 match2=2
33308546.012 |14:42:53.466 |AppInfo  |MediaTerminationPointControl(7)::getResourcesAllocated -- DeviceName=XCODE_HLSD_ISR Ci=42684271 ResourceAllocated=1
33308546.013 |14:42:53.466 |AppInfo  |MediaTerminationPointControl(7)::getResourcesAllocated -- allocateErrBitset=0x0
33308546.014 |14:42:53.466 |AppInfo  |MediaTerminationPointControl(7)::waiting_AllocateMtpResourceReq - MTP usage (1) >= configured throttle percent (95) of Total Resources (2). Attempt to allocate a different MTP.
33308546.015 |14:42:53.467 |AppInfo  |MediaTerminationPointControl(7)::incRequestsThrottledCounter Count=1
33308546.016 |14:42:53.467 |AppInfo  |MediaTerminationPointControl(7)::SendMTPResourceErrToSender - ERROR  AllocateMtpResourceReq failed -- Ci=42684271, errBitset=0x2
```

## Registration state of XCODERS involved in call flow

```text
Cisco IOS Enhanced Media Termination Point  XCODE_NROC_4351 XCODE_NROC_4351 DP-NROC None    None    Copy
Cisco IOS Media Termination Point   XCD-LDN LDN Hardware XCD    DP-LNNH None    None
Cisco IOS Enhanced Media Termination Point  XCODE_CWUT_2821 XCODE_CWUT_2821 DP-CWUT None    None
Cisco IOS Enhanced Media Termination Point     XCODE_HLSD_ISR   HLSD XCODE ISR  DP-HLSD Registered with callmanager x.x.x.x
```

## Due to lack of MTP/XCoder available after hitting the threshold on XCODE_HLSD_ISR, the call fails/drops

GW Config shows 'session 2' command issued on transcoder profile indicating we have very few sessions available for transcoding resources.

```text
ITSACUBE01#show run | sec profile
!irrelevant configurations omitted
associate profile 2 register XCODE_HLSD_ISR
dspfarm profile 2 transcode
codec g729abr8
codec g729ar8
codec g711alaw
codec g711ulaw
maximum sessions 2
associate application SCCP
!irrelevant configurations omitted
```

Now after review we've identified that there is a mismatch in caps (8kbps/g729 for the remote region, 64kbps/g711ulaw for UCCX region) and insufficient transcoding resources to handle this. There are some options we do have to fix this.

## Solution #1

Increase maximum sessions available on transcoding resources on ITSACUBE01 to allow XCODE_HLSD_ISR Transcoding resource to handle the call. 
    This would also require adding the g729r8 codec, as it's not listed as an available codec to transcode.

```text
conf t
dspfarm profile 2 transcode
codec g729r8
maximum sessions 20
end
copy run start
conf t
no sccp
sccp
```

We add g729r8 as an available codec, we increase the sessions (we can select 20 due to the particular gateway having a lot of DSP resources that are [for some reason] unused. This will require DSP calculations on your end depending on what you have available in terms of pvdm type and size). We also bounce SCCP for good measure to get it to re-register.

## Solution #2 

Open up the region relationship between REMOTE-REG and UCCX-REG to allow 64kbps both ways.

```text
Navigate to CM Administration > System > Region Information > Region
Blank Search
Select UCCX-REG
Modify relationship with REMOTE-REG to allow 64kbps, if on default. If already 64kbps, make no change.
Back to Find/List
Select REMOTE-REG
Modify relationship with UCCX-REG to allow 64kbps, if on default or statically assigned to a lower bandwidth value (in this case 8kbps).
Save
Apply Config
```

64kbps per call is allowed in terms of codecs that can be used, which allows g711ulaw to be directly negotiated and cuts out the requirement of transcoding resources. This requires sufficient bandwidth between the UCCX servers and the remote site, as RTP is endpoint-to-endpoint (phone to UCCX//phone to agent).

For the short term we ended up going with Option 2, due to sufficient bandwidth and in order to cut out transcoding in the first place. We have a plan to go back and revisit the available Media Resources, clean up/delete those that aren't coming back, and to appropriately configure those remaining.

Hopefully this was interesting and helped break down in the signaling/traces the steps CCM goes through to determine if it needs to transcode, and if so, how it pulls those resources. Have any ideas for future posts? Feedback on any of my past posts? Just want to chat about UC? Reach out to my Twitter (@thoughtsnoc) or find me on LinkedIn!
