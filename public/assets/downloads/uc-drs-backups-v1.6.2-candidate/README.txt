UC DRS BACKUP CONFIGURATION
v1.6.2 revision 5 | Testing candidate | 2026-11-19

PURPOSE
Configure Cisco UC backup devices and weekly/monthly schedules consistently
across separate managed networks. Use a profile for each network and its SFTP
server. Preview optional schedule/device cleanup and additions, save the plan,
then apply those selections after checking the current appliance state.

The script configures DRS. It does not start backup or restore jobs. Existing
names are preserved unless you explicitly select their deletion. A name match
is not proof that all settings match your profile.

QUICK START
1. Extract the ZIP to a local Windows folder and open PowerShell there. Review
   the script and use your organization's execution/signing policy. A UNC share
   may be treated as a remote unsigned-script source under RemoteSigned. The
   tool does not change execution policy or automatically accept SSH host keys.
2. Copy profile-example.json to site-a.json; replace all example values. Start
   with one publisher. Keep passwords out of the profile and command line.
3. Provide working SFTP folders/account, or use the separate Windows setup below.
4. Run preview, review the ordered plan, then apply its saved file:

  .\Set-UC-DRSBackupSchedules-v1.6.2.ps1 -Profile .\site-a.json -LogPath .\preview-001.jsonl
  .\Set-UC-DRSBackupSchedules-v1.6.2.ps1 -Apply -Plan .\preview-001.plan.json -LogPath .\apply-001.jsonl

Use a new output filename each time. -LogPath is optional; default logs and
plans go under %LOCALAPPDATA%\UC-DRS\Logs. The script prints their full paths.
Check the startup revision after copying an update. Revision 5 requires a new
preview; plans from earlier revisions are rejected.

REQUIREMENTS AND ACCOUNTS
- Windows PowerShell 5.1 or PowerShell 7 on Windows.
- SSH access to each publisher/first node and its OS-administrator credentials.
  These are not AXL credentials. Normal UC operations do not require an elevated
  shell if the module and output folder are accessible.
- Posh-SSH 3.x/4.x with the required APIs. If none is installed:

  .\Set-UC-DRSBackupSchedules-v1.6.2.ps1 -InstallDependencies -PoshSshVersion 3.2.7 -Profile .\site-a.json

  This installs the specified version for CurrentUser, then continues preview.
  It does not replace/pin an existing compatible module. First installation can
  prompt for NuGet and PSGallery package approval; global repository trust is
  not required or changed. This switch does not install OpenSSH Server.
  Run it in the PowerShell edition you intend to use; a module installed for
  Windows PowerShell 5.1 may not be available in a fresh PowerShell 7 session.
- SFTP access from every UC node that sends backups, sufficient disk space, and
  a destination account with permission to write to the configured folders.
- Retain the cluster security/encryption password through your usual credential
  process. The script neither collects nor changes that recovery password.

INPUTS
Use -Profile for JSON or -Csv for inventory CSV. With neither, choose Wizard,
CSV or Profile. Target selection offers Add/Edit/Remove/Continue/Cancel. Remove
excludes a target from this run; it does not remove appliance configuration.
Edit re-enters target information. Runs remain interactive.

JSON uses SchemaVersion: 1 and a Targets array. Each target has:
  Site             Stable network/site identifier; separates credential keys.
  Id               Cluster/environment identifier, unique within the site.
  Technology       CUCM, CUC, CER or UCCX.
  Address          Publisher/first-node IPv4, not the SFTP destination.
  Port             SSH port; default 22.
  Username         Appliance SSH/OS administrator username.
  ExpectedNodes    Exact short hostnames separated by semicolons. Blank means
                   discover and review. Missing/extra expected nodes block apply.
  ImpTopology      Discover (default), None, PublisherOnly or Pair. Non-CUCM
                   targets use None or Discover.
  ImpPublisher     Exact IM&P publisher short hostname for PublisherOnly/Pair.
  ImpSubscriber    Exact IM&P subscriber short hostname for Pair.
  Settings         Backup settings below. CSV omits Settings; wizard prompts.

For CUCM plus an IM&P pair, use all four actual names in ExpectedNodes:
  "ExpectedNodes": "cucm-pub;cucm-sub;imp-pub;imp-sub",
  "ImpTopology": "Pair",
  "ImpPublisher": "imp-pub",
  "ImpSubscriber": "imp-sub"

