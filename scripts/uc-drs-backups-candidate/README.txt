UC DRS BACKUP CONFIGURATION -- OPERATOR GUIDE
Version 1.6.1 | Testing candidate | Updated 2026-11-15
==================================================

WHAT CHANGED FROM v1.6
----------------------
This is a separate candidate; retain v1.6 and its original profiles/logs.
- UCCX release checks compare the entire major/minor version. 12.5 and 15
  remain candidate families; 12.50/12.51 no longer match the 12.5 rule.
- A declared CUCM environment must include CCM registration on at least one
  exact discovered node. IM&P-only registration cannot satisfy that requirement.
- Existing per-node checks and IM&P publisher/subscriber component checks remain.
- Product/expected-feature mapping is shared by inventory, release and coverage
  validation. No credential, SSH, SFTP setup or mutation sequence was changed.

For the first comparison, use your existing site profile with a NEW log path:
  .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site-a.json -ReadOnly -CredentialMode Never -LogPath .\site-a-v161-inspect-001.jsonl
Then run the normal preview without -Apply. Check the detected release, exact
nodes, required feature registration and proposed DRS objects. If coverage is
blocked, retain sanitized discovery output for review; do not bypass the check.
For a working site SFTP host, these fixes do not require rerunning local setup.
Do not use -ManageExisting for this comparison; it is a separate maintenance mode.

START HERE
----------
Use one profile for each managed network and run local setup on that network's
Windows SFTP server. Begin with one UC publisher before expanding the target list.

The normal sequence is:
  1. Prepare the Windows account and a site-specific JSON profile.
  2. Preview local SFTP setup, then apply it on the Windows SFTP server.
  3. Test SFTP access as the backup account.
  4. Inspect one UC publisher and its node/feature inventory.
  5. Preview the DRS devices and schedules, then apply approved additions.
  6. Check the full configuration in DRS and verify an actual backup.
  7. Repeat for other clusters in this site, then use a separate profile elsewhere.

No -Apply means no system/configuration changes from the setup plan. Audit logs
are still created. UC preview can offer optional credential storage, and an explicit
-SaveProfile writes a nonsecret profile. SSH may also prompt for host-key trust.

This tool configures backup destinations and schedules. It does not run a backup,
perform a restore, or establish that recovery will succeed. v1.6.1 has offline test
coverage; Windows provisioning and live appliance behavior still need testing.

CONTENTS
--------
  A. What runs where, and which account to use
  B. Prepare one site's profile
  C. Set up the local Windows SFTP server
  D. Inspect, preview and configure UC
  E. Verify the result and use the next site
  F. Input field reference
  G. Credentials and host-key trust
  H. Results, logs and interrupted work
  I. Existing configuration and explicit maintenance
  J. Troubleshooting
  K. Testing, limitations and references


A. WHAT RUNS WHERE, AND WHICH ACCOUNT TO USE
==========================================

Local SFTP setup:
  Computer: that site's Windows SFTP server.
  Shell: elevated 64-bit Windows PowerShell 5.1 or PowerShell 7 on Windows.
  Account running PowerShell: a Windows administrator authorized to install the
    OpenSSH Server feature and configure folders, permissions, service and firewall.
  Backup account: an existing enabled LOCAL Windows account, for example cmsbackup.
    It supplies the SFTP username in the profile. It does not need to be the
    administrator running the script. Prefer a dedicated nonadministrator account.
  Dependency: Windows inbox OpenSSH Server capability; Posh-SSH is NOT needed here.

UC inspection and schedule configuration:
  Computer: a Windows operator machine with SSH access to that site's publishers.
    It can be the same Windows SFTP server. Elevation is not inherently required
    for these modes when the dependencies and log directory are accessible.
  UC credential: the appliance's SSH/OS administrator account, not an AXL account.
  SFTP credential: the local backup account on the destination Windows server.
    It is requested only when creating a DRS network device.
  Dependency: Posh-SSH 3.x or 4.x with the required APIs.

