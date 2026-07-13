---
title: "Pulling Device Defaults Like A Pro"
layout: single
classes: wide
date: 2019-06-21T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Unified Communications
  - Cisco
  - SQL
tags:
  - Cisco Unified Communications Manager
  - Cisco
  - Database
  - Unified Communications
---

## What Is Our Mission

To pull a list of device defaults (like the Device > Device Defaults GUI page) to gather the device default firmware for a set of phones. In this case we are specifically pulling the device defaults only for phones where the count > 0). I do this for two reasons:

<!--more-->

I don't need the device default data for devices that are not configured in the cluster.

To add context: typically when we upgrade CUCM versions (for example 10.5.2 base image to 10.5.2SU8) the phone firmwares will upgrade. Some clients do not want to upgrade their firmwares and want to revert to the original values "pre-upgrade". This list is useful in providing the device defaults so we have a reference to revert, and even better, we only need to revert it for phones that we actually use. This leaves us with less work to perform and increases our efficiency!

## Relevant Data/Attributes and Tables

As with many of the queries I run, I like to define the attributes I am pulling from the Informix DB to be easier to understand and so that the data can be conveyed to a client, architect, whoever without much/any modification or manipulation. In this case we are dealing with the following attributes and tables:

### Attributes

The tkmodel values within the device, typeproduct and defaults tables are used to correlate and pull data relating to the phone model type.

```text
d.tkmodel
tp.tkmodel
defaults.tkmodel
```

The tkdeviceprotocol and loadinformation values from the defaults table are used to determine the device protocol (11=SIP, 0=SCCP, 99=Media Resource) and assigned default firmware for the phone type. Note; this will deviate between SCCP and SIP, that is why we care what protocol identifier is associated with the load ID. We will see in the "name" field that we get a phone type (e.g. Cisco 8851) but there is no differentiation between SCCP and SIP within the name.

```text
defaults.tk
deviceprotocol
defaults.loadinformation
```

The name value within the device and typeproduct tables is used to grab and associate the actual name for the device associated with the default. This is where we differentiate between a Cisco DX650 and a Cisco ATA.

```text
d.name
tp.name
```

### Tables

```text
device
typeproduct
defaults
```

### Conditions

d.name like '%' (this allows us to search for any device, not just SEP phones but also media resources, telepresence/video endpoints, etc.)defaults.loadinformation !="" (this tells us that we don't want to pull any information if the device defaults is blank.)

## Query

```text
run sql select count(d.tkmodel), tp.name, defaults.tkdeviceprotocol as SignalingProtocol, defaults.loadinformation as DeviceDefault, d.tkmodel as tkmodel from device as d INNER JOIN typeproduct as tp on d.tkmodel=tp.tkmodel INNER JOIN defaults as defaults on tp.tkmodel=defaults.tkmodel where d.name like '%' and defaults.loadinformation != "" group by d.tkmodel, tp.name, defaults.loadinformation, defaults.tkdeviceprotocol
```

### Client Ask/Scenario:
It's upgrade time. 10.5.2SU8 just gets released (let's pretend) and it fixes all the bugs you're encountering in your 10.5.2 base image/installation. As we're discussing with a client or our internal MIS teams we determine that we don't want to perform blanket phone upgrades as they're not comfortable with having so many phones upgrade simultaneously. Instead, the client wants to revert the device defaults to their pre-change values and manually upgrade phones/test the firmware at another time. No problem! Let's just take a screenshot... or two... or three... of the device defaults page, right? And revert all of the values... oh boy. Isn't there a better way to do this? YES! There is! This query will pull exactly what we need to satisfy this portion of the change quickly and easily. When it does come time to upgrade the firmwares, any stragglers that have static phone loads can be identified using the [Query In My Other Post](https://www.nocthoughts.com/2019/06/21/identifying-static-phone-loads.html).

### Return

As you can see in the below output, we're able to pull a few things:

1. Count. How many devices OF THIS TYPE do we have configured. This helps us identify impact to a specific firmware load being changed.
2. What protocols are we concerned with. SIP? SCCP? Both?
3. What the actual load value is, as shown in the Device > Device Defaults page
4. What is the name of the phone type. Is this a DX80? An ATA? A 7960?

```text
run sql select count(d.tkmodel), tp.name, defaults.tkdeviceprotocol as SignalingProtocol, defaults.loadinformation as DeviceDefault, d.tkmodel as tkmodel from device as d INNER JOIN TypeProduct as tp on d.tkmodel=tp.tkmodel INNER JOIN defaults as defaults on tp.tkmodel=defaults.tkmodel where d.name like '%' and defaults.loadinformation != "" group by d.tkmodel, tp.name, defaults.loadinformation, defaults.tkdeviceprotoco

(count) name          signalingprotocol devicedefault       tkmodel
======= ============= ================= =================== =======
20      Cisco 8841                             11               sip88xx.12-1-1SR1-4        683
137     Cisco 8851                             11               sip88xx.12-1-1SR1-4        684
50      Cisco 7960                             0                P0030801SR02               7
391     Cisco 7962                             11               SIP42.9-4-2SR3-1S          404
2       Cisco IOS Media Termination Point      99               M00104000006               111
2       Cisco TelePresence EX60                11               s52000tc7_3_12.pkg         604
4       Cisco DX650                            11               sipdx650.10-2-3-33         647
1       Cisco IOS Conference Bridge            99               C00104000003               51
2       Cisco Media Termination Point Hardware 99               M00104000006               111
1       Cisco ATA 191                          11               ATA191.12-0-1-29           36262
1       Cisco Conference Bridge Hardware       99               C00104000003               51
2       Cisco TelePresence DX80                11               sipdx80.ce915.291117.loads 36239
```

## Now What

Now, what I'd do with this information is tuck it away in a .txt file, or bundled up in a ZIP with other screenshots/data I may pull prior to the upgrade in order to compare with the post-upgrade values. I can quickly access the Device Defaults page while I am checking SIP trunk statuses and other information in the GUI, copy/paste the load names back in, save, and bam! We're done! As mentioned this is but a small part of the steps I take and information I pull pre-and-post upgrade. Speaking of post-upgrade, you can run this command again after you've reverted the values and ensure (double, triple check!) that the values did in fact get reverted and saved to the DB.

That's it for now! Make sure to follow the blog to get alerts on new posts, check out my Twitter (@kperryuc) where you can also ask UC and DC related questions, suggest post topics, or talk about anything!
