#Requires -Version 5.1

<#
.SYNOPSIS
    Preview and configure Cisco UC DRS schedules (v1.6.1 testing release).
.DESCRIPTION
    Windows operator tool for CUCM, Unity Connection, CER and UCCX first nodes.
    Default: inspect, discover node registrations and preview; -Apply permits writes.
    Never deletes/replaces devices or schedules automatically. Existing settings
    which the CLI cannot read back remain UNVERIFIED, even if names match.
    -ManageExisting -Apply is a separate, explicit disable/delete workflow.
    Native Windows Credential Manager storage is optional and scoped by site,
    purpose, IP, port and username. No passwords belong in profiles or CSVs.
    -SetupLocalSftp detects the inbox OpenSSH Server capability and enabled local
    SFTP account. Preview by default; -Apply installs/configures it and creates
    profile-relative backup folders. Run elevated on the site SFTP Windows host.
    Dot-source this file to load functions without prompting or connecting.
.EXAMPLE
    .\Set-UC-DRSBackupSchedules-v1.6.1.ps1
.EXAMPLE
    .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Csv .\targets.csv -SaveProfile .\site.json
.EXAMPLE
    .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site.json -Apply
.EXAMPLE
    .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site.json -Apply -WhatIf
.EXAMPLE
    .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -InstallDependencies -PoshSshVersion 3.2.7
.EXAMPLE
    .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site.json -SetupLocalSftp -SftpRemoteAddress 192.0.2.0/24
.EXAMPLE
    .\Set-UC-DRSBackupSchedules-v1.6.1.ps1 -Profile .\site.json -SetupLocalSftp -SftpRemoteAddress 192.0.2.0/24 -Apply
.NOTES
    Intended for Windows PowerShell 5.1 / PowerShell 7 on Windows. Requires
    Posh-SSH (3.x or 4.x with the checked session APIs). No execution-policy changes.
    CUCM/CUC/CER 14/15 and UCCX 12.5/15 are candidate product adapters, not a
    certification of every SU. Unrecognized CLI output stops that target.
    Configuration verification is separate from an actual backup/restore test.
    Use -ReadOnly for inspection without schedule settings. -WhatIf and -ReadOnly
    never save credentials/profiles, install modules or send configuration writes.
    First-contact SSH trust may still prompt through Posh-SSH; verify fingerprints.
#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
param(
    [switch]$Apply,
    [switch]$ReadOnly,
    [switch]$ManageExisting,
    [switch]$SetupLocalSftp,
    [string[]]$SftpRemoteAddress,
    [string]$Csv,
    [string]$Profile,
    [string]$SaveProfile,
    [ValidateSet('Ask','Never')][string]$CredentialMode='Ask',
    [string]$LogPath,
    [switch]$InstallDependencies,
    [string]$PoshSshVersion='3.2.7'
)

# Keep I/O at the edges: parsers/planners below do not connect, prompt or mutate.
function Get-Field($Object, [string]$Name, $Default=$null) {
    if ($null -eq $Object) { return $Default }
    $p=$Object.PSObject.Properties[$Name]
    if ($null -eq $p -or $null -eq $p.Value -or "$($p.Value)" -eq '') { return $Default }
    return $p.Value
}
function Read-Value([string]$Prompt, [string]$Default='') {
    $suffix=if ($Default) { " [$Default]" } else { '' }
    $value=(Read-Host "$Prompt$suffix").Trim()
    if (-not $value) { $value=$Default }
    if (-not $value) { throw 'Required value missing. No further action taken.' }
    return $value
}
function Confirm-Choice([string]$Prompt) {
    return ((Read-Host "$Prompt [y/N]").Trim() -match '^(?i:y|yes)$')
}
function Read-Choice([string]$Prompt,[string[]]$Choices,[string]$Default) {
    while ($true) {
        $v=Read-Value "$Prompt ($($Choices -join '/'))" $Default
        foreach ($c in $Choices) { if ($v -ieq $c) { return $c } }
        Write-Warning 'Choose one of the displayed values.'
    }
}
function ConvertTo-IPv4([string]$Value) {
    $address=$null
    # Reject shorthand/octal/hex forms, whitespace and control characters.
    if ($Value -notmatch '^\d{1,3}(\.\d{1,3}){3}$' -or
        -not [ipaddress]::TryParse($Value,[ref]$address) -or
        $address.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork) {
        throw "Invalid IPv4 address: $Value"
    }
    return $address.ToString()
}
function Assert-Token([string]$Value,[string]$Name,[string]$Pattern='^[A-Za-z0-9][A-Za-z0-9_.-]{0,79}$') {
    if ($Value -cnotmatch $Pattern) { throw "Invalid $Name. Use supported letters, digits and separators only." }
    return $Value
}
function Get-UcTechnologyPolicy([string]$Technology) {
    $product=$Technology.ToUpperInvariant()
    $requiredFeature=switch ($product) {
        'CUCM' { 'CCM' }
        'CUC'  { 'CONNECTION' }
        'CER'  { 'CER' }
        'UCCX' { 'UCCX' }
        default { throw "Unsupported technology: $Technology" }
    }
    return [pscustomobject]@{Technology=$product;RequiredFeature=$requiredFeature}
}
function ConvertTo-UcTarget($InputObject) {
    $allowed=@('Site','Id','Technology','Address','Port','Username','ExpectedNodes','ImpTopology','ImpPublisher','ImpSubscriber','Settings')
    foreach ($p in $InputObject.PSObject.Properties.Name) {
        if ($p -notin $allowed) { throw "Unknown target field '$p'. Credentials must not be placed in input files." }
    }
    $technology=(Get-UcTechnologyPolicy "$(Get-Field $InputObject Technology)").Technology
    $site=Assert-Token "$(Get-Field $InputObject Site)" 'site'
    $id=Assert-Token "$(Get-Field $InputObject Id)" 'environment ID'
    $address=ConvertTo-IPv4 "$(Get-Field $InputObject Address)"
    $port=0
    if (-not [int]::TryParse("$(Get-Field $InputObject Port 22)",[ref]$port) -or $port -lt 1 -or $port -gt 65535) { throw 'Invalid SSH port.' }
    $user=Assert-Token "$(Get-Field $InputObject Username)" 'SSH username' '^[A-Za-z0-9][A-Za-z0-9_.@\\-]{0,127}$'
    $imp="$(Get-Field $InputObject ImpTopology 'Discover')"
    if ($imp -notin @('None','PublisherOnly','Pair','Discover')) { throw 'Invalid ImpTopology.' }
    if ($technology -ne 'CUCM' -and $imp -notin @('None','Discover')) { throw 'IM&P topology applies only to CUCM.' }
    $nodes=@("$(Get-Field $InputObject ExpectedNodes '')" -split ';' | Where-Object { $_ })
    foreach ($node in $nodes) { $null=Assert-Token $node 'expected node hostname' }
    $impPub="$(Get-Field $InputObject ImpPublisher '')"; $impSub="$(Get-Field $InputObject ImpSubscriber '')"
    foreach ($node in @($impPub,$impSub) | Where-Object { $_ }) { $null=Assert-Token $node 'IM&P hostname' }
    if ($imp -in @('PublisherOnly','Pair') -and -not $impPub) { throw 'ImpPublisher hostname is required for the selected IM&P topology.' }
    if ($imp -eq 'Pair' -and -not $impSub) { throw 'ImpSubscriber hostname is required for Pair.' }
    if ($impPub -and $impPub -ieq $impSub) { throw 'IM&P publisher and subscriber must be distinct.' }
    if ($imp -eq 'None' -and ($impPub -or $impSub)) { throw 'IM&P hostnames conflict with ImpTopology None.' }
    if ($imp -eq 'PublisherOnly' -and $impSub) { throw 'ImpSubscriber conflicts with PublisherOnly.' }
    $settingsValue=Get-Field $InputObject Settings
    if ($settingsValue) { $settingsValue=ConvertTo-BackupSettings $settingsValue }
    return [pscustomobject]@{Site=$site;Id=$id;Technology=$technology;Address=$address;Port=$port;Username=$user;
        ExpectedNodes=($nodes -join ';');ImpTopology=$imp;ImpPublisher=$impPub;ImpSubscriber=$impSub;
        Settings=$settingsValue}
}
function Test-TargetSet([object[]]$Targets) {
    if ($Targets.Count -eq 0) { throw 'No environments selected.' }
    $ids=@{}; $endpoints=@{}
    foreach ($t in $Targets) {
        $id="$($t.Site)/$($t.Id)"; $endpoint="$($t.Site)/$($t.Address):$($t.Port)"
        if ($ids.ContainsKey($id) -or $endpoints.ContainsKey($endpoint)) { throw "Duplicate environment or endpoint: $id ($endpoint)" }
        $ids[$id]=$true; $endpoints[$endpoint]=$true
    }
}
function Read-UcTarget {
    $tech=Read-Choice 'Technology' @('CUCM','CUC','CER','UCCX') 'CUCM'
    $raw=[pscustomobject]@{Site=(Read-Value 'Site ID');Id=(Read-Value 'Environment ID');Technology=$tech;
        Address=(Read-Value 'Publisher/first-node IPv4');Port=22;Username=(Read-Value 'SSH OS administrator username' 'admin');
        ExpectedNodes='';ImpTopology='None';ImpPublisher='';ImpSubscriber='';Settings=$null}
    $raw.ExpectedNodes=(Read-Host 'Expected node short hostnames, separated by ; (blank: discover and review)').Trim()
    if ($tech -eq 'CUCM') {
        $raw.ImpTopology=Read-Choice 'Associated IM&P topology' @('None','PublisherOnly','Pair','Discover') 'Discover'
        if ($raw.ImpTopology -in @('PublisherOnly','Pair')) { $raw.ImpPublisher=Read-Value 'Exact IM&P publisher short hostname' }
        if ($raw.ImpTopology -eq 'Pair') { $raw.ImpSubscriber=Read-Value 'Exact IM&P subscriber short hostname' }
    }
    return ConvertTo-UcTarget $raw
}
function Read-UcTargetSelection([object[]]$Initial=@()) {
    $list=New-Object System.Collections.Generic.List[object]
    foreach ($t in $Initial) { $list.Add($t) }
    while ($true) {
        Write-Host "`nSelected environments (remove here means remove from this run only):" -ForegroundColor Cyan
        for ($i=0;$i -lt $list.Count;$i++) { Write-Host ("{0}. {1}/{2}  {3}  {4}" -f ($i+1),$list[$i].Site,$list[$i].Id,$list[$i].Technology,$list[$i].Address) }
        $choice=Read-Choice 'Action' @('Add','Edit','Remove','Continue','Cancel') $(if ($list.Count) {'Continue'}else{'Add'})
        if ($choice -eq 'Cancel') { throw 'Cancelled before connecting.' }
        if ($choice -eq 'Continue') { Test-TargetSet @($list.ToArray()); return $list.ToArray() }
        if ($choice -eq 'Add') {
            try { $list.Add((Read-UcTarget)) } catch { Write-Warning $_.Exception.Message }
            continue
        }
        $number=0; $entry=Read-Host 'Environment number'
        if (-not [int]::TryParse($entry,[ref]$number) -or $number -lt 1 -or $number -gt $list.Count) { Write-Warning 'Invalid number.'; continue }
        if ($choice -eq 'Remove') { $list.RemoveAt($number-1) }
        else { try { $list[$number-1]=Read-UcTarget } catch { Write-Warning $_.Exception.Message } }
    }
}
function Import-UcTargets([string]$CsvPath,[string]$ProfilePath) {
    if ($CsvPath -and $ProfilePath) { throw 'Use either -Csv or -Profile.' }
    if ($CsvPath) { $raw=@(Import-Csv -LiteralPath $CsvPath -ErrorAction Stop) }
    elseif ($ProfilePath) {
        $document=Get-Content -LiteralPath $ProfilePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ((Get-Field $document SchemaVersion) -ne 1) { throw 'Unsupported profile SchemaVersion.' }
        foreach ($p in $document.PSObject.Properties.Name) { if ($p -notin @('SchemaVersion','Targets')) { throw "Unknown profile field: $p" } }
        $raw=@($document.Targets)
    } else { return @() }
    $targets=@($raw | ForEach-Object { ConvertTo-UcTarget $_ }); Test-TargetSet $targets; return $targets
}
function ConvertTo-BackupSettings($Value) {
    if ($null -eq $Value) { throw 'Backup settings missing.' }
    $allowed=@('SftpAddress','SftpUsername','Retention','WeeklyPath','MonthlyPath','WeeklyName','MonthlyName','WeeklyDay','WeeklyTime','MonthlyDay','MonthlyTime')
    foreach ($p in $Value.PSObject.Properties.Name) { if ($p -notin $allowed) { throw "Unknown backup setting: $p" } }
    $result=[ordered]@{}
    $result.SftpAddress=ConvertTo-IPv4 "$(Get-Field $Value SftpAddress)"
    $result.SftpUsername=Assert-Token "$(Get-Field $Value SftpUsername)" 'SFTP username' '^[A-Za-z0-9][A-Za-z0-9_.@-]{0,127}$'
    $n=0
    if (-not [int]::TryParse("$(Get-Field $Value Retention)",[ref]$n) -or $n -lt 1 -or $n -gt 100) { throw 'Retention must be 1-100 backups.' }
    $result.Retention=$n
    foreach ($name in @('WeeklyName','MonthlyName')) { $result[$name]=Assert-Token "$(Get-Field $Value $name)" $name }
    if ($result.WeeklyName -ieq $result.MonthlyName) { throw 'Weekly and monthly names must differ.' }
    foreach ($name in @('WeeklyPath','MonthlyPath')) {
        $path=Assert-Token "$(Get-Field $Value $name)" $name '^[A-Za-z0-9_./-]{1,200}$'
        if ($path -match '(^|/)\.\.?(/|$)' -or $path.StartsWith('-')) { throw 'Relative traversal and option-like SFTP paths are not allowed.' }
        $result[$name]=$path
    }
    if ($result.WeeklyPath.TrimEnd('/') -ieq $result.MonthlyPath.TrimEnd('/')) { throw 'Weekly and monthly paths must differ.' }
    $day="$(Get-Field $Value WeeklyDay 'Tuesday')"
    if ($day -notin [enum]::GetNames([DayOfWeek])) { throw 'Invalid WeeklyDay.' }; $result.WeeklyDay=$day
    foreach ($name in @('WeeklyTime','MonthlyTime')) {
        $time="$(Get-Field $Value $name '01:00')"
        if ($time -notmatch '^(?:[01][0-9]|2[0-3]):[0-5][0-9]$') { throw "Invalid $name; use HH:mm." }; $result[$name]=$time
    }
    $n=0
    if (-not [int]::TryParse("$(Get-Field $Value MonthlyDay 1)",[ref]$n) -or $n -lt 0 -or $n -gt 28) { throw 'MonthlyDay must be 1-28, or 0 to omit monthly backups.' }
    $result.MonthlyDay=$n
    return [pscustomobject]$result
}
function Read-BackupSettings($Target) {
    Write-Host "`nBackup settings for $($Target.Site)/$($Target.Id). Times are in the UC node's local timezone."
    Write-Host 'SFTP folders must be writable from the UC nodes. -SetupLocalSftp can provision them on this Windows SFTP host in a separate run.'
    $root="SFTPBackups/$($Target.Site)/$($Target.Id)/$($Target.Technology)"
    while ($true) {
        try {
            return ConvertTo-BackupSettings ([pscustomobject]@{
                SftpAddress=(Read-Value 'SFTP server IPv4 (may be a different machine)');SftpUsername=(Read-Value 'SFTP username' 'cmsbackup');
                Retention=(Read-Value 'Backups retained per device (1-100)' '2');
                WeeklyName=(Read-Value 'Weekly device/schedule name' 'Probe_Weekly');MonthlyName=(Read-Value 'Monthly device/schedule name' 'Probe_Monthly');
                WeeklyPath=(Read-Value 'Weekly SFTP path' "$root/Weekly/");MonthlyPath=(Read-Value 'Monthly SFTP path' "$root/Monthly/");
                WeeklyDay=(Read-Choice 'Weekly day' ([enum]::GetNames([DayOfWeek])) 'Tuesday');WeeklyTime=(Read-Value 'Weekly time HH:mm' '01:00');
                MonthlyDay=(Read-Value 'Monthly calendar day (1-28; 0 disables monthly)' '1');MonthlyTime=(Read-Value 'Monthly time HH:mm' '01:00')})
        } catch { Write-Warning $_.Exception.Message; if (-not (Confirm-Choice 'Re-enter settings?')) { throw } }
    }
}
function Test-DestinationCollisions([object[]]$Targets) {
    $seen=@{}
    foreach ($t in $Targets) {
        if (-not $t.Settings) { continue }
        $s=$t.Settings; $paths=@($s.WeeklyPath); if ($s.MonthlyDay -gt 0) { $paths+= $s.MonthlyPath }
        foreach ($path in $paths) {
            $key="$($t.Site)|$($s.SftpAddress)|$($s.SftpUsername)|$($path.TrimEnd('/'))"
            if ($seen.ContainsKey($key)) { throw "Shared backup destination for $($t.Id) and $($seen[$key]); use separate folders." }
            $seen[$key]=$t.Id
        }
    }
}

