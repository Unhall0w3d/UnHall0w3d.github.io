---
title: "RUCKUS SmartZone Backup Retriever"
layout: single
classes: wide
date: 2026-07-01T08:00:00-05:00
excerpt_separator: "<!--more-->"
categories:
  - PowerShell
  - RUCKUS
  - Automation
tags:
  - ruckus
  - smartzone
  - vsz
  - powershell
  - backup
  - automation
---

## Because Of Course Backups Got Weird

There are some tasks that sound simple until they run head first into the real world. SmartZone backups are one of those things.

The normal answer is something along the lines of “just configure the controller to send the backup somewhere.” FTP, SFTP, remote server, done. Beautiful. Clean. A perfectly reasonable answer in a perfectly reasonable world.

Naturally, that was not the world I was working in.<!--more-->

The use case here was a remote client environment with an on-prem jumpbox / multi-use Windows server. The server was already in place and could reach the RUCKUS SmartZone / vSZ controller over HTTPS, but we did not have a good option to allow inbound FTP or SFTP to that server from the SmartZone side. Opening inbound file transfer into the environment just so backups could be pushed at it was not something I was interested in doing.

So instead of having SmartZone push backups to the server, I wanted the server to pull the backups from SmartZone. That turned into this:

[RUCKUS SmartZone Backup Retriever](https://github.com/Unhall0w3d/ruckus-backup-retriever)

A PowerShell script that logs into SmartZone / vSZ over HTTPS, finds available backups, downloads them locally, writes status files, and can be run on a schedule.

As usual, the solution is simple once you have already spent the time finding the parts that are not.

## What Are We Solving?

The problem statement was pretty specific:

- A Windows jumpbox already exists at the remote site.
- The jumpbox can reach SmartZone / vSZ over HTTPS.
- We do not want to open inbound FTP/SFTP to the jumpbox.
- We still need copies of SmartZone backups stored locally.
- The process should be repeatable and schedulable.
- Credentials should not be sitting around in a plain text file like it is 2003 and everyone has given up.

The general idea became:

1. Authenticate to the SmartZone web interface.
2. Use the same API-style endpoints the UI uses to list backups.
3. Download the backup files from the Windows server.
4. Store them in timestamped folders.
5. Track run status with JSON.
6. Retain a reasonable number of successful backup runs.
7. Let Windows Task Scheduler handle the timing.

## The Script

The script is named:

```powershell
Get-RuckusSmartZoneBackup.ps1
```

It is written for Windows PowerShell and is intended to run from a Windows system that can reach the SmartZone / vSZ HTTPS interface.

The first run can be used to establish the saved settings and credential. For example:

```powershell
.\Get-RuckusSmartZoneBackup.ps1 -BaseHost smartzone.example.com -OutputRoot "D:\SmartZoneBackups" -SkipClusterBackups -MaxDownloadPerCategory 1
```

That is the safer first test because it skips cluster backups and limits downloads to one backup per category. Cluster backups can be large, and there is no prize for accidentally downloading a huge file while proving authentication works.

After the first successful run, the saved configuration and credential can be reused:

```powershell
.\Get-RuckusSmartZoneBackup.ps1
```

The script stores its settings under the current user's application data directory and stores the credential using PowerShell credential export. On Windows, that means the credential is protected using DPAPI and tied to the same Windows user and machine.

That last part matters. If the scheduled task runs as a different Windows user, it will not be able to decrypt the saved credential from another account. Security is useful, but it does enjoy making sure you know it is there.

## How It Works

At a high level, the script does the following:

1. Loads saved settings if they exist.
2. Prompts for anything missing, such as the SmartZone host, output path, or credentials.
3. Authenticates to the SmartZone / vSZ web interface.
4. Captures the required session information and CSRF token.
5. Lists available backup files.
6. Downloads selected backups.
7. Writes per-run and latest-run status JSON files.
8. Applies retention to older successful backup folders.

The downloaded files are stored in timestamped folders under the output root selected by the user.

Example structure:

```text
D:\SmartZoneBackups
└── 20260701-060000
    ├── run-status.json
    ├── logs
    ├── SystemConfiguration
    ├── SwitchConfiguration
    └── Cluster
```

A latest status file is also written at the root:

```text
D:\SmartZoneBackups\last-run-status.json
```

The idea is that a human can look in the timestamped run folder when they need detail, while automation or monitoring can look at the latest status file if needed.

## Useful Options

The script has a few options that are worth knowing about.

```powershell
-BaseHost smartzone.example.com
```

Specifies the SmartZone / vSZ host.

```powershell
-OutputRoot "D:\SmartZoneBackups"
```

Specifies where backup folders should be written.

```powershell
-SkipClusterBackups
```

Skips cluster backup downloads. Useful for testing or for environments where those backups are especially large.

```powershell
-MaxDownloadPerCategory 1
```

Limits how many backups are downloaded from each category. This is useful for first-run testing.

```powershell
-KeepBackupRuns 1
```

Controls how many successful backup run folders are retained.

```powershell
-UpdateCreds
```

Forces the script to prompt for and save updated credentials.

```powershell
-ResetSavedConfig
```

Clears saved settings so the script can be reconfigured.

There are other parameters in the script, but those are the ones most likely to matter when getting started.

## Scheduling It

Once the script has been tested manually, it can be scheduled with Windows Task Scheduler.

An example helper script is included in the repository under:

```text
examples\Register-SmartZoneBackupTask.ps1
```

The important thing is that the scheduled task should run as the same Windows user that created the saved credential.

A typical scheduled action would be:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "C:\Scripts\Get-RuckusSmartZoneBackup.ps1"
```

In my case, the goal was to run it at a predictable time, let it pull the backups, write the results, and keep only the newest successful run unless configured otherwise.

Simple. Repeatable. Less exciting than a firewall exception for inbound file transfer, which is exactly the point.

## Things Worth Thinking About

A few design choices ended up mattering more than the initial “download the file” part.

### Credential Storage

The script needed to save credentials for scheduled operation, but saving credentials in plain text was not acceptable.

The script uses PowerShell credential export so the credential is encrypted on Windows using DPAPI. That keeps it bound to the Windows user and machine that created it.

That does mean you need to be intentional about which account runs the setup and which account runs the scheduled task. If those are different accounts, the scheduled task will not be able to use the saved credential.

### Pull Instead Of Push

The whole point of this was to avoid inbound FTP/SFTP to the server.

By pulling over HTTPS from the jumpbox, the firewall story becomes cleaner. The server only needs outbound access to SmartZone / vSZ over HTTPS. The backup destination stays local to the server or whatever storage path that server can already reach.

### Retention

Downloading backups is useful. Downloading backups forever is how you eventually create a storage problem and then pretend to be surprised by it.

The script writes each run to its own timestamped folder and can retain only a configured number of successful backup runs. Failed or partial runs are treated more cautiously so that troubleshooting data is not immediately discarded.

### Status Files

Each run writes a `run-status.json` file inside the timestamped run folder. The script also writes a `last-run-status.json` file at the output root.

That makes it easier to see what happened during the most recent run without opening every folder and playing forensic archaeologist.

## Useful API Endpoints

The work relies on endpoints used by the SmartZone / vSZ web interface.

These are the main ones that were useful.

System configuration backup list:

```text
GET /wsg/api/scg/backup/config
```

System configuration backup download:

```text
GET /wsg/api/scg/backup/config/download?backupUUID=<backupUUID>&timezone=240
```

Cluster backup list:

```text
GET /wsg/api/scg/backup/cluster
```

Cluster backup download:

```text
GET /wsg/api/scg/backup/cluster/downloadagent?bladeUUID=<bladeUUID>&backupUUID=<backupID>&timezone=240
```

Switch configuration backup list:

```text
POST /switchm/api/v13_1/switchconfig
```

Switch configuration backup download:

```text
GET /switchm/api/v13_1/switchconfig/download/<id>
```

The switch configuration endpoints also require a service ticket associated with the current session. The script handles that as part of the login/session flow.

These endpoints may vary across versions. This was built and tested against the environment I had access to, so if you are working with a different version, test carefully before trusting it with anything important. Software versions are where assumptions go to get mugged.

## Where To Get It

The repository is here:

[https://github.com/Unhall0w3d/ruckus-backup-retriever](https://github.com/Unhall0w3d/ruckus-backup-retriever)

The repo includes:

- The PowerShell backup script
- A README
- Rollout notes
- An example scheduled task registration script
- Security notes

If this solves a problem for you, pull it down and use it.

If it does not work in your environment, open an issue with details. SmartZone / vSZ version, what you were trying to download, what failed, and sanitized output are all helpful.

Please do not paste credentials, session cookies, customer hostnames, public IPs, or anything else into an issue unless you enjoy turning a troubleshooting request into an incident response exercise.

## Finishing Up

This script came out of a pretty ordinary operational problem: backups needed to exist somewhere useful, but the normal push model did not fit the environment.

Rather than opening inbound file transfer to a remote jumpbox, this pulls the backups over HTTPS using the existing SmartZone / vSZ web/API behavior. It saves the files locally, stores credentials in a Windows-protected way, writes status files, and can be scheduled to run predictably.

It is not fancy. It is not magic. It is just one of those tools that exists because the clean diagram and the real network were not on speaking terms.

Which, honestly, is how a lot of useful scripts are born.