Use the canonical short names and case from authenticated cluster rows, not a
case-varied alias in the processnode footer. IM&P nodes are cluster members,
not separate schedule targets. Unknown roles stop processing.

Settings:
  SftpAddress      Destination IPv4. Must belong to this PC for local setup.
  SftpUsername     Destination account; an enabled LOCAL Windows account for
                   local setup, e.g. cmsbackup rather than DOMAIN\user.
  Retention        1-100; wizard default 2. This input bound does not establish
                   that every appliance accepts every value in the range.
  WeeklyName       Name used for both weekly device and schedule.
  MonthlyName      Name used for both monthly device and schedule; distinct.
  WeeklyPath       Weekly SFTP path, using forward slashes.
  MonthlyPath      Separate monthly SFTP path.
  WeeklyDay        English weekday; default Tuesday.
  WeeklyTime       24-hour HH:mm; default 01:00.
  MonthlyDay       Calendar day 1-28; 0 omits monthly creation.
  MonthlyTime      24-hour HH:mm; default 01:00.

MonthlyName, MonthlyPath and MonthlyTime remain required when MonthlyDay is 0;
they are validated but no monthly folders/device/schedule are created. Monthly
means a calendar day, not an ordinal weekday. Starts are calculated at least two
days after the appliance clock returned by show date. Apply retains those dates
and rejects starts that have already arrived. It never uses the Windows clock
as a fallback for an unrecognized appliance response.

Use a different path for each cluster and frequency. The wizard defaults to:
  SFTPBackups/<Site>/<Id>/<Technology>/Weekly/
  SFTPBackups/<Site>/<Id>/<Technology>/Monthly/
Local setup requires these profile-relative SFTPBackups paths. For example,
SFTPBackups/SiteA/Voice/CUCM/Weekly/ maps beneath the backup user's Windows
profile, not the administrator's. Do not put C:\Users\... in an SFTP path.
Remote SFTP servers can use other supported paths; check their login directory.

To save wizard/CSV selections, add -SaveProfile .\new-site.json. The destination
must be new. Saving occurs before discovery and does not qualify those settings.
Profiles and plans contain no passwords, but expose private infrastructure.

PREVIEW AND PLAN EDITING
For inspection without schedule planning:
  .\Set-UC-DRSBackupSchedules-v1.6.2.ps1 -Profile .\site-a.json -ReadOnly -CredentialMode Never

-ReadOnly writes an audit log but cannot save/forget credentials, save a profile,
install dependencies or send configuration writes. First-contact SSH trust may
still prompt. Verify its fingerprint through a trusted source.

Normal preview discovers nodes, registrations and existing DRS objects. Confirm
the inventory, then review the appliance clock and maintenance menu:
- Add: choose an available action by number, then object numbers. Commas select
  several objects in the order entered. Names retain their exact spelling.
- Edit: choose one planned action and replace it with another available action.
- Remove: choose one or more planned action numbers to remove from the plan.
- Done: keep the ordered actions and continue to additions.
- Cancel: end preview without saving a plan. At numbered prompts, 0 goes back.

Only applicable actions appear. Already-disabled schedules are omitted from
DisableSchedule. Devices still referenced by schedules are omitted from
DeleteDevice. Empty inventories skip maintenance selection entirely.

The display shows the inventory that would result and the ordered actions.
Edits/removals must leave the whole sequence valid. For example, removing a
schedule-deletion action is rejected if a later device deletion depends on it.
Remove both dependent actions together if that is your intent. Nothing is
silently reordered or removed. All planning occurs locally, without CLI writes.

For replacement, add disable actions as needed, schedule deletions, then device
deletions. Choose Yes to include weekly/monthly additions from the profile, or
No for maintenance only. Existing names left in place are marked for review;
the script does not overwrite them or silently enable a disabled schedule.

A complete successful preview saves <log-name>.plan.json. A failed or cancelled
preview saves no plan. -ReadOnly and -WhatIf do not save a plan. Ordinary preview
may offer optional credential storage; -SaveProfile and -InstallDependencies
perform their explicitly requested local actions even without -Apply.

APPLY
Use -Apply -Plan <file>; do not also supply -Profile or -Csv. Apply uses the
saved targets/settings/actions, authenticates, and checks live release,
topology, registrations, DRS objects, timezone and clock/start times. Drift or
altered/incompatible plans stop the target. Create a fresh preview to change
selections; do not edit a plan to bypass checks. Fingerprints detect changes;
they are not signatures or approval tokens.

