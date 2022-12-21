---
title: "Jabber Video Calling SQL Query"
layout: single
classes: wide
date: 2020-04-07T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - SQL
  - Unified Communications
  - Cisco
tags:
  - Cisco Unified Communications Manager
  - Cisco
  - Cisco Jabber
  - Reports
  - Unified Communications
  - Telepresence
  - Database
---
## We Need To Know If Video Calling Is Enabled

Another day, another query. This time the request was not up for interpretation in terms of 'Can you pull this kind of data from CUCM?' where I can take a look at what might provide the most useful, actionable data relating to what was asked for... no. 

<!--more-->

This time we get a screenshot of the Product Specific Configuration Layout element of "Video Calling" (see below). We're able to do this but it's not as straight forward as a typical query against the 'device' table for an attribute like the 'description' of a phone.

<span class="image fit"><img src="{{ "/assets/images/videocalling1.png" | absolute_url }}" alt="Product Specific Configuration Layout element depicting whether Video Calling is Enabled or Disabled - CUCM Device > Phone" /></span>
Product Specific Configuration Layout element depicting whether Video Calling is Enabled or Disabled - CUCM Device > Phone

The request comes in as "Would you please check if a report can be created for all Asia region users (CSFxxxxxx) that have this Video Calling option "Enabled"? The attachment accompanied the request. Immediately I think of what attributes I need to pull based on the request, which I now, and which I don't know. So we'll have the name (device name) and description (device description) from the Device table. That's a given. The next is to think about where the Video Calling "Product Specific Configuration Layout" is held. For this I performed a "run sql select * from device" presuming the data to be stored there. It's not.

And to save others the explanation and walk through of my hour to an hour and a half of research and poking around, it was found that the attribute of "Video Calling" in the Product Specific Configuration Layout section on the CSF (CUCM Administration > Device > Phone) is held in an xml file that is specific to the phone/device. The location is within the devicexml4k table (as d4k) as the xml attribute. In a query we would pull the name, description from device and inner join the devicexml4k table on the device foreign key (fkdevice) where it is equal to the pkid on the device table. Additionally I thought to limit the output to where device names are like CSF*. I'll provide screencaps for the output.

## The Query

```text
run sql select d.name, d.description, d4k.xml from device as d inner join devicexml4k as d4k on d4k.fkdevice=d.pkid where d.name like 'CSF%'
```

## The Output

<span class="image fit"><img src="{{ "/assets/images/videocalling2.png" | absolute_url }}" alt="Relevant attribute within XML is <videoCapability></videoCapability>" /></span>

<span class="image fit"><img src="{{ "/assets/images/videocalling3.png" | absolute_url }}" alt="Relevant attribute within XML is <videoCapability></videoCapability>" /></span>

This provides us the entire XML contents for the given device, whether they contain the exact attribute we want to find or not. Turns out that attribute is <videoCapability></videoCapability>. Valid entries are 0, or 1. You can see how we'd modify the query from here... but I'd like to cover a few caveats before we do this.

## Caveats and Notes

1. We are unable to simply pull the attribute requested for video capabilities from CUCM Informix DB as the “Product Specific” attributes are held in device specific xml files, so it requires some manual manipulation to determine what this setting is set to.
2. The XML File does not contain the value for a given Product Specific attribute UNTIL it is manually set.
3. If the default is in use and the setting has never been manually changed, it will not populate in the xml file.
4. If the default value is not in use and the setting has been manually changed, it will populate in the xml file.
5. If the default value is in use and the setting has been manually changed, it will still populate in the xml file.
6. The manual setting applied under Product Specific Configuration Layout (shown below) only takes effect if the checkbox for “Override Enterprise/Common Phone Profile Settings” is checked, otherwise the Common Phone Profile/Enterprise setting is used.
7. We are unable to isolate a specific value in the SQL Database to confirm if this setting is enabled or disabled. (the Override Enterprise/Common Profile Settings) button. This was an issue brought up on previous data pulls of this nature and is something we cannot overcome.
8. In my case there is only one Common Phone Profile on the system, and it has Video Calling set to enabled. Unless a user phone has the Product Specific video calling setting set to “Disabled” AND the “Override Enterprise/Common Phone Profile” checkbox ticked the result is that they have video calling enabled.
9. In your environment you'll want to check the Common Phone Profile relevant to the device(s) that you're checking, if that means 12 different ones, you gotta check them. Confirm if Video Calling is Enabled or Disabled, and use that as your initial rule-of-thumb on what devices have it enabled.
10. From there, utilize the SQL query provided in this post to isolate devices that have been manually modified to product a <videoCapability></videoCapability> entry in their XML file. We'll look for "0" to see that it's been disabled.
11. Utilize Excel or similar to "diff" and compare enabled phones vs manually disabled phones to produce your "final" list of devices with Video Calling enabled. If you think of a better way to organize this, do what's comfortable or what works for you.

