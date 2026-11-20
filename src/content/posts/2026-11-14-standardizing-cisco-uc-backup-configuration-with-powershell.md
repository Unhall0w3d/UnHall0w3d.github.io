---
title: "Standardizing Cisco UC Backup Configuration Across Managed Networks With PowerShell"
date: 2026-11-14T12:00:00-05:00
description: "Reusable site profiles, a saved preview plan, and an ordered replacement workflow for Cisco UC DRS backup devices and schedules."
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

The repetition starts when that job spans numerous separated managed networks. Each network has its own local SFTP server and UC clusters. The procedure stays much the same, but the publisher addresses, credentials, paths, and topology change at every site.

That was the reason for this script. I wanted a repeatable way to prepare the destination and configure weekly and monthly backups, with each network's settings kept in its own profile. Replacing an old configuration needed the same treatment: inspect what exists, choose what stays and what goes, then see the whole sequence before changing anything.<!--more-->

## What Is Our Mission?

Standardize the configuration work without losing sight of the environment we are changing.

The tool has two jobs: prepare a local Windows SFTP destination where needed, and configure Cisco UC DRS devices and schedules. It includes product-specific handling for CUCM, Unity Connection, Cisco Emergency Responder, and UCCX. CUCM discovery also accounts for associated IM and Presence nodes. The validation record identifies which versions and workflows have been exercised.

Each network keeps its own profile and local SFTP server. There is no requirement for a central server that can reach every customer environment.