The DRS cluster security/encryption password is a separate recovery requirement.
This script neither collects nor changes it. Keep it through your normal approved
credential-management process.

Before starting:
- Extract the ZIP and open its contained UC-DRS-v1.6.1 folder. Commands below assume
  that folder is the PowerShell working directory.
- Use your organization's approved script-execution/signing policy. This guide
  does not require disabling execution-policy or host-key checks.
- Confirm the Windows SFTP address and intended UC source IPs/subnets. Include
  subscriber nodes that originate backup traffic, not just publishers.
- Have the existing local backup account and password available. Local setup does
  not create users, reset passwords, enable disabled users or change expiry policy.
- Confirm disk space and the intended retention value for this site's backups.
- Keep real site profiles and audit logs private; they describe your environment.


B. PREPARE ONE SITE'S PROFILE
============================

Recommended first run: start from profile-example.json.

1. Save a copy as a NEW filename such as site-a.json.
2. Edit the values for this site using a text editor. Do not run with the example
   addresses; 192.0.2.x values are documentation examples.
3. Keep just one target initially. Add other target objects after the first test.
4. Save valid JSON: quoted property names/strings, no comments or trailing commas.

Replace these values first:
  Site              Stable managed-network identifier, e.g. SiteA.
  Id                Cluster/environment identifier, e.g. Voice.
  Technology        CUCM, CUC, CER or UCCX.
  Address           UC publisher/first-node IPv4 address. This is NOT the SFTP IP.
  Username          SSH/OS administrator username ON THAT UC APPLIANCE.
  ExpectedNodes     Every expected node's exact short hostname, separated by ;.
  ImpTopology       None, PublisherOnly, Pair or Discover (details in section F).
  Settings.SftpAddress
                    IPv4 address of this site's Windows SFTP server.
  Settings.SftpUsername
                    Existing LOCAL Windows backup account, e.g. cmsbackup.
  Settings.WeeklyPath / MonthlyPath
                    Relative SFTP paths beneath that account's home directory.
  Remaining Settings
                    Device/schedule names, retention, weekday/time and monthly day.

Example mapping, assuming Windows reports the account profile as C:\Users\cmsbackup:

  Site:             SiteA
  Id:               Voice
  Technology:       CUCM
  SftpUsername:     cmsbackup
  WeeklyPath:       SFTPBackups/SiteA/Voice/CUCM/Weekly/
  Windows folder:   C:\Users\cmsbackup\SFTPBackups\SiteA\Voice\CUCM\Weekly\

Do not put C:\Users\... in WeeklyPath/MonthlyPath when using local setup. These
fields use forward-slash relative SFTP paths. Windows profile paths are resolved
from the selected user's SID; the script does not assume a particular folder name.

Other input choices:
- Run without -Profile or -Csv to choose Wizard, CSV or Profile interactively.
- The selection screen supports Add, Edit, Remove, Continue and Cancel. Edit
  re-enters a target's information; it is not an in-place JSON editor. Remove
  removes a target from this run only. It never deletes a remote configuration.
- targets-example.csv inventories targets; it does not contain schedule settings.
  Missing backup settings are collected by the wizard.
- All input paths remain interactive. This is not an unattended task runner.

To build and save a profile through the wizard while previewing LOCAL setup:
  .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -SetupLocalSftp -SaveProfile .\site-a.json -SftpRemoteAddress 192.0.2.0/24

Or start that same workflow from a prepared CSV:
  .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Csv .\targets.csv -SetupLocalSftp -SaveProfile .\site-a.json -SftpRemoteAddress 192.0.2.0/24

These commands run on the SFTP server in an elevated shell. They save the profile
and preview local setup without contacting UC. Replace the example source subnet.
The output profile filename must be NEW. SaveProfile runs before discovery/setup
and therefore does not mean the saved configuration has passed live verification.
For later edits, edit a working copy yourself or save to another new filename.


