---
title: "Linux - Automating SSL Cert Trust Install"
layout: single
classes: wide
date: 2023-05-16T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Linux
  - Arch
  - Debian
tags:
  - Linux
  - Arch
  - Debian
  - General
---

## Automating Certificate Chain Import and Trust with a Bash Script

In an increasingly interconnected world, the importance of secure communication cannot be overstated.<!--more--> When devices communicate over a network, it is crucial to ensure that the connection is secure and that the entities at both ends of the communication are who they say they are. This is where SSL/TLS certificates come in.

SSL/TLS certificates are digital certificates that authenticate the identity of a website and enable encrypted communication between a web browser and a web server. These certificates are typically issued by Certificate Authorities (CAs), which are trusted entities that validate the identity of the entities to which they issue certificates.

A certificate chain, also known as a certificate hierarchy, is a list of certificates, starting from the certificate of the server in question, through one or more intermediary certificates, and ending with the root certificate of the CA.

## The Need for Certificate Import and Trust

There are cases where the certificate of a website or service is not trusted by the system or application trying to access it. This can occur for several reasons: the certificate might be self-signed, the root CA might not be trusted by the system, or the certificate chain might not be installed correctly on the server.

An example use case is a VPN client such as Cisco Anyconnect. If the VPN server uses a certificate from a CA that is not included in the trust store of the system running the VPN client, the client will refuse to connect. In this case, manually importing the certificate chain from the VPN server and adding it to the system's trust store can resolve the issue.

## Bash Script for Certificate Import and Trust

To automate this task, we can create a Bash script that connects to a given server, downloads the certificate chain, and adds it to the system's trust store.

First, the script prompts the user for the URL of the website. It then checks if the input is valid.

Next, the script identifies the operating system to set the path for the openssl.cnf file. Currently, the script supports Debian and Arch-based systems.

The script then creates a temporary file and attempts to connect to the server and download the certificate chain. If the connection is unsuccessful, the script informs the user and exits.

If the server supports 'unsafe legacy renegotiation', the script ensures that the UnsafeLegacyRenegotiation SSL option is enabled. To do this, it checks the openssl.cnf file for the relevant configuration categories and options, and adds them if necessary. This involves complex text manipulation and careful error checking.

The script then extracts the certificate chain from the downloaded data and moves it to the proper location for trusted certificates in the system's file structure.

Finally, the script updates the system's trust database, informs the user of the successful operation, and cleans up the temporary files created during the process.

This script not only automates a tedious process but also ensures that the necessary safety checks are in place to prevent errors. By taking care of these details, the script allows users to focus on their main tasks without having to worry about the intricacies of SSL/TLS certificates.

As with any automated tool, it's important to use this script responsibly. While it can be a great time-saver, remember that trusting a certificate means you're placing a lot of trust in the entity it represents. Always ensure that you only import and trust certificates from reliable and trusted sources.

In conclusion, as we continue to rely on secure communications, tools like this Bash script become increasingly valuable. They allow us to manage the complex world of SSL/TLS certificates with ease, ensuring that we can maintain secure connections without getting bogged down in the details.

I have included examples of the cert run on a Debian system (Linux Mint) demonstrating the process if UnsafeLegacyRenegotiation needs to be enabled.

