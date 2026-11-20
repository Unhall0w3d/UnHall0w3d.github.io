# Offline tests for local provisioning. All service/capability/firewall/file ACL
# operations are mocked; this file never installs software or changes Windows.
param([string]$ScriptPath=(Join-Path $PSScriptRoot 'Set-UC-DRSBackupSchedules-v1.6.2.ps1'))
$ErrorActionPreference='Stop'
. $ScriptPath
$script:Passed=0
function Assert($Condition,[string]$Message) {if(-not $Condition){throw "FAILED: $Message"};$script:Passed++;Write-Host "PASS $Message"}
function Throws([scriptblock]$Body,[string]$Message){$caught=$false;try{& $Body}catch{$caught=$true};Assert $caught $Message}
Assert ((ConvertTo-SftpRelativePath 'SFTPBackups/Site/Voice/Weekly/') -eq 'SFTPBackups/Site/Voice/Weekly') 'safe profile-relative path normalized'
foreach($path in @('/SFTPBackups/x','C:/Users/x','SFTPBackups/../other','SFTPBackups//x','SFTPBackups/CON.txt','SFTPBackups/x.','SFTPBackups/x;command')){
 Throws {ConvertTo-SftpRelativePath $path} "reject unsafe path $path"
}
Assert ((@(ConvertTo-SftpRemoteAddress @('192.0.2.15/24','192.0.2.2/32','192.0.2.2')) -join ',') -eq '192.0.2.0/24,192.0.2.2') 'source scopes canonicalized and deduplicated'
foreach($ip in @('Any','0.0.0.0/0','192.0.2.1/0','192.0.2.1/33','127.0.0.1','224.1.1.1','::1','192.0.2.1;command')){Throws {ConvertTo-SftpRemoteAddress @($ip)} "reject invalid source $ip"}
Assert-StandardSftpConfiguration "# Default`nSubsystem sftp sftp-server.exe`nMatch Group administrators`n AuthorizedKeysFile __PROGRAMDATA__/ssh/administrators_authorized_keys"
Assert $true 'standard Windows SSH config accepted without rewrite'
foreach($config in @('Include other.conf','ChrootDirectory C:/jail','ForceCommand internal-sftp','Port 2222','Subsystem sftp sftp-server.exe -d C:/other')){
 Throws {Assert-StandardSftpConfiguration ("Subsystem sftp sftp-server.exe`n"+$config)} "custom mapping rejected: $config"
}
Initialize-UserProfileApi
Assert ($null -ne ('UcDrs.UserProfile' -as [type])) 'native profile API wrapper compiles without calling Windows'
$t=ConvertTo-UcTarget ([pscustomobject]@{Site='Example';Id='Voice';Technology='CUCM';Address='192.0.2.10';Username='admin';ImpTopology='None';Settings=[pscustomobject]@{
 SftpAddress='192.0.2.50';SftpUsername='backup';Retention=2;WeeklyName='Weekly';MonthlyName='Monthly';WeeklyPath='SFTPBackups/Example/Voice/Weekly/';MonthlyPath='SFTPBackups/Example/Voice/Monthly/';MonthlyDay=1;WeeklyDay='Tuesday';WeeklyTime='01:00';MonthlyTime='01:00'}})
$state=[pscustomobject]@{Account=[pscustomobject]@{Name='backup';Sid='S-1-5-21-1-2-3-1001';ProfilePath='';ProfileKey='test'};
 CapabilityState='NotPresent';ServiceState='Missing';StartMode='Missing';Binary='/mock/sshd.exe';ConfigPath='/mock/sshd_config';ConfigHash='';Addresses=@('192.0.2.50');
 DefaultRuleExisted=$false;DefaultRuleEnabled=$false;OpenSshGroupSid='';OpenSshGroupMember=$false}
$plan=New-LocalSftpPlan @($t) $state @('192.0.2.0/24')
Assert ($plan.InstallServer -and $plan.CreateProfile -and $plan.Paths.Count -eq 2) 'missing server/profile produces explicit provisioning plan'
$t.Settings.MonthlyDay=0
Assert ((New-LocalSftpPlan @($t) $state @('192.0.2.0/24')).Paths.Count -eq 1) 'monthly disabled omits monthly folder'
$t.Settings.MonthlyDay=1
$state.Addresses=@('192.0.2.99')
Throws {New-LocalSftpPlan @($t) $state @('192.0.2.0/24')} 'refuse setup when SFTP IP is not local'
$state.Addresses=@('192.0.2.50')
$state.Account.Name='other'
Throws {New-LocalSftpPlan @($t) $state @('192.0.2.0/24')} 'refuse mismatched local account'
$state.Account.Name='backup'
$t2=$t | ConvertTo-Json -Depth 6 | ConvertFrom-Json;$t2.Site='Other'
Throws {New-LocalSftpPlan @($t,$t2) $state @('192.0.2.0/24')} 'separate networks cannot share a setup run'
$rule=[pscustomobject]@{Description='Managed by UC DRS local SFTP setup';Enabled='True';Direction='Inbound';Action='Allow';Profile='Domain,Private';Protocol='TCP';LocalPort='22';LocalAddress=@('192.0.2.50');RemoteAddress=@('192.0.2.0/24')}
Assert (Test-SftpFirewallRule $rule $plan) 'exact scoped firewall rule accepted'
$rule.RemoteAddress=@('Any');Assert (-not (Test-SftpFirewallRule $rule $plan)) 'broad rule is not accepted as scoped setup'
$rule.RemoteAddress=@('192.0.2.0/24')
$expectedRule=$rule | ConvertTo-Json -Depth 5 | ConvertFrom-Json