The examples below use the v1.6.2 revision 5 saved-plan workflow. Use [Tools & Downloads](/tools.html#uc-drs-title) to choose the available package and review its README, changelog, and validation details.

## Where the Manual Work Adds Up

For a single cluster, the individual steps are manageable. Across several networks, keeping those steps consistent becomes the job.

| Task | Manual workflow | Script workflow |
| --- | --- | --- |
| Select the environment | Work from notes containing publisher addresses and site settings. | Load a site profile, CSV, or interactive selection. |
| Prepare the destination | Check OpenSSH, the account, folders, permissions, service, and firewall. | Review a separate local setup plan and apply it explicitly. |
| Establish backup scope | Identify nodes and registered backup features. | Discover topology and registrations using the product's backup scope. |
| Replace old configuration | Disable selected schedules, remove schedules, then remove unused devices. | Select numbered objects and review the ordered maintenance plan. |
| Add the new configuration | Create each device and schedule, then enable it. | Include weekly/monthly additions in the same saved UC plan. |
| Check the result | Compare DRS settings and keep notes. | Read back available fields after each write and record the results. |

This follows the same approach as the [auto-answer](/2026/09/11/updating-cucm-auto-answer-from-a-phone-list-with-python.html) and [BLF-label](/2026/09/11/updating-cucm-blf-labels-with-python.html) tools: define the scope, inspect the existing configuration, and keep a record of each change.

## Keep the Site Details in a Profile

CSV provides target inventory. JSON also holds destination paths, retention, names, and schedule settings. Passwords belong in neither.

A shortened fictional CSV looks like this:

```csv
Site,Id,Technology,Address,Port,Username,ExpectedNodes,ImpTopology,ImpPublisher,ImpSubscriber
SiteA,Voice,CUCM,192.0.2.10,22,admin,cucm-pub;imp-pub;imp-sub,Pair,imp-pub,imp-sub
SiteA,Voicemail,CUC,192.0.2.20,22,admin,cuc-pub;cuc-sub,None,,
SiteA,Emergency,CER,192.0.2.30,22,admin,cer-pub;cer-sub,None,,
SiteA,ContactCenter,UCCX,192.0.2.40,22,admin,ccx-pub;ccx-sub,None,,
```

`ExpectedNodes` uses the actual short hostnames, including subscribers and any IM&P nodes. Missing or extra nodes stop configuration. Leaving it blank allows discovery and review, but the returned inventory alone cannot tell us about a node that is missing from that response.

Use a separate backup path for each cluster and frequency. For example:

```text
SFTPBackups/SiteA/Voice/CUCM/Weekly/
SFTPBackups/SiteA/Voice/CUCM/Monthly/
SFTPBackups/SiteA/Voicemail/CUC/Weekly/
SFTPBackups/SiteA/Voicemail/CUC/Monthly/
```

The site name also separates Windows Credential Manager entries. That matters when several managed networks reuse the same private addresses.

## Preview the Whole Replacement

The original script allowed optional cleanup before creation. That remains useful when replacing a backup destination or standardizing existing schedules. The revised workflow puts those choices into the preview so the complete sequence can be reviewed and saved.

Run it from a local Windows folder with the appropriate publisher OS-administrator account:

```powershell
.\Set-UC-DRSBackupSchedules-v1.6.2.ps1 -Profile .\site-a.json -LogPath .\preview-001.jsonl
```

If Posh-SSH is missing, add `-InstallDependencies` to install it for the current user and continue. Run this from the PowerShell edition you intend to use. Our fresh PowerShell 7 session did not find the module installed for Windows PowerShell 5.1; the existing installation option handled that without a script change.

After discovery, the script displays a compact device and schedule inventory. Choose **Add** to select an available action, then select one or more objects by number. The tool retains their exact names, including capitalization.

A replacement plan might contain:

```text
1. DisableSchedule SiteA_Weekly
2. DisableSchedule SiteA_Monthly
3. DeleteSchedule SiteA_Weekly
4. DeleteSchedule SiteA_Monthly
5. DeleteDevice SiteA_Weekly
6. DeleteDevice SiteA_Monthly
```

Weekly and monthly creation can follow those actions, or the plan can contain maintenance only. Nothing is disabled or deleted during preview.

**Edit** changes a planned action. **Remove** takes actions out of the plan. The script checks the resulting sequence before accepting either change. Removing a schedule deletion while leaving a dependent device deletion is rejected; removing both together is allowed. It does not quietly discard later actions to make an edit fit.

Already-disabled schedules are omitted from the disable list. Referenced devices cannot be selected for deletion until the plan removes their schedules. An empty inventory skips maintenance selection. **Cancel** ends the preview without saving a plan.

A successful preview saves `preview-001.plan.json` beside the log and prints the apply command.

## Apply the Saved Selections

Apply loads that file:

```powershell
.\Set-UC-DRSBackupSchedules-v1.6.2.ps1 -Apply -Plan .\preview-001.plan.json -LogPath .\apply-001.jsonl
```

It reconnects and compares the release, topology, registrations, and DRS inventory with the preview. It also checks the appliance clock and planned start dates. Changes that invalidate the plan stop the target; changing the intended work means creating a new preview.

The script reads `show date` from the appliance. It uses that local time and timezone to calculate the schedule start dates, rather than asking the operator to copy them into a particular format. Unrecognized output stops planning instead of falling back to the Windows clock.

Before the first configuration write, apply displays the plan, collects the required confirmations, and obtains any needed SFTP credentials. Deletions require recorded recovery settings, retained credential access, and a typed `DELETE <exact-name>` confirmation. Declining a deletion stops that target's sequence before an earlier planned disable can run.

Each change is followed by readback. An existing name left outside the selected cleanup remains in place and is reported for review. A familiar name does not establish that its destination, timing, or retention matches the profile.

## Product Differences Matter

The first corrections came from real appliance output. The cluster command can include a separate processnode table after its authenticated node rows. Treating that footer as another cluster row blocked valid CUCM and Unity Connection inventories.

Feature names also needed to follow the returned DRS registrations. CUCM's feature token is `UCM`; `CCM` appears in other product terminology but is not a substitute in the backup feature list. Cisco's CLI examples use `show_registration` to obtain that list. [Cisco DRS CLI operations](https://www.cisco.com/c/en/us/support/docs/unified-communications/unified-communications-manager-callmanager/211975-CUCM-DRS-Backup-and-Restore-Operations-v.html)

Unity Connection uses publisher-only backup scope. Its subscriber still belongs in topology checks, but the script queries registrations on the publisher. Applying CUCM's per-node registration expectation to CUC had blocked a valid cluster. [Cisco Unity Connection backup guidance](https://www.cisco.com/c/en/us/td/docs/voice_ip_comm/connection/15/install_upgrade/guide/b_15cuciumg/b_15cuciumg_chapter_01.html)

For CUCM with IM&P, the script checks the associated nodes and applicable `IM_AND_PRESENCE` components. Unknown output and missing required registrations stop configuration. The README describes each product adapter and its limits; recognizing a release number does not establish that every topology works the same way.

## Credentials and the Local SFTP Server

The SSH username is confirmed before the credential-store lookup. A newly entered password can be saved immediately after SSH authentication succeeds, before discovery starts. A later parsing failure therefore does not force another password entry on the next run.

Storage is optional and belongs to the current Windows user. Entries include the site, purpose, address, port, and username. SSH and SFTP credentials are separate, and host-key checking remains enabled. Use `-CredentialMode Never` to avoid the store.

Creating a backup device is not treated as independent proof of SFTP access. For a new SFTP credential, the script explains how to verify a manual backup in another CLI or DRS session, then return to the save prompt. **Skip** is the default. Saving still requires separate consent after verification.

The optional Windows setup runs on the site's SFTP host in an elevated shell:

```powershell
.\Set-UC-DRSBackupSchedules-v1.6.2.ps1 -Profile .\site-a.json -SetupLocalSftp -SftpRemoteAddress 192.0.2.10,192.0.2.11
```

Review that local plan, then repeat with `-Apply`. This is a separate setup mode; it does not use the UC saved-plan file.

The account must already exist and be enabled. Local setup can install inbox OpenSSH Server, initialize the account's Windows profile, create the required folders, add the required permissions, configure a scoped firewall rule, and start `sshd`. It preserves existing SSH configuration and existing folder permissions. Broader pre-existing firewall rules still need consideration.

This setup enables ordinary Windows SSH/SFTP. Custom chroots, forced commands, and unusual SSH installations require their own administration. The README covers the accepted account types, paths, source addresses, and setup restrictions.

## What the Lab Changed

Using the tool through the same Windows prompts exposed friction that parser tests did not: repeated JSON inventories, exact-name typing for every selection, and cancellation presented as a red error.

The numbered menus, editable plan, and plain cancellation result came from that experience. The output now separates fields checked through CLI readback from settings that require DRS review. Failure guidance distinguishes a preview that attempted no writes from an apply run with earlier successful changes or an unresolved write.

We then tested revision 5 from a fresh PowerShell 7.7.0 window on Windows, using Posh-SSH 3.2.7 against a single CUCM 15.0.1.15900-150 publisher. The test followed the same interactive preview and saved-plan apply workflow used at a managed site.

| Revision 5 check | Observed result |
| --- | --- |
| Select and revise the work | Multiple selection, Add, Edit, and Remove worked. Removing a prerequisite schedule deletion was rejected, leaving the plan unchanged. |
| Save the preview | Six maintenance actions and two creation pairs were saved. Preview sent zero configuration writes. |
| Apply the replacement | Both schedules were disabled and deleted, followed by their devices. Both device/schedule pairs were then recreated and enabled. All 12 writes had matching CLI readback verification records. |
| Reuse credentials and close connections | Saved SSH and SFTP credentials were offered after username confirmation. Both runs completed without connection cleanup errors. |

The intermediate inventory was empty after deletion, and the final inventory contained both network devices with their matching enabled schedules. No code correction was needed during this retest. The result remains `applied_verified_limited`: CLI readback verifies device names/types, schedule-to-device associations, and enabled status, but does not expose every destination or schedule setting.

The manual backup results came from revision 4. In that earlier test, backups to the weekly and monthly destinations each completed with all nine registered components successful. Its replacement cycle also preserved the sizes and hashes of all 20 existing backup files. Revision 5's retest exercised preview and replacement; it did not run another manual backup.

Revision 5 also passed 253 core checks and 53 local-setup checks using simulated dependencies. Those checks cover branches beyond the successful lab run, including cancellation and failure handling. They do not establish native Windows SFTP provisioning, other-product apply behavior, scheduled firing, or restore success. The package's validation record keeps those distinctions with the relevant revision.

## When a Run Stops Partway Through

A durable intent record precedes each appliance write. The response and readback verification follow it. If a write has no verification record, the tool stops and attempts one fresh read-only connection to capture current state. It does not replay the command automatically.

Earlier successful changes remain applied. There is no rollback transaction covering the run, and the audit log is not a complete recovery export. Both SSH stream disposal and session removal are attempted independently.

The tool configures backups. It does not start backup or restore jobs. An enabled schedule, a completed backup, and a usable restore remain separate results.

## Review and Download

Use [Tools & Downloads](/tools.html#uc-drs-title) for the script, README, examples, changelog, checksums, and the validation record for the available revision. The README contains the detailed commands, supported inputs, and recovery instructions.

The download checks compare the source, staged files, ZIP members, and checksums. The Tools page is the download location so package updates and validation details stay together. The panels below let you inspect the script and README before downloading.

<details class="code-preview" data-code-preview="/assets/downloads/uc-drs-backups-v1.6.2-candidate/Set-UC-DRSBackupSchedules-v1.6.2.ps1">
  <summary><span>Review the PowerShell script</span><small>POWERSHELL // UC DRS AND LOCAL SFTP</small></summary>
  <pre aria-live="polite"><code>Open this panel to load the PowerShell script.</code></pre>
</details>

<details class="code-preview" data-code-preview="/assets/downloads/uc-drs-backups-v1.6.2-candidate/README.txt">
  <summary><span>Review the README and usage examples</span><small>TEXT // SETUP AND OPERATION</small></summary>
  <pre aria-live="polite"><code>Open this panel to load the usage guide.</code></pre>
</details>
