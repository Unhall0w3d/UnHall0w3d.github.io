---
title: "Standardizing Cisco UC Backup Configuration Across Managed Networks With PowerShell"
date: 2026-11-14T12:00:00-05:00
description: "A PowerShell workflow for Windows SFTP setup and Cisco UC DRS schedules across separate managed networks, with reusable profiles, coverage checks, and useful logs."
categories:
  - Cisco
  - Unified Communications
  - Automation
tags:
  - Cisco UC
  - Disaster Recovery System
  - PowerShell
  - OpenSSH
  - SFTP
  - CUCM
  - Unity Connection
  - Emergency Responder
  - UCCX
draft: false
---

Configuring a Cisco UC backup schedule is familiar work. Add the SFTP destination, select the features, set the schedule, enable it, and check the result.

The repetition starts when that same job spans numerous separated managed networks. Each network has its own local SFTP server and UC clusters. The procedure stays much the same, but the publisher addresses, credentials, paths, and topology change with every site.

That was the reason for this script. I wanted one repeatable way to prepare the local destination and configure the related backup schedules, with the details for each network kept in a reusable profile. Less time rebuilding the procedure from notes, and fewer opportunities to carry the previous site's settings into the next one.<!--more-->

## What Is Our Mission?

Standardize weekly and monthly DRS backup configuration across managed networks, while keeping each site's settings separate.

The script accepts CUCM, Unity Connection, Cisco Emergency Responder, and UCCX targets. For CUCM environments with IM and Presence, it also checks the associated IM&P nodes and their registered backup components.

There are two parts to the workflow:

1. Prepare the local Windows SFTP server.
2. Inspect and configure the UC backup devices and schedules that use it.

Each part has a preview and an explicit apply step. Both use the same nonsecret site profile. The work stays local to the managed network; a central server with access to every customer environment is unnecessary.

The examples here use **v1.6.1**. The [Tools & Downloads](/tools.html) page provides the entry point for tool revisions, with version-specific details in the accompanying README and changelog.

## The Manual Work We Wanted to Make Consistent

This follows the same idea as the [auto-answer](/2026/09/11/updating-cucm-auto-answer-from-a-phone-list-with-python.html) and [BLF-label](/2026/09/11/updating-cucm-blf-labels-with-python.html) scripts: define the scope, inspect the existing configuration, make the requested changes, and keep a useful record.

| Step | Manual workflow | Script workflow |
| --- | --- | --- |
| Select the environment | Track publisher addresses and site settings in notes. | Load the site's profile or CSV. |
| Prepare SFTP | Check OpenSSH, the account, folders, permissions, service, and firewall. | Display the local setup plan, then apply it explicitly. |
| Establish backup scope | Identify the cluster nodes and their registered features. | Query registration for each discovered node and compare the expected topology. |
| Configure DRS | Create devices, select features, set recurrence, and enable schedules. | Preview the proposed additions, create them with `-Apply`, and read back the available settings. |
| Handle existing objects | Check whether a familiar name has the intended settings. | Preserve the object and identify settings the CLI cannot fully verify. |
| Record the work | Maintain notes and screenshots for each environment. | Write discovery, proposed changes, write intent, and results to a fresh JSONL log. |

The useful part is consistency. The same inputs drive the local folders and the DRS paths. The same checks run for each cluster. The result is a procedure we can inspect and reuse, instead of another set of remembered clicks.

## One Profile for Each Managed Network

The original workflow prompted for CUCM and Unity Connection. The selection list now supports adding, editing, and removing targets for all four technologies, including multiple clusters of the same type.

CSV handles the target inventory. JSON holds the complete site profile, including SFTP settings and schedules. Passwords belong in neither.

Here is a shortened fictional CSV:

```csv
Site,Id,Technology,Address,Port,Username,ExpectedNodes,ImpTopology,ImpPublisher,ImpSubscriber
SiteA,Voice,CUCM,192.0.2.10,22,admin,cucm-pub;imp-pub;imp-sub,Pair,imp-pub,imp-sub
SiteA,Voicemail,CUC,192.0.2.20,22,admin,cuc-pub;cuc-sub,None,,
SiteA,Emergency,CER,192.0.2.30,22,admin,cer-pub;cer-sub,None,,
SiteA,ContactCenter,UCCX,192.0.2.40,22,admin,ccx-pub;ccx-sub,None,,
```