# Validate accounts with synthetic native cmdlet results.
$originalTestPath=${function:Test-Path}
$script:LocalUser=[pscustomobject]@{Name='backup';Enabled=$true;PrincipalSource='Local';AccountExpires=$null;PasswordExpires=$null;SID=[pscustomobject]@{Value='S-1-5-21-1-2-3-1001'}}
function Get-LocalUser {param($Name,$ErrorAction)return $script:LocalUser}
function Test-Path {param($LiteralPath,$PathType)return $false}
Assert ((Get-LocalSftpAccount backup).ProfilePath -eq '') 'uninitialized local profile identified without inventing path'
$script:LocalUser.Enabled=$false;Throws {Get-LocalSftpAccount backup} 'disabled account rejected';$script:LocalUser.Enabled=$true
$script:LocalUser.PrincipalSource='ActiveDirectory';Throws {Get-LocalSftpAccount backup} 'domain account rejected';$script:LocalUser.PrincipalSource='Local'
$script:LocalUser.AccountExpires=(Get-Date).AddDays(-1);Throws {Get-LocalSftpAccount backup} 'expired account rejected';$script:LocalUser.AccountExpires=$null
Remove-Item function:Test-Path

# Isolated orchestration simulation: observe ordering and all mutation counts.
$script:Calls=New-Object System.Collections.Generic.List[string]
$script:Events=New-Object System.Collections.Generic.List[string]
$script:Capability='NotPresent';$script:ServiceState='Missing';$script:Restart=$false;$script:Rule=$null
$script:ServiceMode='Missing';$script:DefaultRuleExists=$false;$script:DefaultDisabled=$false;$script:Admin=$true
$script:CurrentState=$state
function Test-WindowsAdministrator {return $script:Admin}
function Get-LocalSftpState {param($Username)return $script:CurrentState}
function Get-SftpFolderSpecs {param($ProfilePath,$RelativePaths)return @('/mock/user/SFTPBackups')}
function Get-SftpFirewallRuleState {param($Name)return $script:Rule}
function Write-Audit {param($Context,$Event,$Data)$script:Events.Add($Event)}
function Confirm-Choice {param($Prompt)return $true}
# -Online is a switch in the real command.
function Add-WindowsCapability {param([switch]$Online,$Name,$ErrorAction)$script:Calls.Add('install');$script:Capability='Installed';$script:DefaultRuleExists=$true;[pscustomobject]@{RestartNeeded=$script:Restart}}
function Get-WindowsCapability {param([switch]$Online,$Name,$ErrorAction)[pscustomobject]@{State=$script:Capability}}
function Get-NetFirewallRule {param($Name,$ErrorAction)if($script:DefaultRuleExists){[pscustomobject]@{Name=$Name}}}
function Disable-NetFirewallRule {param($Name,$ErrorAction)$script:Calls.Add('disable-default');$script:DefaultDisabled=$true}
function New-LocalSftpProfile {param($Account)$script:Calls.Add('profile');[pscustomobject]@{Name='backup';Sid=$Account.Sid;ProfilePath='/mock/user'}}
function Get-LocalGroup {param($Name,$ErrorAction)return $null}
function Ensure-SftpFolders {param($Context,$Plan)$script:Calls.Add('folders')}
function New-NetFirewallRule {param($Name,$DisplayName,$Description,$Enabled,$Direction,$Protocol,$Action,$LocalPort,$LocalAddress,$RemoteAddress,$Profile,$ErrorAction)
 $script:Calls.Add('firewall');$script:Rule=[pscustomobject]@{Description=$Description;Enabled="$Enabled";Direction=$Direction;Action=$Action;Profile=($Profile -join ',');Protocol=$Protocol;LocalPort="$LocalPort";LocalAddress=@($LocalAddress);RemoteAddress=@($RemoteAddress)}}