# Windows native vault: never shell out with a password, export a secret, or roam it.
function Initialize-CredentialStore {
    if ('UcDrs.NativeVault' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Net;
using System.Runtime.InteropServices;
using System.Security;
namespace UcDrs {
 public static class NativeVault {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  struct Credential {
   public UInt32 Flags, Type;
   [MarshalAs(UnmanagedType.LPWStr)] public string TargetName;
   [MarshalAs(UnmanagedType.LPWStr)] public string Comment;
   public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
   public UInt32 CredentialBlobSize;
   public IntPtr CredentialBlob;
   public UInt32 Persist, AttributeCount;
   public IntPtr Attributes;
   [MarshalAs(UnmanagedType.LPWStr)] public string TargetAlias;
   [MarshalAs(UnmanagedType.LPWStr)] public string UserName;
  }
  [DllImport("advapi32.dll", EntryPoint="CredReadW", CharSet=CharSet.Unicode, SetLastError=true)]
  [return: MarshalAs(UnmanagedType.Bool)] static extern bool ReadNative(string target, UInt32 type, UInt32 flags, out IntPtr credential);
  [DllImport("advapi32.dll", EntryPoint="CredWriteW", CharSet=CharSet.Unicode, SetLastError=true)]
  [return: MarshalAs(UnmanagedType.Bool)] static extern bool WriteNative(ref Credential credential, UInt32 flags);
  [DllImport("advapi32.dll", EntryPoint="CredDeleteW", CharSet=CharSet.Unicode, SetLastError=true)]
  [return: MarshalAs(UnmanagedType.Bool)] static extern bool DeleteNative(string target, UInt32 type, UInt32 flags);
  [DllImport("advapi32.dll")] static extern void CredFree(IntPtr buffer);
  public static NetworkCredential Read(string target) {
   IntPtr p;
   if (!ReadNative(target,1,0,out p)) { int e=Marshal.GetLastWin32Error(); if(e==1168)return null; throw new Win32Exception(e); }
   SecureString secret=new SecureString();
   try {
    Credential c=(Credential)Marshal.PtrToStructure(p,typeof(Credential));
    if(c.CredentialBlobSize>2560 || (c.CredentialBlobSize%2)!=0)throw new InvalidOperationException("Invalid stored credential encoding.");
    for(int i=0;i<c.CredentialBlobSize;i+=2)secret.AppendChar((char)Marshal.ReadInt16(c.CredentialBlob,i));
    secret.MakeReadOnly(); return new NetworkCredential(c.UserName,secret);
   } finally { secret.Dispose(); CredFree(p); }
  }
  public static void Write(string target,string user,SecureString secret) {
   if(secret.Length*2>2560)throw new ArgumentException("Credential exceeds native store limit.");
   IntPtr p=Marshal.SecureStringToCoTaskMemUnicode(secret);
   try {
    Credential c=new Credential(); c.Type=1;c.TargetName=target;c.UserName=user;c.Persist=2;
    c.CredentialBlob=p;c.CredentialBlobSize=(UInt32)(secret.Length*2);c.Comment="UC DRS operator credential";
    if(!WriteNative(ref c,0))throw new Win32Exception(Marshal.GetLastWin32Error());
   } finally { Marshal.ZeroFreeCoTaskMemUnicode(p); }
  }
  public static void Delete(string target) {
   if(!DeleteNative(target,1,0)){int e=Marshal.GetLastWin32Error();if(e!=1168)throw new Win32Exception(e);}
  }
 }
}
'@
}
function Get-CredentialKey([string]$Site,[string]$Purpose,[string]$Address,[int]$Port,[string]$Username) {
    return "UC-DRS/$Site/$Purpose/$(ConvertTo-IPv4 $Address):$Port/$Username"
}
function Request-UcCredential($Context,[string]$Site,[string]$Purpose,[string]$Address,[int]$Port,[string]$Username,[switch]$Fresh) {
    $key=Get-CredentialKey $Site $Purpose $Address $Port $Username
    if ($Context.CredentialMode -ne 'Never' -and -not $Fresh) {
        try {
            Initialize-CredentialStore
            $saved=[UcDrs.NativeVault]::Read($key)
            if ($saved) {
                Write-Host "Saved $Purpose credential: $($saved.UserName) @ $Address (site $Site)"
                $options=@('Use','New'); if ($Context.AllowLocalWrite) { $options+= 'Forget' }
                $choice=Read-Choice 'Credential action' $options 'Use'
                if ($choice -eq 'Use') { return [pscustomobject]@{Credential=[pscredential]::new($saved.UserName,$saved.SecurePassword);Key=$key;Stored=$true} }
                if ($choice -eq 'Forget') { [UcDrs.NativeVault]::Delete($key); Write-Audit $Context 'credential_forgotten' @{Key=$key} }
            }
        } catch { Write-Warning 'Native credential store unavailable; using a prompted credential.' }
    }
    $user=Read-Value "$Purpose username for $Address" $Username
    $null=Assert-Token $user 'username' '^[A-Za-z0-9][A-Za-z0-9_.@\\-]{0,127}$'
    $secure=Read-Host "$Purpose password for $user @ $Address" -AsSecureString
    if ($secure.Length -eq 0) { $secure.Dispose(); throw 'Empty password; target cancelled.' }
    return [pscustomobject]@{Credential=[pscredential]::new($user,$secure);Key=(Get-CredentialKey $Site $Purpose $Address $Port $user);Stored=$false}
}
function Save-ValidatedCredential($Context,$Entry) {
    if (-not $Entry.Stored -and $Context.CredentialMode -eq 'Ask' -and $Context.AllowLocalWrite) {
        if (Confirm-Choice "Remember validated credential '$($Entry.Key)' in your Windows Credential Manager?") {
            try {
                Initialize-CredentialStore
                [UcDrs.NativeVault]::Write($Entry.Key,$Entry.Credential.UserName,$Entry.Credential.Password)
                $Entry.Stored=$true
                Write-Audit $Context 'credential_saved' @{Key=$Entry.Key}
            } catch { Write-Warning 'Could not save credential; the authenticated connection remains usable.' }
        }
    }
}

# Structured logs omit raw SSH output during secret exchange. All other output
# passes through the same sanitizer, including caught exceptions and summaries.
function Protect-Text($Context,[string]$Text) {
    foreach ($secret in $Context.Secrets) { if ($secret) { $Text=$Text.Replace($secret,'[REDACTED]') } }
    return ($Text -replace '(?im)(password\s*[:=]\s*)[^\r\n]*','$1[REDACTED]')
}
function Protect-AuditData($Context,$Data) {
    if ($null -eq $Data) { return $null }
    if ($Data -is [string]) { return Protect-Text $Context $Data }
    if ($Data -is [datetime] -or $Data -is [ValueType]) { return $Data }
    if ($Data -is [System.Collections.IDictionary]) {
        $safe=[ordered]@{}; foreach ($key in $Data.Keys) { $safe[$key]=Protect-AuditData $Context $Data[$key] }; return $safe
    }
    if ($Data -is [System.Collections.IEnumerable]) {
        $safe=@(foreach ($item in $Data) { Protect-AuditData $Context $item }); return ,$safe
    }
    $safe=[ordered]@{}; foreach ($p in $Data.PSObject.Properties) { $safe[$p.Name]=Protect-AuditData $Context $p.Value }; return $safe
}
function Write-Audit($Context,[string]$Event,$Data) {
    $record=[ordered]@{Time=[datetime]::UtcNow.ToString('o');RunId=$Context.RunId;Event=$Event;Data=(Protect-AuditData $Context $Data)}
    $line=$record | ConvertTo-Json -Depth 20 -Compress
    # Write intent must reach disk before a command is sent. Flush to disk, not only
    # to a managed buffer. If logging fails, propagate and stop further writes.
    $bytes=[Text.Encoding]::UTF8.GetBytes($line+[Environment]::NewLine)
    $file=[IO.File]::Open($Context.LogPath,[IO.FileMode]::Append,[IO.FileAccess]::Write,[IO.FileShare]::Read)
    try { $file.Write($bytes,0,$bytes.Length); $file.Flush($true) } finally { $file.Dispose() }
}
function New-RunContext([string]$Path,[string]$Mode,[bool]$AllowLocalWrite) {
    if (-not $Path) {
        $base=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'UC-DRS/Logs'
        if (-not (Test-Path -LiteralPath $base)) { $null=[IO.Directory]::CreateDirectory($base) }
        $Path=Join-Path $base ("UC-DRS-{0}-{1}.jsonl" -f (Get-Date -Format yyyyMMdd-HHmmss),[guid]::NewGuid().ToString('N').Substring(0,8))
    }
    $full=[IO.Path]::GetFullPath($Path)
    if (Test-Path -LiteralPath $full) { throw 'Choose a new log filename; existing audit files are never appended or overwritten.' }
    $file=[IO.File]::Open($full,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::Read); $file.Dispose()
    return [pscustomobject]@{RunId=[guid]::NewGuid().ToString('N');LogPath=$full;CredentialMode=$Mode;AllowLocalWrite=$AllowLocalWrite;
        Secrets=(New-Object System.Collections.Generic.List[string]);CleanupFailed=$false;AllowRemoteWrite=$false;PendingWrites=(New-Object System.Collections.Generic.List[object])}
}
function Initialize-PoshSsh([switch]$Install,[string]$Version) {
    $available=@(Get-Module -ListAvailable -Name Posh-SSH | Where-Object { $_.Version.Major -in @(3,4) } | Sort-Object Version -Descending)
    if ($available.Count -eq 0) {
        if (-not $Install) { throw 'Posh-SSH 3.x/4.x is missing. Run explicitly with -InstallDependencies (or install your approved version).' }
        if ($Version -notmatch '^\d+\.\d+\.\d+$') { throw 'Specify an exact stable Posh-SSH version.' }
        Install-Module Posh-SSH -RequiredVersion $Version -Repository PSGallery -Scope CurrentUser -ErrorAction Stop
        $available=@(Get-Module -ListAvailable -Name Posh-SSH | Where-Object { $_.Version.ToString() -eq $Version })
    }
    if (-not $available.Count) { throw 'Posh-SSH installation was not found.' }
    Import-Module $available[0].Path -ErrorAction Stop
    foreach ($name in @('New-SSHSession','New-SSHShellStream','Remove-SSHSession')) { $null=Get-Command $name -Module Posh-SSH -ErrorAction Stop }
    foreach ($parameter in @('ComputerName','Port','Credential','ConnectionTimeout')) {
        if (-not (Get-Command New-SSHSession).Parameters.ContainsKey($parameter)) { throw "Posh-SSH is missing required parameter: $parameter" }
    }
    return $available[0].Version.ToString()
}
function Close-UcConnection($Context,$Connection) {
    if (-not $Connection) { return }
    # Always attempt both operations. Cleanup errors must not hide the original
    # operation failure or skip cleanup of another target's connection.
    foreach ($kind in @('Stream','Session')) {
        try {
            if ($kind -eq 'Stream' -and $Connection.Stream) { $Connection.Stream.Dispose(); $Connection.Stream=$null }
            if ($kind -eq 'Session' -and $Connection.Session) { Remove-SSHSession -SSHSession $Connection.Session -ErrorAction Stop | Out-Null; $Connection.Session=$null }
        } catch {
            $Context.CleanupFailed=$true
            Write-Warning "SSH $kind cleanup failed; inspect this run's audit log."
            try { Write-Audit $Context 'cleanup_failed' @{Kind=$kind;Address=$Connection.Address} } catch { Write-Warning 'Could not record cleanup failure.' }
        }
    }
}
function Test-AuthenticationError($Exception) {
    while ($Exception) {
        if ($Exception.GetType().FullName -eq 'Renci.SshNet.Common.SshAuthenticationException') { return $true }
        $Exception=$Exception.InnerException
    }
    return $false
}
function Open-UcConnection($Context,$Target) {
    $connection=[pscustomobject]@{Session=$null;Stream=$null;Address=$Target.Address;Ready=$false;SecretExchange=$false}
    $entry=$null
    try {
        for ($attempt=0;$attempt -lt 2;$attempt++) {
            $entry=Request-UcCredential $Context $Target.Site 'ssh' $Target.Address $Target.Port $Target.Username -Fresh:($attempt -gt 0)
            try {
                # Posh-SSH's normal host-key policy stays in force. Never AcceptKey,
                # Force, or bypass verification because a saved password exists.
                $connection.Session=New-SSHSession -ComputerName $Target.Address -Port $Target.Port -Credential $entry.Credential -ConnectionTimeout 25 -ErrorAction Stop
                break
            } catch {
                if ($attempt -ne 0 -or -not (Test-AuthenticationError $_.Exception)) { throw }
                Write-Warning 'Authentication rejected. One fresh credential attempt is available.'
                $entry.Credential.Password.Dispose(); $entry=$null
                if (-not (Confirm-Choice 'Retry this target?')) { throw 'Authentication retry declined.' }
            }
        }
        if (-not $connection.Session -or -not $connection.Session.Connected) { throw 'SSH did not connect.' }
        Save-ValidatedCredential $Context $entry
        $connection.Stream=New-SSHShellStream -SSHSession $connection.Session -TerminalName dumb -Columns 180 -Rows 60 -Width 1024 -Height 768 -ErrorAction Stop
        Write-Host 'SSH connected; waiting up to 120 seconds for the Cisco admin prompt.'
        $null=Receive-UcOutput $Context $connection 120 'Startup'
        return $connection
    } catch { Close-UcConnection $Context $connection; throw }
    finally { if ($entry) { $entry.Credential.Password.Dispose(); $entry=$null } }
}
function Remove-TerminalControl([string]$Text) {
    return ($Text -replace '\x1B\[[0-?]*[ -/]*[@-~]','' -replace '\r','')
}
function Get-UcPrompt([string]$Text,[string]$Expected='None') {
    $clean=Remove-TerminalControl $Text
    # Match only the final line. Earlier echoed prompts cannot finish a command.
    if ($clean -match '(?:^|\n)admin:[ \t]*(?:\n[ \t]*)*\z') { return 'CLI' }
    if ($Expected -eq 'Password' -and $clean -match '(?i)(?:^|\n)[^\n]*(?:enter|re-enter|reenter|confirm)?[^\n]*password[^\n]*[:?][ \t]*(?:\n[ \t]*)*\z') { return 'Password' }
    if ($Expected -eq 'Weekday' -and $clean -match '(?i)(?:^|\n)[^\n]*(?:enter|select|choose)[^\n]*week\s*days?[^\n]*[:?][ \t]*(?:\n[ \t]*)*\z') { return 'Weekday' }
    return 'None'
}
function Receive-UcOutput($Context,$Connection,[int]$Timeout=65,[string]$Expected='None') {
    $buffer=New-Object Text.StringBuilder; $watch=[Diagnostics.Stopwatch]::StartNew(); $last=0L
    while ($watch.Elapsed.TotalSeconds -lt $Timeout) {
        if ($Connection.Stream.DataAvailable) {
            $part=$Connection.Stream.Read(); if ($part) { $null=$buffer.Append($part); $last=$watch.ElapsedMilliseconds }
            if ($buffer.Length -gt 1048576) { throw 'SSH response exceeded 1 MiB; state is unverified.' }
        }
        $prompt=Get-UcPrompt $buffer.ToString() $Expected
        if ($prompt -ne 'None' -and ($watch.ElapsedMilliseconds-$last) -ge 300) {
            $Connection.Ready=($prompt -eq 'CLI')
            $safe=if ($Connection.SecretExchange) { '[secret exchange response omitted]' } else { Protect-Text $Context $buffer.ToString() }
            Write-Audit $Context 'response' @{Address=$Connection.Address;Prompt=$prompt;Text=$safe}
            return [pscustomobject]@{Text=$buffer.ToString();Prompt=$prompt}
        }
        if (-not $Connection.Session.Connected) { throw 'SSH disconnected; last command outcome may be unknown.' }
        Start-Sleep -Milliseconds 100
    }
    $safe=if ($Connection.SecretExchange) {'[secret exchange response omitted]'}else{Protect-Text $Context $buffer.ToString()}
    Write-Audit $Context 'timeout' @{Address=$Connection.Address;Expected=$Expected;Text=$safe}
    if ($Expected -eq 'Startup') { throw 'SSH connected but the Cisco admin prompt did not appear within 120 seconds.' }
    throw 'SSH command timed out. Review the audit log; do not replay a write without reconciling current state.'
}
function Send-UcCommand($Context,$Connection,[string]$Command,[string]$Expected='None',[switch]$Mutation) {
    if ($Mutation -and -not $Context.AllowRemoteWrite) { throw 'Configuration writes are disabled in this run.' }
    if (-not $Connection.Ready) { throw 'CLI is not at a confirmed prompt; no command sent.' }
    if ($Command -match '[\r\n]') { throw 'Multiline CLI command rejected.' }
    if ($Connection.Stream.DataAvailable) { throw 'Unexpected buffered SSH output; reconnect and inspect before issuing commands.' }
    $id=[guid]::NewGuid().ToString('N')
    Write-Audit $Context $(if($Mutation){'write_intent'}else{'read_command'}) @{Id=$id;Address=$Connection.Address;Command=$Command}
    if ($Mutation) { $Context.PendingWrites.Add([pscustomobject]@{Id=$id;Address=$Connection.Address;Command=$Command}) }
    $Connection.Ready=$false
    $Connection.Stream.WriteLine($Command)
    $result=Receive-UcOutput $Context $Connection 110 $Expected
    if ($result.Text -match '(?im)^\s*(?:invalid command|command not found|syntax:|error:|failed\b|drfCliMsg:.*(?:fail|error))') {
        throw 'CLI reported a command error. See sanitized audit output.'
    }
    # A response is not a verified change; the caller must issue readback.
    if ($Mutation) { Write-Audit $Context 'write_response' @{Id=$id;Prompt=$result.Prompt} }
    $result | Add-Member -NotePropertyName OperationId -NotePropertyValue $id
    return $result
}
function Complete-DrsWrite($Context,[string]$Id,[string]$Evidence) {
    Write-Audit $Context 'write_verified_limited' @{Id=$Id;Evidence=$Evidence}
    foreach ($pending in @($Context.PendingWrites.ToArray())) { if ($pending.Id -eq $Id) { $null=$Context.PendingWrites.Remove($pending) } }
}

function Get-MeaningfulLines([string]$Text) {
    foreach ($line in ((Remove-TerminalControl $Text) -split '\n')) {
        $s=$line.Trim()
        if (-not $s -or $s -match '^(?:admin:|utils disaster_recovery |show network cluster|[-=]+$)') { continue }
        $s
    }
}
function ConvertFrom-DrsList([string]$Text,[ValidateSet('device','schedule')][string]$Kind) {
    $rows=New-Object System.Collections.Generic.List[object]; $header=$false; $empty=$false
    foreach ($line in (Get-MeaningfulLines $Text)) {
        if ($line -match "^(?i:$Kind)\s+name\b") { $header=$true; continue }
        if ($line -match "^(?i:(?:drfCliMsg:\s*)?no\s+(?:backup\s+)?${Kind}s?\b.*)$") { $empty=$true; continue }
        if ($Kind -eq 'schedule' -and $line -match '^(\S+)\s{2,}(\S+)\s+(enabled|disabled)$') {
            $rows.Add([pscustomobject]@{Name=$Matches[1];Device=$Matches[2];Status=$Matches[3].ToLowerInvariant()}); continue
        }
        if ($Kind -eq 'device' -and $line -match '^(\S+)\s{2,}(NETWORK|LOCAL|TAPE)(?:\s+(.*))?$') {
            $name=$Matches[1];$type=$Matches[2].ToUpperInvariant();$details=$Matches[3];$server=$null;$path=$null
            if ($type -eq 'NETWORK' -and $details -match '^(\S+)\s*:\s*(.+)$') { $server=$Matches[1];$path=$Matches[2].Trim() }
            $rows.Add([pscustomobject]@{Name=$name;Type=$type;Details=$details;Server=$server;Path=$path}); continue
        }
        throw "Unrecognized $Kind list row; refusing to treat partial output as an empty configuration."
    }
    if (-not $header -and -not $empty -and $rows.Count -eq 0) { throw "No recognizable $Kind listing received." }
    if ($empty -and $rows.Count -gt 0) { throw "Conflicting empty/populated $Kind listing." }
    $unique=@($rows | Select-Object -ExpandProperty Name -Unique)
    if ($unique.Count -ne $rows.Count) { throw "Duplicate $Kind names returned." }
    return $rows.ToArray()
}
function ConvertFrom-UcTopology([string]$Text,[string]$Address) {
    $rows=New-Object System.Collections.Generic.List[object]
    foreach ($line in (Get-MeaningfulLines $Text)) {
        if ($line -match '^(?i:(?:ip\s+address|address\s+hostname|cluster\s+.*|total\s+.*|\d+\s+servers?\s+.*))$') { continue }
        if ($line -notmatch '^(\d{1,3}(?:\.\d{1,3}){3})\s+(\S+)\s+(\S+)\s+(.+)$') { throw 'Unrecognized cluster row; topology is incomplete.' }
        $ip=ConvertTo-IPv4 $Matches[1]; $fqdn=$Matches[2]; $name=Assert-Token $Matches[3] 'cluster hostname'; $tail=$Matches[4]
        if ($tail -match '(?i)unauthenticated|not\s+authenticated' -or $tail -notmatch '(?i)\bauthenticated\b') { throw "Node $name is not authenticated in cluster output." }
        $role=if ($tail -match '(?i)\bPublisher\b') {'Publisher'}elseif($tail -match '(?i)\bSubscriber\b'){'Subscriber'}else{'Unknown'}
        $dbRole=if ($tail -match '(?i)\bDBPub\b'){'Publisher'}elseif($tail -match '(?i)\bDBSub\b'){'Subscriber'}else{'Unknown'}
        $rows.Add([pscustomobject]@{Address=$ip;Hostname=$name;Fqdn=$fqdn;Role=$role;DatabaseRole=$dbRole;Details=$tail})
    }
    if ($rows.Count -eq 0 -or @($rows | Where-Object Address -eq $Address).Count -ne 1) { throw 'Cannot uniquely identify the selected endpoint in the cluster.' }
    if (@($rows | Select-Object -ExpandProperty Hostname -Unique).Count -ne $rows.Count -or
        @($rows | Select-Object -ExpandProperty Address -Unique).Count -ne $rows.Count) { throw 'Duplicate cluster identities.' }
    if (@($rows | Where-Object { $_.Address -eq $Address -and $_.Role -eq 'Publisher' }).Count -ne 1) {
        throw 'The selected endpoint is not identified as the publisher/first node; no configuration changes permitted.'
    }
    return $rows.ToArray()
}
function ConvertFrom-DrsRegistration([string]$Text,[string]$Node) {
    $rows=New-Object System.Collections.Generic.List[object]; $pending=$null
    foreach ($line in (Get-MeaningfulLines $Text)) {
        if ($line -match '(?i)^Feature(?:\s+Name|\s+ID)?\s+(?:Component|Component\s+Name)\s*$') { continue }
        if ($line -match '(?i)^Feature(?:\s+Name|\s+ID)?\s*:\s*([A-Za-z][A-Za-z0-9_]*)\s*$') {
            if ($pending) { throw "Feature without a component on $Node." }; $pending=$Matches[1]; continue
        }
        if ($line -match '(?i)^Component(?:\s+Name)?\s*:\s*([A-Za-z][A-Za-z0-9_]*)\s*$' -and $pending) {
            $rows.Add([pscustomobject]@{Node=$Node;Feature=$pending;Component=$Matches[1]}); $pending=$null; continue
        }
        if ($line -match '^([A-Za-z][A-Za-z0-9_]*)\s+([A-Za-z][A-Za-z0-9_]*)\s*$') {
            if ($pending) { throw "Incomplete feature registration on $Node." }
            $rows.Add([pscustomobject]@{Node=$Node;Feature=$Matches[1];Component=$Matches[2]}); continue
        }
        throw "Unrecognized registration row on $Node. No automatic parser fallback is used."
    }
    if ($pending -or $rows.Count -eq 0) { throw "Incomplete or empty registration on $Node." }
    return @($rows.ToArray() | Sort-Object Node,Feature,Component -Unique)
}
function Get-UcRelease([string]$Text,[string]$Technology) {
    $policy=Get-UcTechnologyPolicy $Technology
    # Compare complete major/minor components: 12.50 must not match UCCX 12.5.
    # Preserve the accepted CLI line shape and return the original release text.
    if ($Text -notmatch '(?im)^\s*Active\s+(?:Master\s+)?Version\s*:\s*(?<Release>(?<Major>\d+)\.(?<Minor>\d+)(?:[.()\w-]*))') { throw 'Cannot parse the active release.' }
    $version=$Matches.Release; $major=$Matches.Major; $minor=$Matches.Minor
    $supported=if ($policy.Technology -eq 'UCCX') {
        $major -eq '15' -or ($major -eq '12' -and $minor -eq '5')
    } else { $major -in @('14','15') }
    if (-not $supported) { throw "No candidate adapter for $($policy.Technology) release $version. Inspection output has been logged." }
    return $version
}
function Test-DrsCoverage($Target,[object[]]$Nodes,[object[]]$Registrations) {
    $issues=New-Object System.Collections.Generic.List[string]
    $policy=Get-UcTechnologyPolicy $Target.Technology
    # IM&P registrations supplement CUCM; they cannot stand in for CCM itself.
    # Only registrations belonging to exact discovered node names count.
    $primary=@($Registrations | Where-Object {
        $_.Node -cin @($Nodes.Hostname) -and $_.Feature -eq $policy.RequiredFeature
    })
    if ($primary.Count -eq 0) {
        $issues.Add("No discovered node has the expected $($policy.RequiredFeature) registration for $($policy.Technology).")
    }
    $expected=@($Target.ExpectedNodes -split ';' | Where-Object { $_ })
    if ($expected.Count) {
        foreach ($name in $expected) { if ($name -cnotin @($Nodes.Hostname)) { $issues.Add("Expected node $name was not discovered (hostname case must match).") } }
        foreach ($node in $Nodes) { if ($node.Hostname -cnotin $expected) { $issues.Add("Unexpected node $($node.Hostname); update/review the inventory.") } }
    }
    $impNodes=New-Object System.Collections.Generic.List[object]
    foreach ($node in $Nodes) {
        $reg=@($Registrations | Where-Object Node -CEQ $node.Hostname)
        if (-not $reg.Count) { $issues.Add("No registrations for $($node.Hostname)."); continue }
        $features=@($reg.Feature | Select-Object -Unique)
        $required=$policy.RequiredFeature
        if ($Target.Technology -eq 'CUCM' -and 'IM_AND_PRESENCE' -in $features) {
            $impNodes.Add($node)
            # Role comes from expected inventory or explicit topology metadata,
            # never from the presence of DB (which could itself be missing).
            $role=$node.DatabaseRole
            if ($Target.ImpPublisher -ceq $node.Hostname) { $role='Publisher' }
            elseif ($Target.ImpSubscriber -ceq $node.Hostname) { $role='Subscriber' }
            if ($role -eq 'Unknown') { $issues.Add("IM&P role unknown for $($node.Hostname); specify ImpPublisher/ImpSubscriber in the profile."); continue }
            $components=@('PLATFORM','CLM','XCP','SYSLOGAGT','CDPAGT','TCT','CUP','REPORTER')
            if ($role -eq 'Publisher') { $components+=@('DB','PREFS','BAT') }
            foreach ($component in $components) {
                if ($component -notin @($reg | Where-Object Feature -eq 'IM_AND_PRESENCE' | Select-Object -ExpandProperty Component)) {
                    $issues.Add("IM&P $($node.Hostname) is missing documented $role component $component.")
                }
            }
        } elseif ($required -notin $features) { $issues.Add("$($node.Hostname) is missing expected $required registration for $($Target.Technology).") }
    }
    if ($Target.Technology -eq 'CUCM') {
        if ($Target.ImpTopology -eq 'None' -and $impNodes.Count -gt 0) { $issues.Add('IM&P nodes exist but the profile says None.') }
        if ($Target.ImpTopology -eq 'PublisherOnly' -and $impNodes.Count -ne 1) { $issues.Add('Expected exactly one IM&P node.') }
        if ($Target.ImpTopology -eq 'Pair' -and $impNodes.Count -ne 2) { $issues.Add('Expected an IM&P publisher/subscriber pair.') }
        foreach ($name in @($Target.ImpPublisher,$Target.ImpSubscriber) | Where-Object { $_ }) {
            if ($name -cnotin @($impNodes | ForEach-Object Hostname)) { $issues.Add("Expected IM&P node $name has no IM_AND_PRESENCE registration.") }
        }
    }
    return [pscustomobject]@{Status=$(if($issues.Count){'blocked'}else{'registered_features_checked'});Issues=$issues.ToArray();
        Features=@($Registrations.Feature | Sort-Object -Unique);Nodes=$Nodes;Registrations=$Registrations;
        Limit='Registration checks do not prove backup success or completeness of every product component.'}
}
function Get-DrsSnapshot($Context,$Connection) {
    $devices=@(ConvertFrom-DrsList (Send-UcCommand $Context $Connection 'utils disaster_recovery device list').Text device)
    $schedules=@(ConvertFrom-DrsList (Send-UcCommand $Context $Connection 'utils disaster_recovery schedule list').Text schedule)
    return [pscustomobject]@{Devices=$devices;Schedules=$schedules}
}
function Get-SnapshotFingerprint($Snapshot) {
    $value=[ordered]@{Devices=@($Snapshot.Devices | Sort-Object Name);Schedules=@($Snapshot.Schedules | Sort-Object Name)} | ConvertTo-Json -Depth 6 -Compress
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($value))).Replace('-','') } finally { $sha.Dispose() }
}
function Get-DrsDiscovery($Context,$Connection,$Target) {
    $releaseText=(Send-UcCommand $Context $Connection 'show version active').Text
    $release=Get-UcRelease $releaseText $Target.Technology
    Write-Host "Declared technology: $($Target.Technology); detected release: $release" -ForegroundColor Cyan
    # show version active does not consistently identify the installed application.
    # Expected feature registration below provides an additional product check.
    $nodes=@(ConvertFrom-UcTopology (Send-UcCommand $Context $Connection 'show network cluster').Text $Target.Address)
    $registrations=New-Object System.Collections.Generic.List[object]
    foreach ($node in $nodes) {
        $text=(Send-UcCommand $Context $Connection "utils disaster_recovery show_registration $($node.Hostname)").Text
        foreach ($row in (ConvertFrom-DrsRegistration $text $node.Hostname)) { $registrations.Add($row) }
    }
    $coverage=Test-DrsCoverage $Target $nodes $registrations.ToArray()
    Write-Audit $Context 'discovery' @{Target=$Target.Id;Release=$release;Coverage=$coverage}
    return [pscustomobject]@{Release=$release;Coverage=$coverage;Snapshot=(Get-DrsSnapshot $Context $Connection)}
}
function Read-NodeClock($Context,$Connection) {
    $text=(Send-UcCommand $Context $Connection 'show date').Text
    Write-Host "`nUC node clock/timezone:`n$(Protect-Text $Context $text)"
    # CLI timezone abbreviations are not reliable Windows time-zone identifiers.
    # Ask for the displayed wall clock, not a workstation-local conversion.
    while ($true) {
        $value=Read-Value 'Enter current UC node date/time from above (yyyy-MM-dd HH:mm)'
        $date=[datetime]::MinValue
        if ([datetime]::TryParseExact($value,'yyyy-MM-dd HH:mm',[cultureinfo]::InvariantCulture,[Globalization.DateTimeStyles]::None,[ref]$date)) {
            if (Confirm-Choice "Use $value in this node's displayed timezone to calculate starts?") {
                Write-Audit $Context 'node_clock_confirmed' @{LocalTime=$value;ClockOutput=$text}; return $date
            }
        } else { Write-Warning 'Use yyyy-MM-dd HH:mm.' }
    }
}
function Get-DrsStartTimes($Settings,[datetime]$NodeNow) {
    $earliest=$NodeNow.AddDays(2)
    $weekly=$earliest.Date.Add([timespan]::Parse($Settings.WeeklyTime,[cultureinfo]::InvariantCulture))
    while ($weekly -lt $earliest -or $weekly.DayOfWeek.ToString() -ne $Settings.WeeklyDay) { $weekly=$weekly.AddDays(1) }
    $monthly=$null
    if ($Settings.MonthlyDay -gt 0) {
        $monthly=[datetime]::new($earliest.Year,$earliest.Month,$Settings.MonthlyDay).Add([timespan]::Parse($Settings.MonthlyTime,[cultureinfo]::InvariantCulture))
        if ($monthly -lt $earliest) { $monthly=$monthly.AddMonths(1) }
    }
    return [pscustomobject]@{Weekly=$weekly;Monthly=$monthly}
}
function New-DrsPlan($Target,$Discovery,[datetime]$NodeNow) {
    if ($Discovery.Coverage.Status -eq 'blocked') { throw "Coverage blocked: $($Discovery.Coverage.Issues -join '; ')" }
    $settings=$Target.Settings; $times=Get-DrsStartTimes $settings $NodeNow
    $actions=New-Object System.Collections.Generic.List[object]
    $definitions=@([pscustomobject]@{Name=$settings.WeeklyName;Path=$settings.WeeklyPath;Start=$times.Weekly;Frequency='WEEKLY'})
    if ($times.Monthly) { $definitions+= [pscustomobject]@{Name=$settings.MonthlyName;Path=$settings.MonthlyPath;Start=$times.Monthly;Frequency='MONTHLY'} }
    foreach ($d in $definitions) {
        $device=@($Discovery.Snapshot.Devices | Where-Object Name -eq $d.Name)
        $schedule=@($Discovery.Snapshot.Schedules | Where-Object Name -eq $d.Name)
        # CLI list does not expose full existing settings. Never label name-only
        # matches already_ok or replace them in an attempt to force convergence.
        if ($device.Count -or $schedule.Count) {
            $actions.Add([pscustomobject]@{Kind='ReviewExisting';Name=$d.Name;State='unverified';Path=$d.Path;Start=$d.Start;Frequency=$d.Frequency;
                Detail='Existing device/schedule: verify settings in DRS, or select unused names. Existing state is preserved.'})
        } else {
            $actions.Add([pscustomobject]@{Kind='CreatePair';Name=$d.Name;State='update_needed';Path=$d.Path;Start=$d.Start;Frequency=$d.Frequency;Detail='Create device, create schedule, enable and read back.'})
        }
    }
    return [pscustomobject]@{Target=$Target;Release=$Discovery.Release;Features=$Discovery.Coverage.Features;
        SnapshotFingerprint=(Get-SnapshotFingerprint $Discovery.Snapshot);Actions=$actions.ToArray();Coverage=$Discovery.Coverage}
}
function Show-DrsPlan($Plan) {
    Write-Host "`n=== $($Plan.Target.Site)/$($Plan.Target.Id) | $($Plan.Target.Technology) $($Plan.Release) ===" -ForegroundColor Cyan
    Write-Host "SFTP: $($Plan.Target.Settings.SftpAddress) / $($Plan.Target.Settings.SftpUsername); retention $($Plan.Target.Settings.Retention)"
    Write-Host "Features: $($Plan.Features -join ',')"
    foreach ($a in $Plan.Actions) {
        Write-Host ("{0}: {1}; {2}; {3}; starts {4:yyyy-MM-dd HH:mm} (node local time)" -f $a.Name,$a.State,$a.Frequency,$a.Path,$a.Start)
        Write-Host "  $($a.Detail)"
    }
    if (@($Plan.Actions | Where-Object Frequency -eq 'MONTHLY').Count) { Write-Host "Monthly means calendar day $($Plan.Target.Settings.MonthlyDay), not a weekday ordinal." }
}
function Assert-CliSuccess([string]$Text) {
    if ($Text -match '(?im)^.*\b(?:failed|failure|invalid|exception|unable|cannot|error)\b' -or
        $Text -notmatch '(?i)\b(?:success|successfully)\b') {
        throw 'The CLI did not report unambiguous success. Inspect and reconcile before rerunning.'
    }
}
function Send-SftpSecret($Context,$Connection,[securestring]$Secret) {
    $pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secret); $plain=$null
    try {
        $plain=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
        $Context.Secrets.Add($plain)
        $Connection.Stream.WriteLine($plain)
        return Receive-UcOutput $Context $Connection 110 'Password'
    } finally {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        # .NET strings cannot be guaranteed erased. Avoid retaining them or raw
        # secret-exchange output; only the short-lived transport uses plaintext.
        if ($plain) { $null=$Context.Secrets.Remove($plain) }; $plain=$null
    }
}
function Invoke-CreateDevice($Context,$Connection,$Plan,$Action,$SftpEntry) {
    $s=$Plan.Target.Settings
    $command="utils disaster_recovery device add network $($Action.Name) $($Action.Path) $($s.SftpAddress) $($SftpEntry.Credential.UserName) $($s.Retention)"
    $Connection.SecretExchange=$true
    try {
        $r=Send-UcCommand $Context $Connection $command Password -Mutation
        $operationId=$r.OperationId
        for ($i=0;$i -lt 3 -and $r.Prompt -eq 'Password';$i++) { $r=Send-SftpSecret $Context $Connection $SftpEntry.Credential.Password }
        if ($r.Prompt -ne 'CLI') { throw 'Device creation did not return to the CLI prompt.' }
        Assert-CliSuccess $r.Text
    } finally { $Connection.SecretExchange=$false; $r=$null }
    $snapshot=Get-DrsSnapshot $Context $Connection
    if (@($snapshot.Devices | Where-Object { $_.Name -eq $Action.Name -and $_.Type -eq 'NETWORK' }).Count -ne 1) { throw 'New network device not present on readback.' }
    $device=@($snapshot.Devices | Where-Object Name -eq $Action.Name)[0]
    if ($device.Server -and $device.Server -cne $s.SftpAddress) { throw 'Created device server does not match the plan.' }
    if ($device.Path -and $device.Path.TrimEnd('/') -cne $Action.Path.TrimEnd('/')) { throw 'Created device path does not match the plan.' }
    Complete-DrsWrite $Context $operationId 'CLI success plus network-device name/type and any displayed server/path checked; remaining fields unverified.'
    Write-Audit $Context 'device_readback' @{Name=$Action.Name;Status='created_name_type_verified';Limit='Server/path checked if displayed. Retention, credentials and SFTP access are not independently verified by list.'}
}
function Invoke-CreateSchedule($Context,$Connection,$Plan,$Action) {
    $stamp=$Action.Start.ToString('yyyy/MM/dd-HH:mm',[cultureinfo]::InvariantCulture)
    $command="utils disaster_recovery schedule add $($Action.Name) $($Action.Name) $($Plan.Features -join ',') $stamp $($Action.Frequency)"
    $expected=if($Action.Frequency -eq 'WEEKLY'){'Weekday'}else{'None'}
    $r=Send-UcCommand $Context $Connection $command $expected -Mutation
    $operationId=$r.OperationId
    if ($r.Prompt -eq 'Weekday') {
        $answer=$Plan.Target.Settings.WeeklyDay
        Write-Audit $Context 'weekday_response' @{Name=$Action.Name;Value=$answer}
        $Connection.Stream.WriteLine($answer); $r=Receive-UcOutput $Context $Connection 110 'None'
    }
    if ($r.Prompt -ne 'CLI') { throw 'Unknown schedule prompt; no automatic answer sent.' }
    Assert-CliSuccess $r.Text
    $snapshot=Get-DrsSnapshot $Context $Connection
    if (@($snapshot.Schedules | Where-Object { $_.Name -eq $Action.Name -and $_.Device -eq $Action.Name }).Count -ne 1) { throw 'New schedule/device association not present on readback.' }
    Complete-DrsWrite $Context $operationId 'CLI success plus schedule name/device association readback.'
    $r=Send-UcCommand $Context $Connection "utils disaster_recovery schedule enable $($Action.Name)" None -Mutation
    Assert-CliSuccess $r.Text
    $snapshot=Get-DrsSnapshot $Context $Connection
    if (@($snapshot.Schedules | Where-Object { $_.Name -eq $Action.Name -and $_.Device -eq $Action.Name -and $_.Status -eq 'enabled' }).Count -ne 1) { throw 'Could not verify new schedule is enabled.' }
    Complete-DrsWrite $Context $r.OperationId 'CLI success plus enabled schedule readback.'
    Write-Audit $Context 'schedule_readback' @{Name=$Action.Name;Status='created_enabled_verified';Limit='Feature list and timing accepted by CLI but not fully exposed on list readback.'}
}
function Invoke-DrsPlan($Context,$Connection,$Plan,$Caller) {
    $results=New-Object System.Collections.Generic.List[object]; $sftp=$null
    try {
        $current=Get-DrsSnapshot $Context $Connection
        if ((Get-SnapshotFingerprint $current) -ne $Plan.SnapshotFingerprint) { throw 'Configuration changed after preview; rerun discovery. Nothing written.' }
        $expectedFingerprint=$Plan.SnapshotFingerprint
        foreach ($action in $Plan.Actions) {
            if ($action.Kind -ne 'CreatePair') { $results.Add([pscustomobject]@{Name=$action.Name;Status='unverified_existing'}); continue }
            if (-not $Caller.ShouldProcess("$($Plan.Target.Address): $($action.Name)",'Create DRS network device and schedule, then enable')) {
                $results.Add([pscustomobject]@{Name=$action.Name;Status='skipped'}); continue
            }
            if (-not $sftp) {
                $s=$Plan.Target.Settings
                $sftp=Request-UcCredential $Context $Plan.Target.Site sftp $s.SftpAddress 22 $s.SftpUsername
                # A different username changes the reviewed destination identity.
                if ($sftp.Credential.UserName -cne $s.SftpUsername) { throw 'SFTP username differs from preview. Update the profile and preview again.' }
            }
            $before=Get-DrsSnapshot $Context $Connection
            if ((Get-SnapshotFingerprint $before) -ne $expectedFingerprint) { throw 'Concurrent configuration change detected before next operation.' }
            Write-Audit $Context 'operation_started' @{Name=$action.Name;Target=$Plan.Target.Id}
            Write-Audit $Context 'operation_before' $before
            Invoke-CreateDevice $Context $Connection $Plan $action $sftp
            $afterDevice=Get-DrsSnapshot $Context $Connection
            Assert-SnapshotPreserved $before $afterDevice $action.Name
            Invoke-CreateSchedule $Context $Connection $Plan $action
            $after=Get-DrsSnapshot $Context $Connection
            Assert-SnapshotPreserved $before $after $action.Name
            Write-Audit $Context 'operation_after' $after
            $expectedFingerprint=Get-SnapshotFingerprint $after
            $results.Add([pscustomobject]@{Name=$action.Name;Status='created_enabled_verified_limited'})
            Write-Host "$($action.Name): created and enabled; full settings require DRS review." -ForegroundColor Green
        }
        # Device-add acceptance is not independent SFTP authentication. Save only
        # after the operator explicitly reports a successful actual backup.
        if ($sftp -and -not $sftp.Stored -and $Context.AllowLocalWrite -and $Context.CredentialMode -eq 'Ask') {
            Write-Host 'SFTP credential has not been independently validated by this tool.'
            if (Confirm-Choice 'Have you verified a successful backup using this SFTP account and want to offer credential saving?') { Save-ValidatedCredential $Context $sftp }
        }
        return $results.ToArray()
    } finally { if ($sftp) { $sftp.Credential.Password.Dispose(); $sftp=$null } }
}
function Show-Coverage($Coverage) {
    foreach ($node in $Coverage.Nodes) {
        $reg=@($Coverage.Registrations | Where-Object Node -CEQ $node.Hostname)
        Write-Host ("{0} ({1}, {2}): {3}; {4} component registrations" -f $node.Hostname,$node.Address,$node.Role,(@($reg.Feature | Sort-Object -Unique) -join ','),$reg.Count)
    }
    foreach ($issue in $Coverage.Issues) { Write-Warning $issue }
    Write-Host "Coverage: $($Coverage.Status). $($Coverage.Limit)"
}
function Save-UcProfile([object[]]$Targets,[string]$Path) {
    # A fresh path prevents silently replacing the user's authoritative inventory.
    $text=[pscustomobject]@{SchemaVersion=1;Targets=$Targets} | ConvertTo-Json -Depth 12
    $file=[IO.File]::Open([IO.Path]::GetFullPath($Path),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    $writer=New-Object IO.StreamWriter($file,([Text.UTF8Encoding]::new($false)))
    try { $writer.WriteLine($text) } finally { $writer.Dispose() }
}
# Local Windows SFTP provisioning is separate from appliance configuration. It
# runs on the selected site's SFTP host and never remotes into another Windows PC.
function Test-WindowsAdministrator {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    try { return ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) }
    finally { $identity.Dispose() }
}
function ConvertTo-SftpRelativePath([string]$Path) {
    $trim=$Path.TrimEnd('/')
    if ($trim -cnotmatch '^SFTPBackups(?:/[A-Za-z0-9_.-]+)+$') { throw 'Local setup requires relative paths beneath SFTPBackups/ in the selected user profile.' }
    foreach ($part in ($trim -split '/')) {
        if ($part -in @('.','..') -or $part.EndsWith('.') -or $part -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\.|$)') { throw 'Unsafe or reserved Windows folder name in SFTP path.' }
    }
    return $trim
}
function ConvertTo-SftpRemoteAddress([string[]]$Values) {
    $result=New-Object System.Collections.Generic.List[string]
    foreach ($value in $Values) {
        foreach ($item in ($value -split ',')) {
            $parts=$item.Trim() -split '/'
            if ($parts.Count -gt 2 -or -not $parts[0]) { throw 'Supply specific UC IPv4 addresses or CIDRs, separated by commas.' }
            $ip=ConvertTo-IPv4 $parts[0]
            if ($ip -match '^(0\.|127\.|169\.254\.)' -or [int]($ip.Split('.')[0]) -ge 224) { throw 'A unicast UC source address is required.' }
            if ($parts.Count -eq 2) {
                $prefix=0
                if (-not [int]::TryParse($parts[1],[ref]$prefix) -or $prefix -lt 1 -or $prefix -gt 32) { throw 'CIDR prefix must be 1-32. Any and /0 are not accepted.' }
                # Canonicalize network bits so idempotent firewall comparisons work.
                $bytes=([ipaddress]$ip).GetAddressBytes(); $remaining=$prefix
                for($i=0;$i -lt 4;$i++){ $bits=[Math]::Min(8,[Math]::Max(0,$remaining)); $mask=if($bits -eq 0){0}else{256-[Math]::Pow(2,8-$bits)}; $bytes[$i]=[byte]($bytes[$i] -band [int]$mask); $remaining-=8 }
                $ip=([ipaddress]::new($bytes)).ToString(); if ($prefix -lt 32) { $ip+="/$prefix" }
            }
            $result.Add($ip)
        }
    }
    if (-not $result.Count) { throw 'At least one UC source address/subnet is required; include subscriber backup sources too.' }
    return @($result.ToArray() | Sort-Object -Unique)
}
function Assert-SafeLocalDirectory([string]$Path) {
    if ($Path -notmatch '^[A-Za-z]:\\' -or $Path -match '[\x00-\x1f]') { throw 'The Windows user profile must be on a local drive.' }
    $full=[IO.Path]::GetFullPath($Path)
    $current=$full
    while ($current) {
        if (Test-Path -LiteralPath $current) {
            $item=Get-Item -LiteralPath $current -Force -ErrorAction Stop
            if (-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw "File or reparse point blocks local provisioning: $current" }
        }
        $parent=[IO.Directory]::GetParent($current)
        $current=if ($parent) {$parent.FullName}else{$null}
    }
    return $full
}
function Get-LocalSftpAccount([string]$Name) {
    $null=Assert-Token $Name 'local SFTP account name' '^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$'
    $user=Get-LocalUser -Name $Name -ErrorAction Stop
    if (-not $user.Enabled) { throw "Local SFTP account '$Name' is disabled." }
    if ($user.PrincipalSource -and "$($user.PrincipalSource)" -ne 'Local') { throw 'Select a local Windows account, not a domain, Microsoft or Entra account.' }
    if ($user.AccountExpires -and $user.AccountExpires -le (Get-Date)) { throw 'The selected local account has expired.' }
    if ($user.PasswordExpires -and $user.PasswordExpires -le (Get-Date)) { throw 'The selected local account password has expired.' }
    $sid=$user.SID.Value
    if (-not $sid -or $sid -notmatch '^S-1-5-21-') { throw 'Cannot establish the selected local account SID.' }
    $profileKey="Registry::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$sid"
    $profile=''
    if (Test-Path -LiteralPath $profileKey) {
        $profile=[Environment]::ExpandEnvironmentVariables((Get-ItemProperty -LiteralPath $profileKey -Name ProfileImagePath -ErrorAction Stop).ProfileImagePath)
        $null=Assert-SafeLocalDirectory $profile
        if (-not (Test-Path -LiteralPath $profile -PathType Container)) { throw 'Registered profile directory is missing; repair the Windows profile before setup.' }
    }
    return [pscustomobject]@{Name=$user.Name;Sid=$sid;ProfilePath=$profile;ProfileKey=$profileKey}
}
function Initialize-UserProfileApi {
    if ('UcDrs.UserProfile' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
namespace UcDrs {
 public static class UserProfile {
  [DllImport("userenv.dll",CharSet=CharSet.Unicode,ExactSpelling=true)]
  static extern int CreateProfile(string sid,string user,StringBuilder path,uint length);
  public static string Create(string sid,string user) {
   StringBuilder path=new StringBuilder(32768);
   int result=CreateProfile(sid,user,path,(uint)path.Capacity);
   if(result<0)Marshal.ThrowExceptionForHR(result);
   return path.ToString();
  }
 }
}
'@
}
function New-LocalSftpProfile($Account) {
    Initialize-UserProfileApi
    $path=[UcDrs.UserProfile]::Create($Account.Sid,$Account.Name)
    $null=Assert-SafeLocalDirectory $path
    # Require Windows to register the profile, not just create a similarly named directory.
    $actual=Get-LocalSftpAccount $Account.Name
    if (-not $actual.ProfilePath -or $actual.ProfilePath -ine $path) { throw 'Windows profile creation could not be verified.' }
    return $actual
}
function Get-LocalSftpState([string]$Username) {
    $account=Get-LocalSftpAccount $Username
    $cap=Get-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' -ErrorAction Stop
    if (@($cap).Count -ne 1 -or "$($cap.State)" -notin @('Installed','NotPresent')) { throw 'OpenSSH Server capability is unavailable or in a pending state. Resolve Windows servicing first.' }
    $service=Get-CimInstance Win32_Service -Filter "Name='sshd'" -ErrorAction Stop
    $binary=Join-Path $env:WINDIR 'System32\OpenSSH\sshd.exe'
    if ($service) {
        $configured="$($service.PathName)".Trim().Trim('"')
        if ($configured -ine $binary) { throw 'Existing sshd uses a custom installation or arguments. Local setup will not replace it; review that host configuration manually.' }
        if ("$($cap.State)" -ne 'Installed') { throw 'An existing sshd service does not match the inbox capability; no duplicate installation will be attempted.' }
    } elseif ("$($cap.State)" -eq 'Installed') { throw 'OpenSSH capability is installed but sshd service is missing. Repair the existing installation first.' }
    $config=Join-Path $env:ProgramData 'ssh\sshd_config'
    $configHash=''
    if (Test-Path -LiteralPath $config) {
        $raw=Get-Content -LiteralPath $config -Raw -ErrorAction Stop
        Assert-StandardSftpConfiguration $raw
        $configHash=(Get-FileHash -LiteralPath $config -Algorithm SHA256).Hash
    }
    $addresses=@(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.AddressState -eq 'Preferred' } | Select-Object -ExpandProperty IPAddress)
    $sshGroup=Get-LocalGroup -Name 'OpenSSH Users' -ErrorAction SilentlyContinue
    $groupSid='';$groupMember=$false
    if ($sshGroup) {
        $groupSid=$sshGroup.SID.Value
        $groupMember=@(Get-LocalGroupMember -SID $sshGroup.SID -ErrorAction Stop | Where-Object { $_.SID.Value -eq $account.Sid }).Count -gt 0
    }
    $defaultRule=@(Get-NetFirewallRule -Name OpenSSH-Server-In-TCP -ErrorAction SilentlyContinue)
    return [pscustomobject]@{Account=$account;CapabilityState="$($cap.State)";ServiceState=$(if($service){$service.State}else{'Missing'});
        StartMode=$(if($service){$service.StartMode}else{'Missing'});Binary=$binary;ConfigPath=$config;ConfigHash=$configHash;
        Addresses=@($addresses | Sort-Object);OpenSshGroupSid=$groupSid;OpenSshGroupMember=$groupMember;DefaultRuleExisted=($defaultRule.Count -gt 0);DefaultRuleEnabled=(@($defaultRule | Where-Object Enabled -eq True).Count -gt 0)}
}
function Assert-StandardSftpConfiguration([string]$Text) {
    $subsystems=0
    foreach ($line in ($Text -split '\r?\n')) {
        $s=($line -replace '\s+#.*$','').Trim()
        if (-not $s -or $s.StartsWith('#')) { continue }
        # Custom homes/chroots/includes can make profile-relative paths incorrect.
        # Preserve the configuration and stop rather than rewrite or guess.
        if ($s -match '^(?i:Include|ChrootDirectory|ForceCommand)\s+') { throw 'Custom SSH include/chroot/forced-command configuration needs manual SFTP path review; no sshd_config rewrite is performed.' }
        if ($s -match '^(?i:Port)\s+(\S+)' -and $Matches[1] -ne '22') { throw 'Local setup currently requires SSH/SFTP port 22.' }
        if ($s -match '^(?i:Subsystem)\s+sftp\s+(.+)$') {
            $subsystems++
            if ($Matches[1] -notmatch '^(?i:sftp-server\.exe|internal-sftp)$') { throw 'Custom SFTP subsystem arguments/path need manual review.' }
        }
    }
    if ($subsystems -ne 1) { throw 'Expected one standard SFTP subsystem in existing sshd_config.' }
}
function New-LocalSftpPlan([object[]]$Targets,$State,[string[]]$Sources) {
    if (-not $Targets.Count) { throw 'No local SFTP targets selected.' }
    $sites=@($Targets.Site | Sort-Object -Unique)
    $users=@($Targets | ForEach-Object {$_.Settings.SftpUsername} | Sort-Object -Unique)
    $addresses=@($Targets | ForEach-Object {$_.Settings.SftpAddress} | Sort-Object -Unique)
    if ($sites.Count -ne 1 -or $users.Count -ne 1 -or $addresses.Count -ne 1) { throw 'Local setup handles one site, one local SFTP username and one local SFTP address per run.' }
    if ($users[0] -ine $State.Account.Name) { throw 'The local account must match every selected target SftpUsername.' }
    if ($addresses[0] -notin $State.Addresses) { throw 'The configured SFTP address is not a preferred IPv4 address on this Windows computer. Run setup on that site SFTP server.' }
    $paths=New-Object System.Collections.Generic.List[string]
    foreach ($target in $Targets) {
        $paths.Add((ConvertTo-SftpRelativePath $target.Settings.WeeklyPath))
        if ($target.Settings.MonthlyDay -gt 0) { $paths.Add((ConvertTo-SftpRelativePath $target.Settings.MonthlyPath)) }
    }
    $sources=@(ConvertTo-SftpRemoteAddress $Sources)
    return [pscustomobject]@{Site=$sites[0];Username=$State.Account.Name;Sid=$State.Account.Sid;Address=$addresses[0];
        AddOpenSshGroupMember=([bool]$State.OpenSshGroupSid -and -not $State.OpenSshGroupMember);
        ProfilePath=$State.Account.ProfilePath;CreateProfile=(-not $State.Account.ProfilePath);InstallServer=($State.CapabilityState -ne 'Installed');
        StartService=($State.ServiceState -ne 'Running');SetAutomatic=($State.StartMode -ne 'Auto');
        Paths=@($paths.ToArray() | Sort-Object -Unique);RemoteAddress=$sources;FirewallRule="UC-DRS-SFTP-$($sites[0])";State=$State}
}
function Get-LocalSetupFingerprint($State) {
    $data=$State | ConvertTo-Json -Depth 8 -Compress
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($data))).Replace('-','') } finally { $sha.Dispose() }
}
function Get-SftpFolderSpecs([string]$ProfilePath,[string[]]$RelativePaths) {
    $root=Assert-SafeLocalDirectory (Join-Path $ProfilePath 'SFTPBackups')
    $all=New-Object System.Collections.Generic.List[string]; $all.Add($root)
    foreach ($path in $RelativePaths) {
        $parts=(ConvertTo-SftpRelativePath $path) -split '/';$current=$ProfilePath
        foreach ($part in $parts) { $current=Join-Path $current $part; $null=Assert-SafeLocalDirectory $current; if ($current -notin $all) {$all.Add($current)} }
    }
    return @($all.ToArray() | Sort-Object Length, {$_})
}
function Get-SftpPermissionSpec([string]$Sid,[bool]$NewRoot) {
    if ($Sid -notmatch '^S-1-5-21-(?:[0-9]+-){3}[0-9]+$') { throw 'Expected a local account SID for folder grants.' }
    if ($NewRoot) {
        [pscustomobject]@{Sid='S-1-5-18';Rights='FullControl'}
        [pscustomobject]@{Sid='S-1-5-32-544';Rights='FullControl'}
    }
    [pscustomobject]@{Sid=$Sid;Rights='Modify'}
}
function Set-SftpFolderPermission([string]$Path,[string]$Sid,[bool]$NewRoot) {
    $null=Assert-SafeLocalDirectory $Path
    $grants=@(Get-SftpPermissionSpec $Sid $NewRoot)
    $acl=Get-Acl -LiteralPath $Path -ErrorAction Stop
    if ($NewRoot) {
        # Only the newly created SFTPBackups root receives a private baseline.
        # Never reset an existing tree's ACLs, recurse through backup files, or
        # grant access to Everyone/Users. Existing explicit entries are preserved.
        $acl.SetAccessRuleProtection($true,$false)
        foreach ($rule in @($acl.Access)) { $null=$acl.RemoveAccessRuleSpecific($rule) }
        foreach ($grantSpec in @($grants | Where-Object Rights -eq 'FullControl')) {
            $rule=[Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($grantSpec.Sid),$grantSpec.Rights,'ContainerInherit,ObjectInherit','None','Allow')
            $acl.AddAccessRule($rule)
        }
    }
    $userSid=[Security.Principal.SecurityIdentifier]::new($Sid)
    foreach ($entry in $acl.Access) {
        if ($entry.AccessControlType -eq 'Deny') { throw "Existing deny ACL on $Path requires manual permission review; it will not be removed." }
    }
    $grant=[Security.AccessControl.FileSystemAccessRule]::new($userSid,'Modify','ContainerInherit,ObjectInherit','None','Allow')
    $needed=[int][Security.AccessControl.FileSystemRights]::Modify
    $present=@($acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]) | Where-Object {
        $_.IdentityReference.Value -eq $Sid -and $_.AccessControlType -eq 'Allow' -and
        (([int]$_.FileSystemRights -band $needed) -eq $needed) -and
        (([int]$_.InheritanceFlags -band 3) -eq 3) -and $_.PropagationFlags -eq 'None'
    }).Count -gt 0
    if (-not $present) { $acl.AddAccessRule($grant) }
    if ($NewRoot -or -not $present) { Set-Acl -LiteralPath $Path -AclObject $acl -ErrorAction Stop }
    $verified=Get-Acl -LiteralPath $Path -ErrorAction Stop
    $rules=@($verified.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]) | Where-Object {
        $_.IdentityReference.Value -eq $Sid -and $_.AccessControlType -eq 'Allow' -and
        (([int]$_.FileSystemRights -band $needed) -eq $needed) -and $_.PropagationFlags -eq 'None'
    })
    if (-not $rules.Count) { throw 'Could not verify the requested directory Modify grant.' }
    return $verified.Sddl
}
function Ensure-SftpFolders($Context,$Plan) {
    $root=Join-Path $Plan.ProfilePath 'SFTPBackups'
    $specs=@(Get-SftpFolderSpecs $Plan.ProfilePath $Plan.Paths)
    foreach ($path in $specs) {
        # Recheck immediately before mutation; directory creation is not a transaction.
        $null=Assert-SafeLocalDirectory $path
        $existed=Test-Path -LiteralPath $path
        $before=if($existed){(Get-Acl -LiteralPath $path).Sddl}else{$null}
        Write-Audit $Context 'local_folder_intent' @{Path=$path;Existed=$existed;BeforeSddl=$before;AccountSid=$Plan.Sid}
        if (-not $existed) { $null=[IO.Directory]::CreateDirectory($path) }
        $sddl=Set-SftpFolderPermission $path $Plan.Sid (-not $existed -and $path -ieq $root)
        Write-Audit $Context 'local_folder_verified' @{Path=$path;Sddl=$sddl;Limit='ACL grant verified, not an authenticated SFTP write test.'}
    }
}
function Get-SftpFirewallRuleState([string]$Name) {
    $rule=@(Get-NetFirewallRule -Name $Name -ErrorAction SilentlyContinue)
    if (-not $rule.Count) { return $null }
    if ($rule.Count -ne 1) { throw 'Ambiguous local SFTP firewall rule identity.' }
    $address=$rule[0] | Get-NetFirewallAddressFilter -ErrorAction Stop
    $port=$rule[0] | Get-NetFirewallPortFilter -ErrorAction Stop
    return [pscustomobject]@{Name=$Name;Description=$rule[0].Description;Enabled="$($rule[0].Enabled)";Direction="$($rule[0].Direction)";
        Action="$($rule[0].Action)";Profile=("$($rule[0].Profile)" -replace '\s','');LocalAddress=@($address.LocalAddress);RemoteAddress=@($address.RemoteAddress);
        Protocol="$($port.Protocol)";LocalPort="$($port.LocalPort)"}
}
function Test-SftpFirewallRule($Rule,$Plan) {
    if (-not $Rule) { return $false }
    return ($Rule.Description -eq 'Managed by UC DRS local SFTP setup' -and $Rule.Enabled -eq 'True' -and
        $Rule.Direction -eq 'Inbound' -and $Rule.Action -eq 'Allow' -and $Rule.Profile -eq 'Domain,Private' -and
        $Rule.Protocol -in @('TCP','6') -and $Rule.LocalPort -eq '22' -and
        ((@($Rule.LocalAddress | Sort-Object) -join ',') -eq $Plan.Address) -and
        ((@($Rule.RemoteAddress | Sort-Object) -join ',') -eq (@($Plan.RemoteAddress | Sort-Object) -join ',')))
}
function Invoke-LocalSftpSetup($Context,[object[]]$Targets,$Caller,[bool]$DoApply,[string[]]$Sources) {
    if (-not (Test-WindowsAdministrator)) { throw 'Local OpenSSH capability inspection/setup requires an elevated 64-bit PowerShell window on the SFTP server.' }
    $users=@($Targets | ForEach-Object {$_.Settings.SftpUsername} | Sort-Object -Unique)
    if ($users.Count -ne 1) { throw 'Select one local SFTP username for this host setup.' }
    $state=Get-LocalSftpState $users[0]
    if (-not $Sources.Count) { $Sources=@(Read-Value 'UC source IPv4 addresses/CIDRs allowed to reach this server (comma-separated; include backup subscribers)') }
    $plan=New-LocalSftpPlan $Targets $state $Sources
    if ($plan.ProfilePath) { $null=Get-SftpFolderSpecs $plan.ProfilePath $plan.Paths }
    $existingRule=Get-SftpFirewallRuleState $plan.FirewallRule
    if ($existingRule -and -not (Test-SftpFirewallRule $existingRule $plan)) { throw 'An existing same-name firewall rule differs from this plan. Review it manually; it will not be overwritten.' }
    Write-Host "`nLocal SFTP setup on $env:COMPUTERNAME ($($plan.Address)); site $($plan.Site)" -ForegroundColor Cyan
    Write-Host "Account: $($plan.Username) [$($plan.Sid)]"
    Write-Host "Profile: $(if($plan.CreateProfile){'Create through Windows profile API, then use its registered path'}else{$plan.ProfilePath})"
    Write-Host "Install OpenSSH Server: $($plan.InstallServer); start sshd: $($plan.StartService); Automatic startup: $($plan.SetAutomatic)"
    Write-Host "Folders below the user profile: $($plan.Paths -join ', ')"
    Write-Host "OpenSSH Users: add this account if Windows provides the group and membership is absent."
    Write-Host "New root: private ACL. Existing folders: preserve entries and add user Modify where absent."
    Write-Host "Firewall: TCP/22 on $($plan.Address), Domain/Private profiles, from $($plan.RemoteAddress -join ', ')"
    if ($state.DefaultRuleExisted) { Write-Warning 'Existing OpenSSH firewall rules are preserved. They or other rules may allow broader access than the new scoped rule; review effective firewall policy.' }
    elseif ($plan.InstallServer) { Write-Host 'The broad default rule created by a fresh Windows installation will be disabled before sshd is started.' }
    Write-Host 'Existing sshd_config is preserved. This enables ordinary Windows SSH/SFTP, not an SFTP-only jail.'
    Write-Audit $Context 'local_setup_plan' $plan
    if (-not $DoApply) { Write-Host 'Local setup preview only. Add -Apply to perform these local changes.'; return }
    if (-not $Caller.ShouldProcess("$env:COMPUTERNAME / $($plan.Username)",'Install/configure local OpenSSH Server, create backup folders and scoped firewall rule')) { return }
    if (-not (Confirm-Choice 'Apply this local SFTP setup plan?')) { Write-Host 'Local setup cancelled.'; return }
    if ((Get-LocalSetupFingerprint (Get-LocalSftpState $users[0])) -ne (Get-LocalSetupFingerprint $state)) { throw 'Local account/service/configuration changed after preview; rerun.' }
    Write-Audit $Context 'local_setup_intent' @{Site=$plan.Site;Account=$plan.Username}
    if ($plan.InstallServer) {
        $installed=Add-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0' -ErrorAction Stop
        Write-Audit $Context 'local_capability_result' @{RestartNeeded=[bool]$installed.RestartNeeded}
        # Do not leave the feature install's new broad rule enabled even when a
        # reboot is required. Existing rules are not ours to silently narrow.
        if (-not $state.DefaultRuleExisted -and (Get-NetFirewallRule -Name OpenSSH-Server-In-TCP -ErrorAction SilentlyContinue)) {
            Disable-NetFirewallRule -Name OpenSSH-Server-In-TCP -ErrorAction Stop | Out-Null
        }
        if ($installed.RestartNeeded) { throw 'Windows reports a restart is required. No reboot was performed; complete normal maintenance and rerun setup.' }
        if ("$((Get-WindowsCapability -Online -Name 'OpenSSH.Server~~~~0.0.1.0').State)" -ne 'Installed') { throw 'OpenSSH installation was not verified.' }
    }
    if ($plan.CreateProfile) {
        $account=New-LocalSftpProfile $state.Account
        $plan.ProfilePath=$account.ProfilePath
        Write-Audit $Context 'local_profile_created' @{Sid=$account.Sid;Path=$account.ProfilePath}
    }
    # Windows may introduce this group during installation (not all releases use it).
    $sshGroup=Get-LocalGroup -Name 'OpenSSH Users' -ErrorAction SilentlyContinue
    if ($sshGroup -and @((Get-LocalGroupMember -SID $sshGroup.SID -ErrorAction Stop) | Where-Object { $_.SID.Value -eq $plan.Sid }).Count -eq 0) {
        Add-LocalGroupMember -SID $sshGroup.SID -Member $plan.Sid -ErrorAction Stop
        if (@(Get-LocalGroupMember -SID $sshGroup.SID -ErrorAction Stop | Where-Object { $_.SID.Value -eq $plan.Sid }).Count -ne 1) { throw 'OpenSSH Users group membership could not be verified.' }
        Write-Audit $Context 'local_ssh_group_verified' @{GroupSid=$sshGroup.SID.Value;AccountSid=$plan.Sid}
    }
    Ensure-SftpFolders $Context $plan
    if (-not $existingRule) {
        New-NetFirewallRule -Name $plan.FirewallRule -DisplayName "UC DRS SFTP ($($plan.Site))" -Description 'Managed by UC DRS local SFTP setup' `
            -Enabled True -Direction Inbound -Protocol TCP -Action Allow -LocalPort 22 -LocalAddress $plan.Address `
            -RemoteAddress $plan.RemoteAddress -Profile Domain,Private -ErrorAction Stop | Out-Null
    }
    if (-not (Test-SftpFirewallRule (Get-SftpFirewallRuleState $plan.FirewallRule) $plan)) { throw 'Scoped firewall rule could not be verified.' }
    if ($plan.SetAutomatic) { Set-Service -Name sshd -StartupType Automatic -ErrorAction Stop }
    if ($plan.StartService) { Start-Service -Name sshd -ErrorAction Stop }
    $service=Get-CimInstance Win32_Service -Filter "Name='sshd'" -ErrorAction Stop
    if ($service.State -ne 'Running' -or $service.StartMode -ne 'Auto') { throw 'sshd service/startup verification failed.' }
    if (-not (Test-Path -LiteralPath $state.ConfigPath)) { throw 'sshd_config was not generated; inspect the Windows service logs.' }
    Assert-StandardSftpConfiguration (Get-Content -LiteralPath $state.ConfigPath -Raw)
    if ($state.ConfigHash -and (Get-FileHash -LiteralPath $state.ConfigPath -Algorithm SHA256).Hash -ne $state.ConfigHash) { throw 'Existing sshd_config changed during setup; inspect before continuing.' }
    $listeners=@(Get-NetTCPConnection -State Listen -LocalPort 22 -ErrorAction Stop | Where-Object { $_.OwningProcess -eq $service.ProcessId -and $_.LocalAddress -in @('0.0.0.0','::',$plan.Address) })
    if (-not $listeners.Count) { throw 'Could not verify that sshd listens on the selected address/port.' }
    Write-Audit $Context 'local_setup_complete' @{Address=$plan.Address;Account=$plan.Username;Profile=$plan.ProfilePath;Folders=$plan.Paths;
        Status='local_configuration_verified';SftpLogin='not_tested';UcReachability='not_tested';Backup='not_run'}
    Write-Host 'Local configuration verified. Test SFTP login and file creation as the selected account, then test a backup from UC.' -ForegroundColor Green
}