`ExpectedNodes` contains the exact, case-preserved short hostnames for the cluster, including any subscribers. The sample voice cluster has a CUCM publisher and an IM&P pair. Missing or unexpected nodes become a coverage issue. Without an expected list, discovery describes what the publisher returned but cannot establish whether a node is absent from that inventory.

The example JSON provides a starting profile. The wizard can also save its settings with `-SaveProfile .\site-a.json`, using a new filename. Each network gets its own profile. The site name also forms part of the credential-store key, which matters when separate networks reuse the same private IP addresses.

## Preparing the Local SFTP Server

Local setup runs in an elevated, 64-bit PowerShell window on that network's Windows SFTP server. The configured SFTP address must belong to the machine, and the selected targets must agree on the site, SFTP address, and local username.

The backup account must already exist and be enabled. The script resolves its SID and Windows profile location instead of assuming the home directory is always `C:\Users\<username>`. If the account has no initialized profile, apply mode can create one through the Windows profile API. Account creation, password changes, and enabling disabled accounts remain outside this operation. [Microsoft CreateProfile documentation](https://learn.microsoft.com/en-us/windows/win32/api/userenv/nf-userenv-createprofile)

A profile using `cmsbackup` might produce:

```text
C:\Users\cmsbackup\SFTPBackups\SiteA\Voice\CUCM\Weekly\
C:\Users\cmsbackup\SFTPBackups\SiteA\Voice\CUCM\Monthly\
C:\Users\cmsbackup\SFTPBackups\SiteA\Voicemail\CUC\Weekly\
C:\Users\cmsbackup\SFTPBackups\SiteA\Voicemail\CUC\Monthly\
```

DRS uses the corresponding relative paths, such as `SFTPBackups/SiteA/Voice/CUCM/Weekly/`.

In apply mode, local setup installs the Windows OpenSSH Server capability when absent, creates the folder hierarchy, grants the backup account Modify access, and configures `sshd` to start automatically. A new `SFTPBackups` root gets a private permission baseline for the backup account, SYSTEM, and Administrators. Existing folder permissions are preserved, with the required grant added where absent. Conflicting deny entries stop the operation.

For a fresh OpenSSH installation, the script replaces the newly created broad default firewall rule with a rule scoped to the selected local address and supplied UC source addresses or subnets, on Domain/Private profiles. Pre-existing firewall rules remain in place, so the new rule does not narrow access those rules already allow. [Microsoft OpenSSH installation guidance](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse)

The preview command is:

```powershell
.\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site-a.json -SetupLocalSftp -SftpRemoteAddress 192.0.2.0/24
```

The subnet is fictional. The actual source scope includes the UC nodes that originate backup traffic, which can include subscribers. Adding `-Apply` enables the displayed setup changes after confirmation.

This mode preserves existing SSH configuration. It does not create an SFTP-only jail or adapt custom chroots, forced commands, or nonstandard subsystem paths. Those configurations sit outside the supported local setup workflow. [Microsoft OpenSSH configuration guidance](https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh-server-configuration)

## A Publisher Login Does Not Establish Backup Coverage

One of the more useful changes came from looking at feature discovery. A successful publisher login says very little about whether every expected node and component appears in DRS.

The script discovers the cluster nodes and queries registration for each one through the publisher. It retains the feature and component information, builds the schedule's feature list, and compares it with the expected topology.

For CUCM with IM&P, that includes `IM_AND_PRESENCE` and the expected publisher/subscriber component sets. Cisco documents cases where missing registrations cause backup failures. The script reports those gaps rather than attempting to repair registration as part of schedule creation. [Cisco IM&P component guidance](https://www.cisco.com/c/en/us/support/docs/unified-communications/unified-communications-manager-im-presence-service/220186-troubleshoot-missing-drf-components-in-t.html)

The release checks recognize CUCM, Unity Connection, and CER 14/15, plus UCCX 12.5/15. Unrecognized output or unavailable node registration stops that target. These are input and coverage checks; an accepted release number is not proof that a backup completed.

Two corrections in v1.6.1 make that distinction more useful. The UCCX check compares complete major and minor version components, so a value such as `12.50` cannot accidentally satisfy the rule for `12.5`. A declared CUCM environment also requires `CCM` registration on an exact discovered node. An IM&P-only inventory cannot stand in for evidence of CUCM itself.

The existing per-node and IM&P component checks remain in place. The product-to-feature mapping is shared across input validation, release checks, and coverage checks, so those parts of the script use the same definition of each technology.

## Preview, Then Apply

UC operations use Posh-SSH and the appliance's SSH/OS administrator credentials. The README covers module setup and the full command options.

Inspection reads the environment without creating a device or schedule:

```powershell
.\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site-a.json -ReadOnly -CredentialMode Never -LogPath .\site-a-inspect-001.jsonl
```

A normal run presents the proposed additions. `-Apply` enables writes after the script's confirmation step:

```powershell
.\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site-a.json -CredentialMode Never -LogPath .\site-a-preview-001.jsonl
.\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site-a.json -CredentialMode Never -LogPath .\site-a-apply-001.jsonl -Apply
```

Each log filename is new. Apply performs fresh discovery and checks; it does not replay a saved preview. The prompts include the UC node's displayed date, time, and timezone because the schedule uses that node's wall clock. Weekly and monthly settings are configurable. A `MonthlyDay` of `0` omits the monthly device and schedule.

The examples use `-CredentialMode Never`. Optional `-CredentialMode Ask` stores SSH and SFTP credentials separately in Windows Credential Manager, scoped by site, purpose, address, port, and username. New SSH credentials are offered for storage after authentication succeeds. Host-key checking stays enabled. The DRS cluster security password is separate from this credential feature.

Existing objects are preserved. A device named `Probe_Weekly` may exist without having the intended destination or retention, and the CLI does not expose every setting. Those cases are reported as `unverified_existing`. Disabling or deleting existing configuration belongs to the separate `-ManageExisting -Apply` workflow.

## Keeping a Useful Record When Something Fails

Before each appliance write, the script flushes an intent record to the log. The response and available read-back results follow it. If the result is uncertain, the script stops that target and attempts a fresh read-only connection to capture its current state. It does not automatically replay the command.

SSH streams and sessions have independent cleanup attempts. A failure disposing one resource does not prevent the attempt to close the other.

A run is not a transaction. A device, installed Windows feature, or folder can remain after a later failure. The log records that sequence, but it is not a restore package and the script does not automatically roll back current configuration.

The tool's scope is backup configuration. An enabled schedule, a completed backup, and a usable restore are different results. Keeping those distinctions in the output makes the record more useful when something goes wrong.

## Review and Download

The package contains the script, README, fictional CSV and JSON inputs, offline test harnesses, validation notes, a changelog, and SHA-256 checksums. The expandable sections below show the script and usage guide before download.

The packaging checks compare the source files, individual downloads, and ZIP contents. The site checks also cover the expandable preview targets. That keeps the code shown in the article aligned with the files in the package. Revision and release details belong with the tool, while this post explains the job it solves and the decisions behind it.

<details class="code-preview" data-code-preview="/assets/downloads/uc-drs-backups-candidate/Set-UC-DRSBackupSchedules-v1.6.1.ps1">
  <summary><span>Review the PowerShell script</span><small>POWERSHELL // UC DRS AND LOCAL SFTP</small></summary>
  <pre aria-live="polite"><code>Open this panel to load the PowerShell script.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/uc-drs-backups-candidate/README.txt">
  <summary><span>Review the README and usage examples</span><small>TEXT // SETUP AND OPERATION</small></summary>
  <pre aria-live="polite"><code>Open this panel to load the usage guide.</code></pre>
</details>

- <a href="/assets/downloads/uc-drs-backups-candidate/UC-DRS-v1.6.1-testing.zip" download>Download the complete v1.6.1 package</a>
- <a href="/assets/downloads/uc-drs-backups-candidate/Set-UC-DRSBackupSchedules-v1.6.1.ps1" download>Download the PowerShell script</a>
- <a href="/assets/downloads/uc-drs-backups-candidate/README.txt" download>Download the README</a>
- <a href="/assets/downloads/uc-drs-backups-candidate/targets-example.csv" download>Download the fictional target CSV</a>
- <a href="/assets/downloads/uc-drs-backups-candidate/profile-example.json" download>Download the example profile</a>

The next managed network starts with its own settings and the same procedure. That was the point of making the script: keep the repeated work consistent, keep the site-specific details visible, and leave a record of what happened.