Review the displayed plan. Disables require confirmation. Each deletion asks
whether you have recorded complete recovery settings and retained credential
access, then requires DELETE <exact-name>. All confirmations and needed SFTP
credentials are collected before the first change for that target. Declining
one cancels that target's sequence. Password entry is not an SFTP login test.

Operations run in the selected order, with readback after each write. A later
failure leaves earlier successful changes in place: there is no automatic
rollback. Targets are processed individually, not as one transaction. Another
administrator's intervening change or unexpected output stops further work.

To inspect the saved apply path without configuration writes:
  .\Set-UC-DRSBackupSchedules-v1.6.2.ps1 -Apply -Plan .\preview-001.plan.json -WhatIf

-WhatIf cannot save credentials/profiles or install dependencies. The separate
legacy mode below applies maintenance immediately and does not use a saved plan:
  .\Set-UC-DRSBackupSchedules-v1.6.2.ps1 -Profile .\site-a.json -ManageExisting -Apply
It creates nothing, requires exact object names and explicit confirmations, and
rejects deletion of referenced devices. Prefer the saved-plan flow for replacement.

VERIFICATION AND CREDENTIAL STORAGE
Creation verifies device name/type, schedule/device association and enabled
status. Named server/path fields are checked when the CLI returns them. The
console lists what was verified and what still needs review. Check features,
recurrence/start time, retention and any unavailable server/path fields in DRS.
Verify a real backup separately. Successful backup does not qualify restore.

-CredentialMode Ask (default) confirms the username before looking up its Windows
Credential Manager entry. You can Use/New/Forget where local writes are allowed.
SSH saving is offered immediately after authentication succeeds, before CLI
startup/discovery. Save success is printed and recorded. Authentication failure
allows one fresh attempt. -CredentialMode Never skips all native-store access.

Keys include site, purpose, IP, port and username, for example:
  UC-DRS/SiteA/ssh/192.0.2.10:22/admin
SSH and SFTP entries are separate. Storage belongs to the current Windows user
on this machine. A different account/machine has a different store; other
software running as that user may access it. Saving never bypasses host-key checks.

For a new SFTP password, the script explains how to verify a manual backup in a
second CLI/DRS session while its prompt remains open. Choose Verified only after
that succeeds, then separately consent to saving the password. Skip is the
default and finishes without saving. A later run will request the password again.
Already-saved credentials do not repeat this prompt. No automatic SFTP probe is
added, and device creation alone is not treated as password validation.

To remove a stored entry without connecting to UC, use Windows Credential
Manager > Windows Credentials and select the intended UC-DRS generic entry.
Never include passwords in profiles, CSVs, command lines or shared log excerpts.

LOCAL WINDOWS SFTP SETUP (OPTIONAL)
Use an elevated 64-bit shell on that site's Windows SFTP server. All selected
targets must use one Site, local SftpAddress and local SftpUsername. Posh-SSH is
not needed for this mode. The backup account must already exist and be enabled;
a dedicated nonadministrator account is recommended.

Preview, then apply after checking the account, folders and permitted sources:
  .\Set-UC-DRSBackupSchedules-v1.6.2.ps1 -Profile .\site-a.json -SetupLocalSftp -SftpRemoteAddress 192.0.2.10,192.0.2.11
  .\Set-UC-DRSBackupSchedules-v1.6.2.ps1 -Profile .\site-a.json -SetupLocalSftp -SftpRemoteAddress 192.0.2.10,192.0.2.11 -Apply

Replace example source addresses with every node that sends backup traffic.
A CIDR such as 192.0.2.0/24 is accepted; Any and /0 are not. Omitted sources are
prompted. Local setup uses its own immediate preview/apply workflow, not -Plan.
Do not combine it with -ReadOnly, -ManageExisting or -InstallDependencies.

Local apply can:
- Install the Windows inbox OpenSSH.Server capability if absent.
- Create a Windows profile for the existing account, resolving its path by SID.
- Create SFTPBackups/subfolders. A new root grants SYSTEM/Administrators FullControl
  and the backup user Modify. Existing ACL entries are preserved, with missing
  user Modify grants added. Deny entries stop the operation. Existing backup
  files are not deleted or recursively re-permissioned.
- Add direct membership in OpenSSH Users when that standard group exists.
- Create UC-DRS-SFTP-<Site> for TCP/22 on the selected local IP, approved source
  IPs/subnets and Domain/Private profiles. A broad default rule created by a fresh
  OpenSSH installation is disabled; pre-existing firewall rules are preserved.