C. SET UP THE LOCAL WINDOWS SFTP SERVER
======================================

Run on the SFTP server in an elevated 64-bit PowerShell window.
All selected targets must use one Site, one SftpAddress and one SftpUsername.
The SftpAddress must be a preferred IPv4 address assigned to this Windows machine.

Preview:
  .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site-a.json -SetupLocalSftp -SftpRemoteAddress 192.0.2.0/24

For exact source IPs instead of a subnet:
  .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site-a.json -SetupLocalSftp -SftpRemoteAddress 192.0.2.10,192.0.2.11,192.0.2.12

Check the displayed account, address, folders and firewall scope. Then apply:
  .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site-a.json -SetupLocalSftp -SftpRemoteAddress 192.0.2.0/24 -Apply

The script presents the plan again and asks before applying it. Use the actual
approved IPs/subnets for this site. If SftpRemoteAddress is omitted, it is prompted.
Do not combine this mode with -ReadOnly, -ManageExisting or -InstallDependencies.
For a nonmutating local preview, simply omit -Apply.

What local setup can change:
- Install the inbox OpenSSH.Server Windows capability if absent. Windows servicing
  must be able to obtain the feature through your approved source.
- Create a Windows profile for the existing backup account if it has never had one.
- Create SFTPBackups and required subfolders below that account's profile.
- Give a NEW SFTPBackups root a private ACL: SYSTEM/Administrators FullControl and
  the backup account Modify. Existing ACL entries are preserved, with a user
  Modify grant added where missing. Deny entries stop the permission operation.
  Existing backup files are not recursively re-permissioned or removed.
- Add the account to the standard OpenSSH Users group if Windows provides it and
  direct membership is absent. It does not add the account to Administrators.
- Create UC-DRS-SFTP-<Site>, allowing TCP/22 on the selected local address from the
  supplied sources, on Domain/Private firewall profiles. Any and /0 are rejected.
- Disable the broad default OpenSSH firewall rule created by a FRESH installation.
  Pre-existing firewall rules are preserved, even if they allow broader access.
- Set sshd to Automatic and start it if needed. An already-running service is not
  restarted. The service and its listening process are checked afterward.

Boundaries to review:
- This enables ordinary Windows SSH/SFTP, not an SFTP-only jail.
- Existing SSH access restrictions and broader firewall/GPO policy still apply.
  Public-profile networks are not automatically enabled or reclassified.
- Existing custom SSH installations, Include/chroot/forced-command configuration,
  nonstandard SFTP subsystem configuration or non-22 ports require manual setup.
  The script does not rewrite sshd_config or install a competing SSH server.
- Local setup rejects domain/Microsoft/Entra accounts, disabled/expired accounts,
  unsafe paths, reserved Windows names and existing reparse points/files.
- If Windows requests a reboot, setup stops. It never reboots the computer.

Success message: "Local configuration verified."
This establishes configured folders/grants, service state and a listener. It does
NOT prove that the backup account can log in or that UC nodes can reach the server.

Before proceeding, use an SFTP client from a permitted client/context to:
  1. Verify the server fingerprint against a trusted source.
  2. Log in using the backup account, not the Windows administrator account.
  3. Confirm the home directory and each configured relative backup path.
  4. Upload a uniquely named disposable test file to each destination, list it,
     and remove only that test file. Never overwrite an existing backup as a test.

A successful client test still needs a real UC backup test because its source
address, SSH negotiation and permissions may differ from the operator's client.


D. INSPECT, PREVIEW AND CONFIGURE UC
==================================

D1. Make Posh-SSH available on the operator machine
--------------------------------------------------
Local Windows setup uses native tools; UC connections use Posh-SSH.
If a compatible module is already installed, the script uses it and logs its version.
If none is installed, follow your approved installation process or explicitly run:
  .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -InstallDependencies -PoshSshVersion 3.2.7 -Profile .\site-a.json