function Invoke-UcDrsMain($Caller) {
    $ErrorActionPreference='Stop'
    if ($env:OS -ne 'Windows_NT') { throw 'Run this operator tool on Windows. Dot-sourcing for isolated tests is supported elsewhere.' }
    if ($SetupLocalSftp -and $InstallDependencies) { throw 'Local SFTP setup uses native Windows tools, not Posh-SSH. Omit -InstallDependencies for this mode.' }
    if ($SetupLocalSftp -and ($ReadOnly -or $ManageExisting)) { throw '-SetupLocalSftp is a separate mode; omit -ReadOnly and -ManageExisting. Without -Apply it previews only.' }
    if ($SftpRemoteAddress -and -not $SetupLocalSftp) { throw '-SftpRemoteAddress requires -SetupLocalSftp.' }
    if ($ManageExisting -and (-not $Apply -or $ReadOnly)) { throw '-ManageExisting requires -Apply and is not available with -ReadOnly.' }
    if ($ReadOnly -and $Apply) { throw '-ReadOnly and -Apply cannot be combined.' }
    if (($ReadOnly -or $WhatIfPreference) -and ($InstallDependencies -or $SaveProfile)) { throw 'Inspection/WhatIf cannot install dependencies or save profiles. Run that setup separately.' }
    $context=$null; $results=New-Object System.Collections.Generic.List[object]
    try {
        $context=New-RunContext $LogPath $CredentialMode (-not ($WhatIfPreference -or $ReadOnly))
        Write-Host "UC DRS v1.6.1 testing release. Log: $($context.LogPath)" -ForegroundColor Cyan
        Write-Audit $context 'run_started' @{Apply=[bool]$Apply;ReadOnly=[bool]$ReadOnly;WhatIf=[bool]$WhatIfPreference;ScriptVersion='1.6.1'}
        $context.AllowRemoteWrite=[bool]($Apply -and -not $ReadOnly -and -not $WhatIfPreference)
        if (-not $SetupLocalSftp) {
            $module=Initialize-PoshSsh -Install:$InstallDependencies -Version $PoshSshVersion
            Write-Audit $context 'dependency' @{PoshSSH=$module;PowerShell=$PSVersionTable.PSVersion.ToString()}
        }
        $targets=@(Import-UcTargets $Csv $Profile)
        if (-not $Csv -and -not $Profile) {
            $source=Read-Choice 'Input source' @('Wizard','CSV','Profile') 'Wizard'
            if ($source -eq 'CSV') { $targets=@(Import-UcTargets (Read-Value 'CSV path') '') }
            elseif ($source -eq 'Profile') { $targets=@(Import-UcTargets '' (Read-Value 'JSON profile path')) }
        }
        $targets=@(Read-UcTargetSelection $targets)
        if (-not $ReadOnly -and -not $ManageExisting) {
            foreach ($target in $targets) {
                if ($target.Settings) { $target.Settings=ConvertTo-BackupSettings $target.Settings }
                else { $target.Settings=Read-BackupSettings $target }
            }
            Test-DestinationCollisions $targets
        }
        if ($SaveProfile) { Save-UcProfile $targets $SaveProfile; Write-Host "Nonsecret profile saved: $SaveProfile" }
        if ($SetupLocalSftp) {
            Invoke-LocalSftpSetup $context $targets $Caller ([bool]$Apply) $SftpRemoteAddress
            return 0
        }
        foreach ($target in $targets) {
            $connection=$null
            $result=[ordered]@{Site=$target.Site;Id=$target.Id;Technology=$target.Technology;Address=$target.Address;
                ConfigurationStatus='not_attempted';CoverageStatus='unknown';BackupExecutionStatus='not_run';Details=''}
            try {
                Write-Host "`nInspecting $($target.Technology) $($target.Address) ..." -ForegroundColor Cyan
                $connection=Open-UcConnection $context $target
                $discovery=Get-DrsDiscovery $context $connection $target
                Show-Coverage $discovery.Coverage; $result.CoverageStatus=$discovery.Coverage.Status
                Write-Host ($discovery.Snapshot | ConvertTo-Json -Depth 6)
                if ($ReadOnly) { $result.ConfigurationStatus='inspection_complete'; continue }
                if ($discovery.Coverage.Status -eq 'blocked') { throw "Coverage blocked: $($discovery.Coverage.Issues -join '; ')" }
                if (-not (Confirm-Choice 'Does this list contain every expected node, with the correct product and publisher endpoint?')) { throw 'Topology not confirmed. No writes performed.' }
                if ($target.Technology -eq 'CER') { Write-Warning 'CER 14SU2+: verify required tomcat/tomcat-ecdsa certificate exchange between publisher and subscriber before backup.' }
                if ($ManageExisting) {
                    Invoke-DrsMaintenance $context $connection $discovery.Snapshot $Caller
                    $result.ConfigurationStatus=if($WhatIfPreference){'whatif_only'}else{'maintenance_complete'}
                    continue
                }
                $nodeNow=Read-NodeClock $context $connection
                $plan=New-DrsPlan $target $discovery $nodeNow
                Show-DrsPlan $plan
                Write-Audit $context 'plan' $plan
                if (-not $Apply) { $result.ConfigurationStatus='preview_only'; continue }
                if (-not $WhatIfPreference -and -not (Confirm-Choice 'Apply the displayed create operations to this environment?')) { $result.ConfigurationStatus='skipped'; continue }
                $outcomes=@(Invoke-DrsPlan $context $connection $plan $Caller)
                $result.ConfigurationStatus=if ($WhatIfPreference) {'whatif_only'} elseif (@($outcomes | Where-Object Status -ne 'created_enabled_verified_limited').Count) {'partial_or_unverified'} else {'created_enabled_verified_limited'}
                $result.Details=($outcomes | ConvertTo-Json -Compress)
            } catch {
                # The transport never puts secret exchange text in exceptions.
                $message=Protect-Text $context $_.Exception.Message
                $result.ConfigurationStatus='stopped_review_required'; $result.Details=$message
                Write-Warning "$($target.Id): $message"
                try { Write-Audit $context 'target_stopped' @{Target=$target.Id;Message=$message;Action='Inspect readback and reconcile write intents before rerunning.'} }
                catch { throw 'Audit log became unavailable; stopping the whole run.' }
                if (@($context.PendingWrites | Where-Object Address -eq $target.Address).Count -gt 0) {
                    Close-UcConnection $context $connection; $connection=$null
                    Invoke-ReadbackReconciliation $context $target
                }
            } finally {
                Close-UcConnection $context $connection
                $results.Add([pscustomobject]$result)
                Write-Audit $context 'target_result' $result
            }
        }
        Write-Host "`n=== SUMMARY ===" -ForegroundColor Cyan
        $results | Format-Table Id,Technology,ConfigurationStatus,CoverageStatus,BackupExecutionStatus -AutoSize | Out-Host
        Write-Host "Audit: $($context.LogPath)"
        Write-Host 'No backup or restore was executed. Existing names may need manual DRS verification.'
        $failed=@($results | Where-Object { $_.ConfigurationStatus -eq 'stopped_review_required' -or $_.CoverageStatus -eq 'blocked' }).Count -gt 0
        $incomplete=@($results | Where-Object ConfigurationStatus -eq 'partial_or_unverified').Count -gt 0
        Write-Audit $context 'run_finished' @{Failed=$failed;Incomplete=$incomplete;CleanupFailed=$context.CleanupFailed}
        if ($failed -or $context.CleanupFailed) { return 1 }; if ($incomplete) { return 2 }; return 0
    } finally { if ($context) { $context.Secrets.Clear() }; $context=$null }
}