- Set sshd to Automatic and start it if needed, without restarting a running
  service. Check the service and listening process afterward.

It does not create/reset/enable user accounts, grant administrator membership,
rewrite sshd_config, change network profiles, reboot, or configure a remote PC.
Domain/Microsoft/Entra accounts, expired/disabled users, unsafe/reparse paths,
custom SSH installations, Include/chroot/forced-command configurations, unusual
SFTP subsystems and non-22 ports require manual setup or are rejected.

This is ordinary Windows SSH/SFTP, not an SFTP-only jail. Existing access rules,
GPO and broader firewall rules still apply. A Public network profile is not
changed. Feature installation uses approved Windows servicing sources and stops
if a reboot is required. Partial setup is not automatically undone.

"Local configuration verified" confirms folders/grants, service and listener,
not authenticated access. From an allowed client, verify the fingerprint, log in
as the backup user, check each relative path, upload/list/remove a uniquely named
disposable file. Then verify a UC-origin backup; its source and SSH negotiation
may differ from the operator's client.

LOGS, RESULTS AND RECOVERY
Logs are JSONL. -LogPath needs an existing parent and a new filename; relative
paths use the PowerShell working directory. Existing logs/profiles/plans are not
overwritten. Logs contain topology, settings and local paths/ACLs; keep them
private. Secret exchanges are omitted and sensitive text is filtered.

Common results:
  preview_only / whatif_only      No planned configuration writes performed.
  update_needed                  Planned new device/schedule pair.
  inspection_complete            Read-only inspection finished; review coverage.
  registered_features_checked    Registration checks passed, not backup success.
  unverified_existing            Name exists; full settings require review.
  applied_verified_limited       Saved actions completed with CLI readback.
  maintenance_verified           Selected disable/delete verified.
  created_enabled_verified_limited
                                 Pair created/enabled; limited readback as above.
  no_changes                     No executable actions in the saved plan.
  partial_or_unverified          Some outcomes skipped or need review.
  stopped_review_required / blocked
                                 Resolve the reported issue before retrying.
  cancelled                      Operator cancelled selection; no preview saved.
  not_run (backup status)         This script did not start a backup job.

Failure guidance distinguishes these cases for the failed target:
- No writes attempted: correct the issue and make a new preview.
- Earlier verified writes: they remain applied; review current state and preview
  only the remaining work.
- Unresolved write: match write_intent IDs with write_verified_limited IDs.
  write_response alone is not verification. Inspect DRS and any logged
  uncertain_write_readback before retrying. A timeout can follow a successful
  server-side change. The tool attempts one fresh read-only connection, not a
  replay or rollback. Preserve partial pairs and recover from actual state.

Cancellation at target/plan selection is exit 3 with run_cancelled, not a red
PowerShell fault. Exit 1 takes precedence if connection cleanup fails.
Other exit codes: 0 completed/no fatal error (including some declined/no-op
paths); 1 error/blocked target/cleanup failure; 2 partial or unverified apply.
Always review the results; exit 0 does not mean a backup ran or can be restored.
Owned streams/sessions are closed independently in finally. Forced termination
cannot guarantee cleanup. Audit records are not a full recovery export.

For local setup failures, inspect local_setup_plan/intents and completed events.
Installed features, profiles, grants and firewall changes can remain after a
later failure. Do not infer SFTP login success from local_setup_complete.

TROUBLESHOOTING
- Use -Profile (one hyphen) and named options. Settings.SftpAddress is the SFTP
  destination; -SftpRemoteAddress is a firewall source list for local setup only.
- Stale/expired plan: run a new preview. Reapplying a plan is not a safe retry
  mechanism; compare current state, even if names happen to match again.
- Unknown show date/cluster/registration output: keep the log and sanitized raw
  output. The tool stops rather than guessing or treating unknown data as empty.
- unverified_existing: inspect the existing settings. This is not a request to
  delete working configuration or proof a previous backup failed.
- Local address/account errors: use the correct SFTP machine and local account.
  Do not substitute the appliance OS administrator for the backup account.
- Feature install/reboot or custom SSH errors: use normal Windows administration;
  the tool does not change update policy or overwrite an existing SSH setup.
- SFTP permission/path errors: check the authenticated account, login directory,
  deny/group permissions, network profile and SSH/firewall restrictions.