This installs the specified version for CurrentUser only when no compatible 3.x/4.x
module is present, THEN continues into UC preview. It is not an install-only command
and does not pin/replace an existing compatible installation. It does not silently
change PSGallery trust or execution policy. Native OpenSSH Server installation is
controlled by -SetupLocalSftp, not -InstallDependencies.

D2. Inspect one publisher
------------------------
  .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site-a.json -ReadOnly -CredentialMode Never

Choose the intended target(s) and Continue. Supply UC SSH/OS credentials.
Review product/release, every discovered node, registered features/components,
and existing DRS devices/schedules. No SFTP password is requested in this mode.

-ReadOnly performs remote inspection and writes an audit log. It cannot save a
profile, install dependencies or save/forget credentials. Posh-SSH may still prompt
for first-contact host-key trust. Verify that fingerprint before accepting it.

D3. Preview DRS additions
------------------------
  .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site-a.json

Check the inventory and features. Enter the date/time shown by the UC "show date"
response in yyyy-MM-dd HH:mm format and confirm its displayed timezone. Scheduling
uses that node-local wall clock, not the Windows computer's timezone.

Review both proposed device/schedule names, SFTP paths, retention and recurrence.
No UC configuration writes occur without -Apply. Default CredentialMode Ask may
offer optional credential saving after authentication; see section G.

D4. Apply approved additions
----------------------------
  .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site-a.json -Apply

Apply performs fresh discovery and preview; it does not replay a saved approved
plan. After your confirmation it rechecks the listed configuration, creates new
network devices and schedules, enables them, and reads back the available fields.
It requests the SFTP account password when a new network device is actually needed.

Optional WhatIf run:
  .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site-a.json -Apply -WhatIf

WhatIf still connects and writes logs but suppresses planned configuration writes
and credential saves. It cannot be combined with SaveProfile or dependency install.


E. VERIFY THE RESULT AND USE THE NEXT SITE
=========================================

For the first test, use a reviewed destination and unused device/schedule names.
If Probe_Weekly/Probe_Monthly already exist, inspect them first; do not delete them
just to obtain a green result from this tool.

After application:
1. Open DRS and verify the COMPLETE device and schedule settings, especially
   feature selection, start time, recurrence, retention and destination credentials.
2. Perform an authorized backup through the normal DRS workflow. The script does
   not launch it. Check the result for every expected node and component.
3. Confirm the backup files exist at the intended SFTP destination.
4. Retain the profile, audit log and backup result with that site's operational
   records. Restore qualification remains a separate approved exercise.
5. Rerun a preview to inspect existing state. Existing names are reported as
   unverified_existing; name matches alone cannot establish full settings.
6. Add the next cluster to this site's profile and repeat the checks.

For the next managed network, use a separate profile and run local setup on ITS
Windows SFTP server. Change Site, endpoints, account, expected nodes, paths and
allowed source addresses. Do not carry over a site's secrets or assume a reused
private IP identifies the same server. Credential keys include the site identity.


F. INPUT FIELD REFERENCE
=======================

The JSON document has SchemaVersion: 1 and a Targets array. Copy a target object
inside that array for additional clusters; use a unique Id within the Site.
Unknown fields, duplicate site/IDs and duplicate endpoints within a site are rejected.

Target fields (CSV headers or JSON target properties):
  Site             Required. Managed-network identifier.
  Id               Required. Environment/cluster identifier.
  Technology       Required. CUCM | CUC | CER | UCCX.
  Address          Required. Publisher/first-node IPv4. IPv6/hostnames unsupported.
  Port             Optional SSH port; defaults to 22. Not the SFTP port.
  Username         Required UC SSH/OS username.
  ExpectedNodes    Optional semicolon-separated EXACT short hostnames, including
                   CUCM subscribers and attached IM&P nodes. With a supplied list,
                   missing or extra nodes block apply. Without it, review discovery.
  ImpTopology      None | PublisherOnly | Pair | Discover; default Discover.
                   For non-CUCM targets use None or Discover.
  ImpPublisher     Exact IM&P publisher short hostname; required for PublisherOnly
                   and Pair. It is not another schedule target.
  ImpSubscriber    Exact IM&P subscriber short hostname; required for Pair.
  Settings         JSON-only nested backup settings, or collected by the wizard.

