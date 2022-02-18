---
title: "Securing SCCP Media Resources in IOS"
date: 2019-11-18T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - Unified Communications
  - Cisco
  - IOS/XE
tags:
  - Cisco CUBE
  - Cisco
  - SCCP
  - Media Resource
  - Security
  - Certificates
  - Cisco Callmanager
  - Unified Communications
---

<head>
    <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=ca-pub-7351461893377144"
     crossorigin="anonymous">
     </script>
</head>

An interesting change I was involved in recently that was more of an oddity to me was setting up a CA in IOS, signing a certificate for Media Resources and registering it against a secure CCM cluster. Most of the clients I have had the pleasure of working with did not secure, or need to secure their UC environment for SRTP. And as many folks will say, you can read about something all you want but you don't really get a firm grasp on it until you get your feet wet.

<!--more-->

And get my feet wet I did! I made an initial mistake in disabling the "Cisco Cert Change Notification" service which prevented the certificates from automagically propagating from the Pub to Sub trust stores. This caused me some confusion when the CFB wouldn't register, I ended up double checking the specific CUCM list that SCCP was using and verified the cert didn't exist, so I re-enabled the service across the board and re-checked. Bam. Cert existed, CFB registered. Stressful 10-15 minutes while I sat and thunk about what might have been wrong.

But to learn from my experience (and mistake), below is a mock up of the configuration used to stand up a CA, a trustpoint for the CFB resource, enroll/sign the certificate and export it out. The steps are also provided for the CUCM portion in order to get the newly secured media resource to register.

## The Process

### Enable HTTP Server

CUBE_CA_1 is a configurable name, this is what I chose. Choose what you want but stay consistent.

```text
ip http server
crypto key generate rsa general-keys label CUBE_CA_1 modulus 2048
crypto pki trustpoint CUBE_CA_1 
     revocation-check none
     rsakeypair CUBE_CA_1
```

### Create CA Server

You will be prompted for a password.

```text
crypto pki server CUBE_CA_1
     database level complete
     no database archive
     grant auto
     hash sha256
     lifetime certificate 1826
     lifetime ca-certificate 1826
     database url flash:/CUBE_CA_1
     no shut
```

### Validate CA Certificate

```text
show crypto pki certificate CUBE_CA_1
```

### Create CFB Trustpoint

CUBE_CFB_1 is a configurable name, but should match the name of the CFB resource attempting to register to CCM via SCCP.

For example: If your CFB is named "USCAROMEO33RDSTREETCFB" then it needs to match in the trustpoint configuration and subsequent CA signed certificate.

```text
crypto pki trustpoint CUBE_CFB_1
      enrollment url http://<cube-ip>:80
     serial-number none (configurable, I chose none)
   fqdn none (configurable, I chose none )
     ip-address none (configurable, I chose none)
       subject-name cn=CUBE_CFB_1
       revocation-check none (configurable, I chose none)
       rsakeypair CUBE_CFB_1
       exit
```

### Perform CA Sign/Enroll

You will be prompted, press "Y" to continue. Also, enter a password for the trustpoint upon prompt. 

```text
crypto pki authentication CUBE_CFB_1
crypto pki enroll CUBE_CFB_1
```

### Validate CFB Certificate

```text
show crypto pki certificate CUBE_CFB_1
```

### Export Certificate & Save To .pem File

This will export the certificate metadata to the terminal. It will provide the CA (top most) and general purpose (CFB) certificates. Save these two as separate files (CUBE_CFB_1.pem) and (CUBE_CA_1.pem) respectively. 

```text
crypto pki export CUBE_CFB_1 pem terminal
```

### Upload to CUCM Pub as callmanager-trust

1. Log in to CUCM Publisher via HTTPs (443/8443) and navigate to OS Administration
2. Click on Security > Certificate Management
3. Click on "Upload a certificate/certificate chain"
4. Select "callmanager-trust"
5. Click "Browse"
6. Browse to the location where the two .pem files are stored and upload the CA Certificate, then General Purpose/CFB Certificate.
7. Verify via logging into the other Subscribers in the cluster that the two certificates were propagated over via Cisco Certificate Change Notification.
8. Navigate to Cisco Unified Serviceability
9. Restart the Cisco CallManager service on the CUCM Pub, then Subscribers one at a time. Allow 5 minutes between service restarts for devices to fail over/fail back before proceeding to the next node. Add more time depending on your network design and expected failover times.

### Verify Registration Status

1. In IOS, perform a "show sccp all" and verify that the CFB resource has registered and shows active/connected.
2. In CUCM, navigate to CM Administration > Media Resources > Conference Bridge. Ensure that the endpoint is registered.

You may need a "no sccp // sccp", although I did not.
Given that this config requires a secure cluster (Mixed Mode) - (SRTP) the CFB should have been previously unregistered after being configured.

### Replicating The Steps on a Redundant CUBE

If you're looking to replicate this on, for example, a redundant CUBE, you can utilize the trustpoint steps only in order to sign/enroll the certificate against the already existent CUBE_CA_1. For this, see below; follow the same steps regarding saving the metadata to two separate files, and the same upload, validation, and service restart procedures.

```text
crypto pki trustpoint CUBE_CFB_2
     enrollment url http://<CUBE_CA_1-IPADD>:80
     serial-number none
     fqdn none
     ip-address none
     subject-name cn=CUBE_CFB_2
     rsakeypair CUBE_CFB_2
     exit
```

```text
crypto pki authentication CUBE_CFB_2
crypto pki enroll CUBE_CFB_2  
```

```text
show crypto pki certificate CUBE_CFB_2
crypto pki export CUBE_CFB_2 pem terminal
```

And that's it! An initially daunting (due to lack of experience) task made easy. Do abide by any security requirements your org has, as you may have additional considerations that I did not, and may require some changes to the configuration.

As always I hope this has been helpful, especially in outlining the required config elements and steps to secure Media Resources on IOS for registration with CUCM. For socials you can follow or reach out to me in the comments here, on Twitter (@kperryuc), and on LinkedIn.