PRODUCT COVERAGE AND TESTING
Candidate adapters: CUCM/CUC/CER 14/15 and UCCX 12.5/15. This does not qualify every
service update or topology. CUCM/IM&P, CER and UCCX registrations are queried for
each discovered node through the publisher. CUC queries only the publisher;
subscribers remain in inventory/ExpectedNodes, not its registration check.
CUCM uses UCM, CDR_CAR and applicable IM_AND_PRESENCE registrations. Missing or
unrecognized required data stops apply. No hidden direct-node connection occurs.
CER 14SU2+ certificate-exchange prerequisites require the normal maintenance
process. External databases/archives/appliances are not implicitly covered.

VALIDATION.txt records results for each revision and environment. Revision 4
passed Windows/CUCM 15 initial creation, two manual backups and full replacement;
revision 2 passed supplied CUCM/CUC 14 previews. These results do not qualify
restore, scheduled firing, other-product apply or native Windows SFTP setup.
Revision 5 passed preview, plan editing and saved-plan replacement on Windows
PowerShell 7.7.0 / Posh-SSH 3.2.7 against CUCM 15.0.1.15900-150. Preview made no
writes; all 12 replacement writes passed the available CLI readback checks.
No new manual backup or restore was run during that revision's test.

Run each offline harness in a fresh process; do not dot-source tests into an
operational shell because they define mocks:
  powershell.exe -NoProfile -File .\Test-UC-DRSBackupSchedules.ps1
  powershell.exe -NoProfile -File .\Test-LocalSftpSetup.ps1
Use pwsh for PowerShell 7. Offline tests make no live connections or native
credential/firewall/feature changes. Recorded results are included in the ZIP.

Package: operator script, README, profile-example.json, targets-example.csv,
two test harnesses, registration-fixtures.json, test results, VALIDATION.txt,
CHANGELOG.txt and SHA256SUMS.txt. Hashes check integrity; they are not signatures.

Primary references:
Windows OpenSSH installation and configuration:
https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse
https://learn.microsoft.com/en-us/windows-server/administration/openssh/openssh-server-configuration
Windows user profile / native credentials:
https://learn.microsoft.com/en-us/windows/win32/api/userenv/nf-userenv-createprofile
https://learn.microsoft.com/en-us/windows/win32/api/wincred/ns-wincred-credentialw
https://learn.microsoft.com/en-us/windows/win32/api/wincred/nf-wincred-credwritew
Posh-SSH:
https://www.powershellgallery.com/packages/Posh-SSH/3.2.7
https://github.com/darkoperator/Posh-SSH
Cisco CUCM/IM&P backup and component guidance:
https://www.cisco.com/c/en/us/td/docs/voice_ip_comm/cucm/im_presence/configAdminGuide/15_0/cup0_b_config-and-admin-guide-15/cup0_b_config-and-admin-guide-1401_chapter_011101.html
https://www.cisco.com/c/en/us/support/docs/unified-communications/unified-communications-manager-im-presence-service/220186-troubleshoot-missing-drf-components-in-t.html
Cisco CER CLI and DRS:
https://www.cisco.com/c/en/us/td/docs/voice_ip_comm/cer/15/english/cli/guide/cer0_b_cisco-emergency-responder-cli-guide-15/cer0_b_cisco-emergency-responder-cli-guide-1251su1_chapter_01.html
https://www.cisco.com/c/en/us/td/docs/voice_ip_comm/cer/15/english/administration/guide/cer0_b_cisco-emergency-responder-administration-guide-15/cer0_b_cisco-emergency-responder-administration-guide-1401_appendix_010010.html
Cisco UCCX DRS:
https://www.cisco.com/c/en/us/td/docs/voice_ip_comm/cust_contact/contact_center/crs/express_15_0/maintain_and_operate/guide/uccx_b_1501_admin-and-operations-guide/uccx_m_1501_backup-and-restore.html

CUCM CLI feature names and Unity Connection publisher-only scope:
https://www.cisco.com/c/en/us/support/docs/unified-communications/unified-communications-manager-callmanager/211975-CUCM-DRS-Backup-and-Restore-Operations-v.html
https://www.cisco.com/c/en/us/td/docs/voice_ip_comm/connection/14/install_upgrade/guide/b_14cuciumg/b_14cuciumg_chapter_01.html
https://www.cisco.com/c/en/us/td/docs/voice_ip_comm/connection/15/install_upgrade/guide/b_15cuciumg/b_15cuciumg_chapter_01.html