That was a bit to explain, and we'll put it into practical use now. So the method I chose to employ to provide as much data as possible while also making it as clear as possible was to pull 3 sets of data. One that pulls ALL CSF devices (Worksheet 1 in Excel), their names, description, and XML contents. All of these devices utilize the same Common Device Profile where Video Calling was enabled.

## The Query... Again. So Nice, I Provide It Twice

```text
run sql select d.name, d.description, d4k.xml from device as d inner join devicexml4k as d4k on d4k.fkdevice=d.pkid where d.name like 'CSF%'
```

My second query was to isolate users with the option manually enabled. This would indicate that the option to enable Video Calling was manually set rather than inherited from the Common Device Profile. Note though that it's still enabled... some where, some how, some way. We qualify this with an additional 'and d4k.xml like '%<videoCapability>1</videoCapability>%' in order to capture the XML contents where video is enabled. The % % are required to represent a wildcard and allow XML files that have additional contents leading or trailing the option we're looking for. This is my Worksheet 2 in Excel.

## Altered Query -- Filtering for "Video Capability" = 1

```text
run sql select d.name, d.description, d4k.xml from device as d inner join devicexml4k as d4k on d4k.fkdevice=d.pkid where d.name like 'CSF%' and d4k.xml like '%<videoCapability>1</videoCapability>%'
```

## Altered Query -- Output

The output provides all user devices (CSF/Jabber) where Video Calling is enabled via Product Specific Layout, indicating manual enablement.
<span class="image fit"><img src="{{ "/assets/images/videocalling4.png" | absolute_url }}" alt="The output provides all user devices (CSF/Jabber) where Video Calling is enabled via Product Specific Layout, indicating manual enablement." /></span>

Now that we know what devices have been enabled manually, we can parse for the devices that have it disabled manually. To do this we need to edit our '1' to a '0'. Remember our caveat, if the user has the Product Specific Layout option for Video Calling set to '0' (disabled) but they do not check the option to override the Common Phone Profile, it won't apply. This is akin to a 'best effort' or 'as best as we can get' query. This is my Worksheet 3 in Excel

The output provides all user devices (CSF/Jabber) where Video Calling is disabled via Product Specific Layout, indicating manual disablement.
<span class="image fit"><img src="{{ "/assets/images/videocalling5.png" | absolute_url }}" alt="The output provides all user devices (CSF/Jabber) where Video Calling is disabled via Product Specific Layout, indicating manual disablement." /></span>

Where do we go from here? Well, what I chose to do as explained previously is to translate this data (copy + paste) to Excel, Worksheet 1 being the "All users" pull, Worksheet 2 being the "Manually Enabled Users" pull, and Worksheet 3 being the "Manually Disabled Users" pull. Once the data is posted into Excel we select Column A and use the "Data" Ribbon tab to find the "Text to Columns" option. We then set the Text to Columns to match our data type - Delimited or Fixed Width, and sort all three worksheets so the attributes are in cell columns matching their type - Name, Description, XML.