IM&P Discover can cover additional nodes when topology exposes their DBPub/DBSub
roles. Unknown roles block apply. The script does not infer a publisher from a DB
component that might itself be missing. Exact hostname case matters.

Settings fields:
  SftpAddress      Required SFTP server IPv4; must be LOCAL for -SetupLocalSftp.
  SftpUsername     Required destination account. For local setup: an enabled local
                   Windows account using a simple name such as cmsbackup, not DOMAIN\user.
  Retention        Required integer 1-100; default wizard value 2. This is the tool's
                   input bound, not proof that every appliance accepts the whole range.
  WeeklyName       Required weekly device AND schedule name.
  MonthlyName      Required monthly device AND schedule name; distinct from WeeklyName.
  WeeklyPath       Required destination path. Local setup requires SFTPBackups/...
                   relative to the backup user's profile.
  MonthlyPath      Required, distinct destination path. Same local-setup rule.
  WeeklyDay        Defaults to Tuesday; use an English weekday name.
  WeeklyTime       Defaults to 01:00; 24-hour HH:mm in the UC node's timezone.
  MonthlyDay       Defaults to 1; values 1-28, or 0 to OMIT monthly creation.
  MonthlyTime      Defaults to 01:00; 24-hour HH:mm in the UC node's timezone.

Keep MonthlyName, MonthlyPath and MonthlyTime in the profile even when MonthlyDay
is 0: input validation still checks them, but no monthly folders/device/schedule
are created. Monthly recurrence is a calendar date, not an ordinal weekday.
Starts are calculated at least two days after the confirmed UC node clock.

Default folders use SFTPBackups/<Site>/<Id>/<Technology>/Weekly/ and Monthly/.
Different environments must not share a backup destination path in one run.
Custom paths may be used for existing remote SFTP infrastructure, but local setup
supports only the documented profile-relative layout and port 22.


G. CREDENTIALS AND HOST-KEY TRUST
================================

Default -CredentialMode Ask:
- Offers a saved credential for the exact site/purpose/IP/port/username key.
- Lets you choose Use, New or Forget where local writes are allowed.
- Offers to save a newly validated SSH credential after authentication succeeds.
- Allows one fresh credential attempt after an authentication rejection.

-CredentialMode Never avoids all native credential-store reads/writes and prompts.
This is useful for an initial test or a shared operator computer.

Storage: Windows Credential Manager, Generic Credentials, current Windows user
on the same machine. Example key:
  UC-DRS/SiteA/ssh/192.0.2.10:22/admin

SSH and SFTP use separate keys. Credentials do not roam between machines or users.
Running PowerShell as a different administrator uses that administrator's store.
Other software running as that same Windows user may access its credentials.

New SFTP credentials are not treated as validated merely because a DRS device was
created. The script only offers to save them after the operator confirms a real
successful backup using that account, followed by explicit permission to save.
If you have not verified that backup, answer No and expect another prompt next time.

To forget an entry without connecting to UC, use Windows Credential Manager >
Windows Credentials and remove the intended UC-DRS generic entry. Never put a
password in the CSV, JSON, command line, a public log attachment or the blog post.

Saved credentials do not bypass SSH host-key checks. A changed key needs trusted
verification through the normal operational process, not automatic acceptance.


H. RESULTS, LOGS AND INTERRUPTED WORK
====================================

Default log location:
  %LOCALAPPDATA%\UC-DRS\Logs\UC-DRS-<timestamp>-<id>.jsonl