function Assert-SnapshotPreserved($Before,$After,[string]$AddedName) {
    foreach ($kind in @('Devices','Schedules')) {
        $old=@($Before.$kind | Sort-Object Name)
        $retained=@($After.$kind | Where-Object Name -ne $AddedName | Sort-Object Name)
        if (($old | ConvertTo-Json -Depth 6 -Compress) -cne ($retained | ConvertTo-Json -Depth 6 -Compress)) {
            throw "Unexpected change in other $kind; stop and review the before/after audit data."
        }
    }
}
function Invoke-DrsMaintenance($Context,$Connection,$InitialSnapshot,$Caller) {
    Write-Host 'Maintenance mode: no new devices or schedules will be created.' -ForegroundColor Yellow
    Write-Warning 'List output is not a restorable export. Record full settings in DRS before deleting anything.'
    $snapshot=$InitialSnapshot
    while ($true) {
        Write-Host ($snapshot | ConvertTo-Json -Depth 6)
        $action=Read-Choice 'Maintenance action' @('Done','DisableSchedule','DeleteSchedule','DeleteDevice') 'Done'
        if ($action -eq 'Done') { return }
        $name=Assert-Token (Read-Value 'Exact existing name') 'existing name'
        $kind=if ($action -eq 'DeleteDevice') {'device'}else{'schedule'}
        $collection=if($kind -eq 'device'){@($snapshot.Devices)}else{@($snapshot.Schedules)}
        if (@($collection | Where-Object Name -eq $name).Count -ne 1) { Write-Warning 'Name not found.'; continue }
        if ($kind -eq 'device' -and @($snapshot.Schedules | Where-Object Device -eq $name).Count) { Write-Warning 'Device is referenced by a schedule. Resolve that dependency first.'; continue }
        if ($action -like 'Delete*') {
            if (-not (Confirm-Choice 'Have you recorded the complete settings needed to recreate this object, including access to its credentials?')) { continue }
            if ((Read-Host "Type DELETE $name to confirm permanent removal") -cne "DELETE $name") { Write-Host 'Deletion cancelled.'; continue }
        } elseif (-not (Confirm-Choice "Disable schedule $name?")) { continue }
        if (-not $Caller.ShouldProcess("$($Connection.Address): $name",$action)) { continue }
        $fresh=Get-DrsSnapshot $Context $Connection
        if ((Get-SnapshotFingerprint $fresh) -ne (Get-SnapshotFingerprint $snapshot)) { throw 'Configuration changed during maintenance selection. Rerun inspection.' }
        $verb=if ($action -eq 'DisableSchedule') {'disable'}else{'delete'}
        Write-Audit $Context 'maintenance_before' $snapshot
        $r=Send-UcCommand $Context $Connection "utils disaster_recovery $kind $verb $name" None -Mutation
        Assert-CliSuccess $r.Text
        $after=Get-DrsSnapshot $Context $Connection
        $observed=if($kind -eq 'device'){@($after.Devices | Where-Object Name -eq $name)}else{@($after.Schedules | Where-Object Name -eq $name)}
        if ($verb -eq 'delete' -and $observed.Count) { throw 'Deletion could not be verified.' }
        if ($verb -eq 'disable' -and ($observed.Count -ne 1 -or $observed[0].Status -ne 'disabled')) { throw 'Disabled state could not be verified.' }
        foreach ($property in @('Devices','Schedules')) {
            $skip=($property -eq 'Devices' -and $kind -eq 'device') -or ($property -eq 'Schedules' -and $kind -eq 'schedule')
            $beforeOther=@($snapshot.$property | Where-Object { -not $skip -or $_.Name -ne $name } | Sort-Object Name)
            $afterOther=@($after.$property | Where-Object { -not $skip -or $_.Name -ne $name } | Sort-Object Name)
            if (($beforeOther | ConvertTo-Json -Compress) -cne ($afterOther | ConvertTo-Json -Compress)) { throw 'Other DRS objects changed during maintenance; review audit evidence.' }
        }
        Complete-DrsWrite $Context $r.OperationId "$action verified by readback; other list entries unchanged."
        Write-Audit $Context 'maintenance_after' $after
        $snapshot=$after
        Write-Host "${name}: $action verified." -ForegroundColor Green
    }
}
function Invoke-ReadbackReconciliation($Context,$Target) {
    $pending=@($Context.PendingWrites | Where-Object Address -eq $Target.Address)
    if (-not $pending.Count) { return }
    Write-Warning 'A write is unresolved. A fresh read-only connection will attempt to capture current lists; no commands will be replayed.'
    $connection=$null; $remote=$Context.AllowRemoteWrite; $local=$Context.AllowLocalWrite
    try {
        $Context.AllowRemoteWrite=$false; $Context.AllowLocalWrite=$false
        $connection=Open-UcConnection $Context $Target
        $snapshot=Get-DrsSnapshot $Context $connection
        Write-Audit $Context 'uncertain_write_readback' @{Target=$Target.Id;Pending=$pending;Snapshot=$snapshot;
            Resolution='Operator reconciliation required. Name/status readback cannot prove every intended field.'}
        Write-Host ($snapshot | ConvertTo-Json -Depth 6)
    } catch {
        try { Write-Audit $Context 'reconciliation_unavailable' @{Target=$Target.Id;Pending=$pending;Message=(Protect-Text $Context $_.Exception.Message)} } catch { Write-Warning 'Could not log reconciliation failure.' }
        Write-Warning 'Readback reconciliation was unavailable. Inspect DRS manually before rerunning.'
    } finally { Close-UcConnection $Context $connection; $Context.AllowRemoteWrite=$remote; $Context.AllowLocalWrite=$local }
}

if ($MyInvocation.InvocationName -ne '.') {
    try { $exitCode=Invoke-UcDrsMain $PSCmdlet; exit $exitCode }
    catch { Write-Error $_.Exception.Message -ErrorAction Continue; exit 1 }
}
