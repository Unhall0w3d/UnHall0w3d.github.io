---
title: "Automating mRemoteNG - PuTTY Session Creation"
layout: single
classes: wide
date: 2023-05-23T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - General
  - Python
  - Automation
tags:
  - Python
  - Automation
  - SSH
---

## Automating mRemoteNG and PuTTY Session Creation: A Comprehensive Overview
In the information technology landscape, efficiency is not just a preference—it's a requirement.<!--more--> In the intricate digital environments we manage, reducing laborious manual tasks is a critical factor in maintaining an effective workflow. Thus, we've developed an innovative [Python](https://www.python.org/) script that significantly streamlines the process of creating [mRemoteNG](https://mremoteng.org/) and [PuTTY](https://www.chiark.greenend.org.uk/~sgtatham/putty/) sessions, particularly those that require [SSH port forwarding](https://www.ssh.com/academy/ssh/tunneling-example#:~:text=SSH%20port%20forwarding%20is%20a,server%20machine%2C%20or%20vice%20versa.).

## SSH Port Forwarding
Also known as SSH tunneling, is a versatile and reliable method for securely transmitting data. It has emerged as a crucial strategy in the toolset of IT professionals who are committed to maintaining robust and effective security practices. The key advantage of SSH Port Forwarding lies in its ability to establish a secure channel over an unsecured network, bridging a path between the local system and a remote server. By so doing, it ensures the confidentiality and integrity of data in transit, an aspect that is particularly invaluable in today's world fraught with cybersecurity risks.

One of the unique strengths of SSH Port Forwarding is that it allows for traffic to be sent securely from a local port to a remote port, or even between two remote ports. This attribute facilitates the configuration of scenarios where access to certain devices can be locked down to only those approved hosts used as SSH port forwarding jump hosts. This not only strengthens the security landscape of an organization but also provides more granular control over who has access to what within a network.

### Standardizing Your Access Method
In a modern networking environment that is characterized by diverse types of devices and access methods, standardization is key. SSH Port Forwarding enables such standardization by providing a consistent, reliable, and secure method for accessing hosts. By incorporating this into our scripts, we ensure a uniform access method across the board, which simplifies the process of managing and maintaining devices. It reduces complexities that could arise from dealing with multiple access methods and enhances the efficiency of network management operations.

### Here At NOCThoughts
The incorporation of SSH Port Forwarding within our scripting aligns harmoniously with the use of mRemoteNG, an open-source software for managing remote connections. mRemoteNG supports a wide array of protocols, including SSH, and presents an organized interface that can handle a high number of connections. In our context, the script works seamlessly with mRemoteNG, auto-generating configuration files that can be readily imported into the software. This not only accelerates the process of setting up new sessions but also reduces potential human errors.

### Why mRemoteNG? Why Open Source?
The open-source nature of mRemoteNG provides several advantages. It offers the transparency that is much sought after in today's digital world. Users can review the source code to ascertain its security and integrity. In addition, being open-source means that it benefits from the contributions of a global community of developers who work tirelessly to refine and enhance its features. This, in turn, assures users of the continual evolution of the software to meet emerging needs and tackle novel challenges. The usage of open-source software such as mRemoteNG aligns with the ethos of promoting transparency, collaboration, and community engagement.

### Right, Let's Sum It Up
SSH Port Forwarding and mRemoteNG form a formidable duo in bolstering the security and efficiency of managing network connections. SSH Port Forwarding ensures that data transmission is secure and access to devices is controlled, while mRemoteNG provides a comprehensive and organized platform for handling remote connections. The integration of these technologies within our scripts delivers a highly efficient, secure, and streamlined process for creating large numbers of port forward sessions. In an era where network complexity is constantly increasing, such approaches are vital in maintaining operational efficiency, control, and security.

## The Script's Purpose: Responding to the Challenge
Working with large-scale networks and data centers requires establishing numerous remote access points for a myriad of devices. mRemoteNG and PuTTY are robust tools that simplify this task. However, the creation of multiple sessions manually can be time-consuming, which detracts from other critical tasks. Our Python script addresses this problem, dramatically reducing the time required to set up these sessions, thereby increasing efficiency.

## Script Functionality: An Overview
The Python script we've developed performs several functions:

### Data Analysis and Cleanup:
The script begins by reading a CSV file that contains data about network devices. It filters this information, selecting only the devices for which sessions need to be created.

### Session Creation:
Once the list of devices is ready, the script generates unique session names and universally unique identifiers (UUIDs) for each device and crafts configurations for each session.

### Port Forwarding Configuration:
The script also manages the complex task of setting up port forwarding, customizing the settings based on the type of device in question.

The output includes a registry (.reg) file for import into PuTTY and a CSV file for mRemoteNG. Both of these files contain ready-to-use sessions, saving a significant amount of time compared to the manual creation process.

## Efficiency Increase: Time and Resource Management
The script’s effectiveness comes down to a significant reduction in time spent creating and configuring sessions. Manually, this process could take up to five minutes per device, which, across hundreds of devices, quickly adds up. Our Python script can accomplish the same task in a fraction of the time, freeing resources for other tasks and substantially improving workflow efficiency.

## Recent Improvements: An Enhanced Version
The [Python script](https://github.com/Unhall0w3d/mind-enigma/blob/master/General%20Automation/mRemoteNG_puttySessionCreator.py) has recently undergone several updates, please be sure to check the [ReadMe](https://github.com/Unhall0w3d/mind-enigma/blob/master/General%20Automation/ReadMe.md):

### UUID Generation:
The script now leverages the Python uuid library for the creation of unique UUIDs for each session, and linkage between parent folders and child sessions. This enhancement simplifies the import of sessions into mRemoteNG.

###  Port Forwarding Configuration:
The script's ability to adjust port forwarding settings based on the device type has been improved. It now accurately tailors the settings based on device type, as outlined in the import .csv [template](https://github.com/Unhall0w3d/mind-enigma/tree/master/General%20Automation/mRemoteNG_docs).

### Improved Output:
The script now provides a CSV file for mRemoteNG and a .reg file for PuTTY, facilitating easier setup of sessions in both platforms.

## The Script
```python
#!/usr/bin/python
#####################################
# Script created by Ken Perry, 2023 #
#       NOC THOUGHTS BLOG           #
#    https://www.nocthoughts.com    #
#####################################

import random
import os
import pandas as pd
import glob
import time
import csv
import uuid


def analyze_sanitize():
    # List all .csv files in the current directory
    csv_files = glob.glob("*.csv")

    # If there are no .csv files in the directory, notify the user
    if not csv_files:
        print("No .csv files found in the current directory.")
        return

    # Print out the files for the user to choose
    for i, file in enumerate(csv_files):
        print(f"{i + 1}. {file}")

    # Get the user's choice
    choice = int(input("Enter the number of the file to use: ")) - 1
    device_list_path = csv_files[choice]

    # Read the .csv file
    read_in = pd.read_csv(device_list_path, header=None)  # Indicate that there is no header

    # Filter the data based on the device type and column "E"
    device_types = ["Network", "DC-UCS", "DC-VMWare", "IPT", "Network-Voice", "Video-TelePresence"]
    filtered = read_in[read_in[0].isin(device_types)]
    return filtered


def generate_chaos():
    return str(uuid.uuid4())


class HiveMind:
    def __init__(self):
        self.filename = None
        self.folderuuid = generate_chaos()

        # Check if the directory exists, create it if it doesn't
        if not os.path.exists('mRemoteNG Sessions'):
            os.makedirs('mRemoteNG Sessions')

        # Establish list to contain port forwarding information
        self.port_forwardings = []
        self.timestr = time.strftime("%Y%m%d-%H%M%S")

        # Collect some data
        self.session_name = input("Enter the session name: ")
        self.hostname = input("Enter the hostname/IP: ")
        self.username = input("Enter the username: ")

    def get_tunnel_config(self, tech_type, ip_addr, dev_name, descrip, site):
        """
        Returns the tunnel configuration based on the device type.
        """
        ssh_port = random.randint(30000, 35000)
        ssh_tunnel = f"L{ssh_port}={ip_addr}:22"

        if tech_type in ["Network", "Network-Voice"]:
            self.port_forwardings.append(ssh_tunnel)
            sshuuid = generate_chaos()
            with open(
                    os.path.join('mRemoteNG Sessions', (self.session_name + '-' + self.timestr + '-importFile.csv')),
                    'a') as f:
                writer = csv.writer(f, delimiter=";")
                data = [
                    f"{tech_type}_{dev_name}_SSH", f"{sshuuid}", f"{self.folderuuid}", "Connection",
                    f"{site}_{descrip}", "SSH", "General", f"localhost", "", "SSH2",
                    "DefaultSettings", f"{ssh_port}", "False", "True", "False", "IE",
                    "EncrBasic", "NoAuth", "", "Colors16Bit", "FitToWindow",
                    "TRUE", "FALSE", "FALSE", "FALSE",
                    "FALSE", "FALSE", "FALSE", "FALSE",
                    " FALSE", "FALSE", "FALSE", "DoNotPlay", "FALSE",
                    "", "", "", "", "", "FALSE", "CompNone",
                    "EncHextile", "AuthVNC", "ProxyNone", "", "0", "",
                    "", "ColNormal", "SmartSAspect", "False", "Never",
                    "", "Yes", "", "",
                    "", "FALSE", "Highest"
                ]
                writer.writerow(data)
        elif tech_type in ["IPT", "DC-UCS", "DC-VMware"]:
            https_port = random.randint(35000, 40000)
            https_tunnel = f"L{https_port}={ip_addr}:443"
            self.port_forwardings.append(f"{ssh_tunnel},{https_tunnel}")
            sshuuid = generate_chaos()
            httpsuuid = generate_chaos()
            with open(os.path.join('mRemoteNG Sessions', (self.session_name + '-' + self.timestr + '-importFile.csv')),
                      'a') as f:
                writer = csv.writer(f, delimiter=";")
                sshdata = [
                    f"{tech_type}_{dev_name}_SSH", f"{sshuuid}", f"{self.folderuuid}", "Connection",
                    f"{site}_{descrip}", "SSH", "General", f"localhost", "", "SSH2",
                    "DefaultSettings", f"{ssh_port}", "False", "True", "False", "IE",
                    "EncrBasic", "NoAuth", "", "Colors16Bit", "FitToWindow",
                    "TRUE", "FALSE", "FALSE", "FALSE",
                    "FALSE", "FALSE", "FALSE", "FALSE",
                    "FALSE", "FALSE", "FALSE", "DoNotPlay", "FALSE",
                    "", "", "", "", "", "FALSE", "CompNone",
                    "EncHextile", "AuthVNC", "ProxyNone", "", "0", "",
                    "", "ColNormal", "SmartSAspect", "False", "Never",
                    "", "Yes", "", "",
                    "", "FALSE", "Highest"
                ]
                writer.writerow(sshdata)
                httpsdata = [
                    f"{tech_type}_{dev_name}_HTTPS", f"{httpsuuid}", f"{self.folderuuid}", "Connection",
                    f"{site}_{descrip}", "Web Server", "General", f"localhost", "", "HTTPS",
                    "DefaultSettings", f"{https_port}", "False", "True", "False", "IE",
                    "EncrBasic", "NoAuth", "", "Colors16Bit", "FitToWindow",
                    "TRUE", "FALSE", "FALSE", "FALSE",
                    "FALSE", "FALSE", "FALSE", "FALSE",
                    "FALSE", "FALSE", "FALSE", "DoNotPlay", "FALSE",
                    "", "", "", "", "", "FALSE", "CompNone",
                    "EncHextile", "AuthVNC", "ProxyNone", "", "0", "",
                    "", "ColNormal", "SmartSAspect", "False", "Never",
                    "", "Yes", "", "",
                    "", "FALSE", "Highest"
                ]
                writer.writerow(httpsdata)

    def construct_port_forwards(self, tech_type, ip_addr, dev_name, descrip, site):
        # Get the tunnel configuration
        self.get_tunnel_config(tech_type, ip_addr, dev_name, descrip, site)

    def construct_reg_key(self):

        # Define registry key path
        key_path = r"[HKEY_CURRENT_USER\Software\SimonTatham\PuTTY\Sessions\{}]".format(self.session_name)

        # Define the session details
        session_details = f"""Windows Registry Editor Version 5.00 

{key_path}

"HostName"="{self.hostname}"
"PortNumber"=dword:{22:08x}
"UserName"="{self.username}"
"Protocol"="ssh"
"SshProt"=dword:3
"""

        # Define the filename using the session name and hostname
        self.filename = f"{self.session_name}-SSH-Tunnels-{self.timestr}.reg"

        # Create a new file and write the session details
        with open(os.path.join('mRemoteNG Sessions', self.filename), 'w') as f:
            f.write(session_details)

        # Inform user that the .reg file was created successfully
        print(f"Reg file {self.session_name} created successfully.")

    def mremoteng_import_generator(self):
        # Create .csv file
        with open(os.path.join('mRemoteNG Sessions', (self.session_name + "-" + self.timestr +
                                                      '-importFile.csv')), 'w+') as f:
            writer = csv.writer(f, delimiter=";")
            header = [
                "Name", "Id", "Parent", "NodeType", "Description", "Icon", "Panel", "Hostname", "VmId", "Protocol",
                "PuttySession", "Port", "ConnectToConsole", "UseCredSsp", "UseVmId", "RenderingEngine",
                "ICAEncryptionStrength", "RDPAuthenticationLevel", "LoadBalanceInfo", "Colors", "Resolution",
                "AutomaticResize", "DisplayWallpaper", "DisplayThemes", "EnableFontSmoothing",
                "EnableDesktopComposition", "CacheBitmaps", "RedirectDiskDrives", "RedirectPorts",
                "RedirectPrinters", "RedirectClipboard", "RedirectSmartCards", "RedirectSound", "RedirectKeys",
                "PreExtApp", "PostExtApp", "MacAddress", "UserField", "ExtApp", "Favorite", "VNCCompression",
                "VNCEncoding", "VNCAuthMode", "VNCProxyType", "VNCProxyIP", "VNCProxyPort", "VNCProxyUsername",
                "VNCProxyPassword", "VNCColors", "VNCSmartSizeMode", "VNCViewOnly", "RDGatewayUsageMethod",
                "RDGatewayHostname", "RDGatewayUseConnectionCredentials", "RDGatewayUsername", "RDGatewayPassword",
                "RDGatewayDomain", "RedirectAudioCapture", "RdpVersion"
            ]
            writer.writerow(header)
            parentfolder = [
                f"{self.session_name}", f"{self.folderuuid}", "a1c0d02c-6d1d-4c23-b8af-c2d75ce96b8d", "Container",
                "", "mRemoteNG", "General", "", "", "RDP",
                "DefaultSettings", "3389", "False", "True", "False", "IE",
                "EncrBasic", "NoAuth", "", "Colors16Bit", "FitToWindow",
                "TRUE", "FALSE", "FALSE", "FALSE",
                "FALSE", "FALSE", "FALSE", "FALSE",
                "FALSE", "FALSE", "FALSE", "DoNotPlay", "FALSE",
                "", "", "", "", "", "FALSE", "CompNone",
                "EncHextile", "AuthVNC", "ProxyNone", "", "0", "",
                "", "ColNormal", "SmartSAspect", "False", "Never",
                "", "Yes", "", "",
                "", "FALSE", "Highest"
            ]
            writer.writerow(parentfolder)

    def director(self):
        print(f"Constructing reg key for PuTTY {self.session_name} session...")

        # Construct the base reg key to add a session to the end device for tunneling
        self.construct_reg_key()

        print("Constructing template .csv file for mRemoteNG import...")
        # Construct the template csv file with proper headers for mRemoteNG import
        self.mremoteng_import_generator()

        print("Filtering input data...")
        # Read in and parse .csv file to gather interesting data
        filtered = analyze_sanitize()

        print("Iterating through sanitized data...")
        # Iterate over each row in the filtered data
        for _, row in filtered.iterrows():
            tech_type = row[0]
            ip_addr = row[2]
            dev_name = row[1]
            descrip = row[3]
            site = row[9]

            self.construct_port_forwards(tech_type, ip_addr, dev_name, descrip, site)

        # Generate port forward string from list
        pfwdlist = ",".join(self.port_forwardings)

        print("Putting in the final touches...")
        # Add in port forwards
        with open(os.path.join('mRemoteNG Sessions', self.filename), 'a') as f:
            f.write(f""""PortForwardings"="{pfwdlist}"
                                            """)

        print("Job completed! Please check ./mRemoteNG Sessions/ for .reg and .csv!")


if __name__ == "__main__":
    print("Starting up...")
    HiveMind().director()

```

## TODO
There's a few things left to do with the script from an optimization perspective... quite a lot actually. There's a few blocks of code that could be abstracted to helper functions, I need to get better with list comprehension, less hard coding of values where possible... maybe using f-strings for file paths instead. This last one might just be a personal preference. Oh! I just thought of this: it would be better to read in the structure for the mRemoteNG import file from a template, rather than hard coding it. Create a dictionary and assign values read in to the output cells and write. Ideas, ideas, ideas.

## The Implication: Embracing Automation
In summary, the Python script exemplifies the power of automation in IT practices. The script significantly reduces the time and resources required for session creation and configuration, thereby improving efficiency. This innovative solution not only addresses a prevalent challenge in the IT field but also illustrates how automation can transform workflows.

By continuing to refine this tool, we aim to stay abreast of technological advancements and changing requirements in the realm of IT. The role of automation in IT cannot be overstated—it is an ally that allows us to focus on complex tasks while it handles the repetitive ones. By embracing automation, we can optimize our workflows and push the boundaries of what's achievable in IT.