To choose a location, use -LogPath with a NEW filename and an existing parent:
  .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site-a.json -ReadOnly -LogPath .\site-a-inspect-001.jsonl

A new file is required on every run. Existing logs are never overwritten or appended.
Logs contain topology, configuration, and local setup paths/ACLs. Keep them private.
Secret-exchange responses are omitted, and sensitive text is sanitized.

Common UC results:
  update_needed                     Planned new device/schedule pair; not applied yet.
  inspection_complete               Read-only inspection completed; review coverage too.
  preview_only / whatif_only         No planned UC configuration write performed.
  registered_features_checked       Registration checks passed; not backup success.
  unverified_existing               Existing names found; full settings remain unverified.
  created_enabled_verified_limited   Success responses plus name/type/association/enabled
                                    readback. Visible device server/path also checked.
  partial_or_unverified              Review individual outcomes and existing settings.
  stopped_review_required / blocked Stop and resolve the reported issue before retrying.
  not_run (BackupExecutionStatus)    The script did not execute a backup.

Features, timing, retention and credentials still need DRS review after limited
readback. A name match is intentionally not called already_ok.

For interrupted or failed UC writes:
1. Keep the log and identify the target and last action. Match each write_intent Id
   to its write_verified_limited Id; write_response alone is not verification.
2. Review uncertain_write_readback if present. The script attempts one fresh
   read-only connection after an unresolved write, never a blind replay.
3. Inspect the actual device/schedule in DRS. A timeout can occur after acceptance.
4. Decide the specific recovery action using current state and full settings.
5. Rerun with a new log only after reconciliation. Partial pairs are preserved.

For interrupted local setup:
- Review local_setup_plan, local_setup_intent, local_capability_result,
  local_profile_created, local_folder_intent/local_folder_verified,
  local_ssh_group_verified and local_setup_complete as applicable.
- An installed feature, profile, group membership, folder or grant can remain after
  a later failure. Inspect current state before retrying; there is no automatic
  uninstall, ACL rollback or reboot.
- local_setup_complete establishes local configuration, not successful SFTP login
  or a successful UC backup. A cancelled/previewed run has no such completion event.

Exit codes:
  0  No detected fatal error in the chosen workflow. Includes previews and some
     operator-declined/no-op paths; inspect output rather than treating 0 as proof
     that changes were made or a backup is recoverable.
  1  Error, stopped target, blocked coverage or cleanup failure.
  2  UC apply reached partial/skipped/unverified per-operation results.

Owned streams and sessions are closed in finally, with independent cleanup attempts.
Forced process termination cannot guarantee remote session cleanup. Neither UC
configuration nor local Windows setup is transactional. There is no automatic
rollback or restore, and the log is not a standalone recovery package.


I. EXISTING CONFIGURATION AND EXPLICIT MAINTENANCE
=================================================

Normal setup preserves existing names, even when a schedule is disabled. It cannot
verify every field from CLI list output and will not replace an existing object
just to match a proposed profile.

If an intentional disable/delete is required, use the separate maintenance mode:
  .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site-a.json -Apply -ManageExisting

This mode creates nothing new. Select the exact object. Disable defaults to No;
deletion requires confirmation that full recovery settings were recorded, followed
by typing DELETE <exact-name>. Referenced devices cannot be deleted. Other listed
objects are compared before/after; wildcard deletion is not supported.

Record complete settings and retain access to credentials before deletion. List
snapshots alone cannot recreate every field. Do not use deletion as a routine way
to silence unverified_existing on a working backup configuration.


J. TROUBLESHOOTING
=================

"Posh-SSH ... missing"
  Use the approved module-install process or the explicit dependency command in D1.
  That switch does not install Windows OpenSSH Server.

"Local ... requires an elevated 64-bit PowerShell window"
  Reopen PowerShell as Administrator ON the site's SFTP server. This requirement
  also applies to capability inspection during local setup preview.