function Set-Service {param($Name,$StartupType,$ErrorAction)$script:Calls.Add('automatic');$script:ServiceMode='Auto'}
function Start-Service {param($Name,$ErrorAction)$script:Calls.Add('start');$script:ServiceState='Running'}
function Get-CimInstance {param($ClassName,$Filter,$ErrorAction)[pscustomobject]@{State=$script:ServiceState;StartMode=$script:ServiceMode;ProcessId=123}}
function Get-NetTCPConnection {param($State,$LocalPort,$ErrorAction)[pscustomobject]@{OwningProcess=123;LocalAddress='0.0.0.0'}}
function Test-Path {param($LiteralPath,$PathType)return $true}
function Get-Content {param($LiteralPath,[switch]$Raw)return 'Subsystem sftp sftp-server.exe'}
$caller=[pscustomobject]@{Permit=$true};$caller | Add-Member ScriptMethod ShouldProcess {param($Target,$Action)return $this.Permit}
Invoke-LocalSftpSetup $null @($t) $caller $false @('192.0.2.0/24')
Assert ($script:Calls.Count -eq 0) 'preview performs zero system mutations'
$caller.Permit=$false
Invoke-LocalSftpSetup $null @($t) $caller $true @('192.0.2.0/24')
Assert ($script:Calls.Count -eq 0) 'ShouldProcess refusal performs zero system mutations'
$caller.Permit=$true;$script:Admin=$false
Throws {Invoke-LocalSftpSetup $null @($t) $caller $true @('192.0.2.0/24')} 'non-elevated setup stops before mutations'
Assert ($script:Calls.Count -eq 0) 'elevation failure is nonmutating';$script:Admin=$true
Invoke-LocalSftpSetup $null @($t) $caller $true @('192.0.2.0/24')
Assert (($script:Calls -join ',') -eq 'install,disable-default,profile,folders,firewall,automatic,start') 'fresh install orders scoped firewall before service startup'
Assert ('local_setup_complete' -in $script:Events) 'completion only after service and listener verification'
$script:Calls.Clear();$script:Events.Clear();$script:Rule=$null;$script:Restart=$true
Throws {Invoke-LocalSftpSetup $null @($t) $caller $true @('192.0.2.0/24')} 'Windows restart requirement stops setup without reboot'
Assert (($script:Calls -join ',') -eq 'install,disable-default') 'installer-created broad rule disabled even when restart is needed'
Assert ('local_setup_complete' -notin $script:Events) 'partial install is not marked complete'
$script:Restart=$false;$script:Calls.Clear();$script:DefaultRuleExists=$true
$state.DefaultRuleExisted=$true;$state.DefaultRuleEnabled=$true;$state.CapabilityState='Installed';$state.ServiceState='Running';$state.StartMode='Auto';$state.Account.ProfilePath='/mock/user'
$script:Capability='Installed';$script:ServiceState='Running';$script:ServiceMode='Auto';$script:Rule=$expectedRule
Invoke-LocalSftpSetup $null @($t) $caller $true @('192.0.2.0/24')
Assert (($script:Calls -join ',') -eq 'folders') 'existing server service and firewall retained; folder checks rerun'
$script:Calls.Clear();$expectedRule.RemoteAddress=@('Any');$script:Rule=$expectedRule
Throws {Invoke-LocalSftpSetup $null @($t) $caller $true @('192.0.2.0/24')} 'conflicting same-name firewall rule not overwritten'
Assert ($script:Calls.Count -eq 0) 'firewall conflict blocks all provisioning'
Write-Host "`nFINAL: $script:Passed local-setup checks passed. Native Windows servicing, ACLs, firewall and SFTP login remain untested."
$grants=@(Get-SftpPermissionSpec 'S-1-5-21-1-2-3-1001' $true)
Assert ($grants.Count -eq 3 -and @($grants | Where-Object Rights -eq FullControl).Count -eq 2) 'new root grant plan limits FullControl to SYSTEM and Administrators'
Assert (@($grants | Where-Object { $_.Sid -eq 'S-1-5-21-1-2-3-1001' -and $_.Rights -eq 'Modify' }).Count -eq 1) 'backup user receives Modify rather than FullControl'
Assert ((@(Get-SftpPermissionSpec 'S-1-5-21-1-2-3-1001' $false)).Count -eq 1) 'existing folder plan adds only selected user grant'
Throws {Get-SftpPermissionSpec 'S-1-1-0' $true} 'Everyone cannot become the backup account grant'
Write-Host "`nFINAL: $script:Passed local-setup checks passed. Native Windows servicing, ACLs, firewall and SFTP login remain untested."
$expectedRule.RemoteAddress=@('192.0.2.0/24');$script:Rule=$expectedRule;$script:Calls.Clear()
$script:MemberPresent=$false
function Get-LocalGroup {param($Name,$ErrorAction)[pscustomobject]@{SID=[pscustomobject]@{Value='S-1-5-21-1-2-3-2001'}}}
function Get-LocalGroupMember {param($SID,$ErrorAction)if($script:MemberPresent){[pscustomobject]@{SID=[pscustomobject]@{Value='S-1-5-21-1-2-3-1001'}}}}
function Add-LocalGroupMember {param($SID,$Member,$ErrorAction)$script:Calls.Add('ssh-group');$script:MemberPresent=$true}
Invoke-LocalSftpSetup $null @($t) $caller $true @('192.0.2.0/24')
Assert ('ssh-group' -in $script:Calls -and $script:MemberPresent) 'Windows-provided OpenSSH Users group gains selected account only'
$script:Calls.Clear()
Invoke-LocalSftpSetup $null @($t) $caller $true @('192.0.2.0/24')
Assert ('ssh-group' -notin $script:Calls) 'existing OpenSSH Users membership is not added repeatedly'
Write-Host "`nFINAL: $script:Passed local-setup checks passed. Native Windows servicing, ACLs, firewall and SFTP login remain untested."