### Script
```bash
#!/usr/bin/bash
#####################################
# Script created by Ken Perry, 2023 #
#       NOC THOUGHTS BLOG           #
#    https://www.nocthoughts.com    #
#####################################


# Prompt user to enter the URL of the website
echo "Please enter the URL of the website (without 'https://'):"
read website

# Check if user input is empty
if [ -z "$website" ]; then
    echo "Error: No website URL provided. Please run the script again with a valid URL."
    exit 1
fi

openssl_cnf_path="/etc/ssl/openssl.cnf"

# Detect system and set the path to the openssl.cnf file
if [ -f /etc/debian_version ]; then
    # Debian-based system
    dirpath="/usr/local/share/ca-certificates/"
    command="update-ca-certificates"
elif [ -f /etc/arch-release ]; then
    # Arch-based system
    dirpath="/etc/ca-certificates/trust-source/anchors/"
    command="trust extract-compat"
else
    echo "Error: This script supports only Debian and Arch based systems."
    exit 1
fi

# Create a temporary file
tempfile=$(mktemp)

# Status message
echo "Attempting to connect to $website and download the certificate chain..."

# Attempt to connect to the server and download the certificate chain
output=$(echo "QUIT" | openssl s_client -showcerts -servername "$website" -connect "$website":443 2>&1)
echo "$output" > $tempfile

# Check if the connection was successful
if ! grep -q "BEGIN CERTIFICATE" "$tempfile"; then
    echo "Error: Failed to connect to $website. Please ensure the URL is correct and the website is up."
    rm "$tempfile"
    exit 1
fi

# Check if 'unsafe legacy renegotiation' is supported
if echo "$output" | grep -q "unsafe legacy renegotiation"; then
    # Check and insert options in openssl.cnf if necessary
    echo "Ensuring UnsafeLegacyRenegotiation SSL option is enabled..."

    declare -A options
    options=(["openssl_init"]="ssl_conf = ssl_sect" ["ssl_sect"]="system_default = system_default_sect" ["system_default_sect"]="Options = UnsafeLegacyRenegotiation")

    for category in "${!options[@]}"; do
        if grep -q "^\[$category\]" $openssl_cnf_path; then
            if ! grep -q "^${options[$category]}" $openssl_cnf_path; then
                sudo sed -i "/^\[$category\]/a\\${options[$category]}" $openssl_cnf_path
            fi
        else
            echo "[$category]" | sudo tee -a $openssl_cnf_path
            echo "${options[$category]}" | sudo tee -a $openssl_cnf_path
        fi
    done
else
    echo "Unsafe legacy renegotiation not supported by $website, or enabled locally already. Skipping..."
fi

echo "Connection successful. Extracting certificate chain..."

awk '/BEGIN CERTIFICATE/,/END CERTIFICATE/ {print $0}' $tempfile > chain.pem

# Status message
echo "Moving the certificate to $dirpath..."

# Move the certificate to the proper location
sudo mv chain.pem "$dirpath""$website".pem

# Status message
echo "Updating the trust database..."

# Update the trust database
sudo "$command"

# Print the result
echo "The certificate chain has been saved to $dirpath$website.pem and trusted."

# Clean up
echo "Cleaning up temporary files..."
rm "$tempfile"

echo "Done!"
```

### UnsafeLegacyRenegotiation needed, enablement automated
```bash
[kperry@VM Scripts]$ ./adoptSSLCert.sh 
Please enter the URL of the website (without 'https://'):
vpn.example.com
Attempting to connect to examplesite and download the certificate chain...
Ensuring UnsafeLegacyRenegotiation SSL option is enabled...
Connection successful. Extracting certificate chain...
Moving the certificate to the proper location...
[sudo] password for kperry: 
Updating the trust database...
The certificate chain has been saved to /etc/ca-certificates/trust-source/anchors/vpn.example.com.pem and trusted.
Cleaning up temporary files...
Done!
[kperry@VM Scripts]$ 
```

### UnsafeLegacyRenegotiation not needed, or already enabled
```bash
[kperry@VM Scripts]$ ./adoptSSLCert.sh 
Please enter the URL of the website (without 'https://'):
vpn.example.com
Attempting to connect to examplesite and download the certificate chain...
Unsafe legacy renegotiation not supported by examplesite, or enabled locally already. Skipping...
Connection successful. Extracting certificate chain...
Moving the certificate to the proper location...
[sudo] password for kperry: 
Updating the trust database...
The certificate chain has been saved to /etc/ca-certificates/trust-source/anchors/vpn.example.com.pem and trusted.
Cleaning up temporary files...
Done!
[kperry@VM Scripts]$ 
```

## Was It Worth It To Automate

All in all I would say it's worth the time to automate this process. As certificates get rotated due to expiry and new certificates need to be handled in a similar manner, this takes out the need to walk through the syntax and manage the certificates manually. This means the certificate import process is handled in the same way, every time. You can stop by the [NOCThoughts GitHub](https://github.com/Unhall0w3d/mind-enigma/tree/master) for all of the NOC Thoughts scripts and projects, or check out the script [directly](https://github.com/Unhall0w3d/mind-enigma/blob/master/Linux%20Scripts/adoptSSLCert.sh). Thank you for reading! If you want to suggest post topics or start a discussion, you can join the NOCThoughts Discord using the quick-links!