"SFTP address is not ... on this Windows computer"
  Check Settings.SftpAddress and the host you are using. Local setup cannot provision
  a remote Windows server; move to that server or use its normal management process.

Local account missing, disabled, expired or wrong source
  Correct the account/profile input or resolve its state through normal Windows
  administration. Do not substitute the UC SSH username for the local SFTP username.

OpenSSH feature installation fails / restart required
  Inspect Windows servicing and approved feature-source availability. The script
  does not change update policy or reboot. Resolve the condition and inspect state
  before rerunning.

Custom SSH installation/configuration or different same-name firewall rule
  Review that existing setup manually. The script does not overwrite it. An active
  Public network profile, GPO, other firewall or SSH access restriction can still
  block SFTP after the tool creates its own scoped rule.

Permission denied / missing SFTP folder after local setup
  Confirm which account actually logged in, its SFTP home and the relative path.
  Review existing parent/group/deny permissions and SSH restrictions. A configured
  Modify grant is not a complete authenticated access test. Test a disposable file.

Missing node/component or unrecognized CLI output
  Verify inventory, hostname case, product/release and registration output. The
  parser stops rather than treating incomplete data as an empty configuration.
  Preserve the log and provide sanitized read-only output for investigation.

unverified_existing on a rerun
  Expected when names already exist. Review the actual settings in DRS. This is
  not a request to delete the objects or evidence that the previous backup failed.

Log/profile file already exists
  Use a new output filename. Existing evidence and profiles are preserved.


K. TESTING, LIMITATIONS AND REFERENCES
======================================

Candidate adapters: CUCM/CUC/CER 14 and 15; UCCX 12.5 and 15. These are not blanket
qualifications of every service update or topology. The operator selects the
technology, and feature registration is checked against it.

Each discovered node is queried through the publisher with:
  utils disaster_recovery show_registration <exact-hostname>

If that product/release cannot return the required node registrations, the target
stops. There is no hidden direct-node connection or automatic credential reuse.
CUCM IM&P checks use documented publisher/subscriber component baselines; they do
not repair registrations or prove every release-specific component complete.
Other products enumerate registrations and check expected feature presence.
Independent external databases, archives or appliances are not implicitly covered.
CER 14SU2+ certificate-exchange prerequisites need the normal maintenance workflow.

Recorded validation: 106 core checks and 53 local-setup checks passed on PowerShell
7.7.0/Linux. Inputs and remote/native operations are synthetic or mocked. Native
credential/profile wrappers compiled, but Windows APIs were not exercised.

To run the offline checks, use a FRESH PowerShell process for EACH harness:
  powershell.exe -NoProfile -File .\Test-UC-DRSBackupSchedules.ps1
  powershell.exe -NoProfile -File .\Test-LocalSftpSetup.ps1

Use pwsh instead of powershell.exe to run with PowerShell 7. The tests make no live
connections, install no features, and do not change native credentials or firewall.
Do not dot-source the test harnesses into an operational session; they define mocks.

Still to qualify: Windows PowerShell 5.1 runtime, actual Windows provisioning and
credential/ACL/firewall behavior, real Posh-SSH/appliance exchanges, SFTP access,
live configuration changes, backup completion and restore fidelity.

Package contents:
  Set-UC-DRSBackupSchedules-v1.6.1.ps1   Operator script; built-in Get-Help examples.
  README.txt                         This guide.
  profile-example.json               Nonsecret profile template.
  targets-example.csv                Fictional inventory template.
  Test-UC-DRSBackupSchedules.ps1       Offline core harness.
  Test-LocalSftpSetup.ps1              Offline local setup harness.
  core-test-results.txt               Recorded core results.
  local-setup-test-results.txt         Recorded local setup results.
  VALIDATION.txt                     Evidence and untested boundaries.
  CHANGELOG.txt                      Changes relative to v1.6.
  SHA256SUMS.txt                     File integrity hashes, not a signing certificate.

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