Now, you'll need to know a little about Excel as I'm not going to go over step-by-step how I formatted the data and displayed things... primarily because we all have our own ways of doing it and I know FOR SURE that this was not the best way to present the data... the trouble is primarily in being the 'data pull' guy, and not the 'data manipulation' guy. I can make a report, I can try (and fail my first few attempts) at making a pretty report. :)

Here we go, on Worksheet 1 where we have all users I utilizes the UNUSED Column D, and Column E to sort highlight in Column A the users that have it manually enabled (green), manually disabled (red) or enabled by Common Phone Profile (white). The total pool of users that have it enabled are White + Green. Confusing? Maybe. Like I said, I don't make pretty reports...

## Excel Fromatting and Formulas

Column D (Manually Disabled) has the following formula along the entire column

```text
=VLOOKUP(A3,'CSF Video Disabled Manually'!$A$3:$A$388,1,FALSE)
```

Column E (Manually Enabled) has the following formula along the entire column  

```text
=VLOOKUP(A3,'CSF Video Enabled Manually'!$A$3:$A$180,1,FALSE)
```

A view of what the report rows look like after the formula is applied. Headers left to right are “Device”, “Description”, “Device Pool”, “XML”
<span class="image fit"><img src="{{ "/assets/images/videocalling6.png" | absolute_url }}" alt="A view of what the report rows look like after the formula is applied. Headers left to right are “Device”, “Description”, “Device Pool”, “XML”" /></span>

Now, as is the case with almost any report that I've pulled there's always the request for additional information. Usually something they wanted from the get-go but didn't mention or didn't know they wanted when the initial request came through. In our case it was to attempt to identify the site these users are at. To do this I've utilized the Device Pool associated with the user's phone. If there is no more granular depiction within CUCM (Location field?) then this is what we'll end up going with. So the only query I end up modifying is my initial "all users" query as that page displays the colorized data (and is really what they want to be looking at). To this we add the dp.name (from devicepool table represented as dp) and we related the foreign key of the devicepool assigned to the device (fkdevicepool in device as d) to the pkid of the device pool (pkid in devicepool as dp). 

## Expanded Query - Device Pool Relationship

```text
run sql select d.name, d.description, d4k.xml, dp.name as devicepool from device as d inner join devicexml4k as d4k on d4k.fkdevice=d.pkid inner join devicepool as dp on d.fkdevicepool=dp.pkid where d.name like 'CSF%'
```

## Expanded Query - Output

Modified version of my initial query to include the device pool assigned to the given device.
<span class="image fit"><img src="{{ "/assets/images/videocalling7.png" | absolute_url }}" alt="Modified version of my initial query to include the device pool assigned to the given device." /></span>

The caveats mentioned were sent to the client in the email containing the report, as well as a quick explainer on how to interpret the data (such as below). When I can't make it clean and easily understandable, you might say I've failed... and maybe I have. But I'm not particularly great at organizing data so that it's digestable by others, especially when it comes to Excel.

## Explainer

In this new version of the report, on the “CSF All Jabber Profiles” worksheet (Sheet 1) the following can be viewed; filters are disabled and formula based color coding is in use.

If the CSF name in “Column A” is WHITE, video calling is enabled by **default**.
If the CSF name in “Column A” is GREEN, video calling is enabled *manually*.
If the CSF name in “Column A” is RED, video calling is disabled *manually*.

The caveats that I noted in my previous email are still relevant.

Visual representation of the color scheme described above.
<span class="image fit"><img src="{{ "/assets/images/videocalling8.png" | absolute_url }}" alt="Visual representation of the color scheme described above." /></span>


So with all of this done I was able to button up the data into a single Excel Workbook with 3 sheets, some formulas to identify information that was of interest to the client and ultimately created another SQL query to throw into my tool belt to potentially be pulled out for other regions or clients that may request similar data.

This query was fun to work up in that it dealt with data that I had not previously looked at (XML Data for the specific devices) as well as finding ways to work around the lack of ability to identify if we are overriding the Common Phone Profile setting. I hope this was informative for you and encourage you to reach out on Twitter (@kperryUC, @ThoughtsNOC), or @kperryuc on LinkedIn, or join the NOC Thoughts Discord!
