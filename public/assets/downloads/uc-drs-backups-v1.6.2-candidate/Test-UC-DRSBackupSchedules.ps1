# Offline deterministic tests. No Posh-SSH module, Windows vault or remote access.
param([string]$ScriptPath=(Join-Path $PSScriptRoot 'Set-UC-DRSBackupSchedules-v1.6.2.ps1'))
$ErrorActionPreference='Stop'
$tokens=$null; $errors=$null
$null=[Management.Automation.Language.Parser]::ParseFile($ScriptPath,[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw ($errors | Out-String) }
. $ScriptPath
$script:Passed=0
function Assert($Condition,[string]$Message) { if (-not $Condition) { throw "FAILED: $Message" }; $script:Passed++; Write-Host "PASS $Message" }
function Throws([scriptblock]$Body,[string]$Message) { $caught=$false; try { & $Body } catch { $caught=$true }; Assert $caught $Message }
function New-TestTarget([string]$Technology='CUCM') {
    ConvertTo-UcTarget ([pscustomobject]@{Site='Lab';Id='Cluster1';Technology=$Technology;Address='192.0.2.10';Username='admin';ExpectedNodes='';ImpTopology='None'})
}
function New-TestSettings {
    ConvertTo-BackupSettings ([pscustomobject]@{SftpAddress='192.0.2.50';SftpUsername='backup';Retention=2;WeeklyName='Weekly';MonthlyName='Monthly';WeeklyPath='Lab/Weekly/';MonthlyPath='Lab/Monthly/';WeeklyDay='Tuesday';WeeklyTime='01:00';MonthlyDay=1;MonthlyTime='02:00'})
}
$target=New-TestTarget; $target.Settings=New-TestSettings
# Revision5 interactive paths use queued inputs, never native credentials/network.
& {
    $script:Answers=New-Object System.Collections.Generic.Queue[string]
    function Set-Answers([string[]]$Values) { $script:Answers.Clear();foreach($v in $Values){$script:Answers.Enqueue($v)} }
    function Read-Host { param($Prompt) if(-not $script:Answers.Count){throw "Unexpected prompt: $Prompt"};return $script:Answers.Dequeue() }
    function Send-UcCommand { throw 'UI selection must not contact an appliance' }
    $snap=[pscustomobject]@{Devices=@([pscustomobject]@{Name='Case_A';Type='NETWORK'},[pscustomobject]@{Name='Case_b';Type='NETWORK'});Schedules=@([pscustomobject]@{Name='Case_A';Device='Case_A';Status='enabled'},[pscustomobject]@{Name='Case_b';Device='Case_b';Status='enabled'})}
    $original=$snap | ConvertTo-Json -Depth 6 -Compress
    Set-Answers @('0,1','1,1','-1','99999999999999999','1;delete','1,3','2,1')
    $n=Read-NumberSelection 'pick' 2 -Multiple
    Assert (($n -join ',') -eq '1,0' -and $script:Answers.Count -eq 0) 'number selection rejects invalid duplicate overflow and injected input; preserves chosen order'
    Set-Answers @('1,2','0');$n=Read-NumberSelection 'pick one' 2
    Assert ($n.Count -eq 0 -and $script:Answers.Count -eq 0) 'single selection rejects multiple indexes and supports Back'
    $empty=[pscustomobject]@{Devices=@();Schedules=@()}
    Assert ((Read-DrsMaintenancePlan $empty).Count -eq 0) 'empty inventory skips every maintenance prompt'
    Assert (@(Get-DrsMaintenanceOptions $snap DeleteDevice).Count -eq 0) 'referenced devices are not offered for deletion'
    $disabled=Get-DrsProjectedSnapshot $snap @([pscustomobject]@{Kind='DisableSchedule';Name='Case_A'})
    Assert ((@(Get-DrsMaintenanceOptions $disabled DisableSchedule).Name -join ',') -ceq 'Case_b') 'disabled schedule omitted from disable choices'
    Set-Answers @('Add','1','1,2','Done')
    $selected=Read-DrsMaintenancePlan $snap
    Assert ($selected.Count -eq 2 -and ($selected.Name -join ',') -ceq 'Case_A,Case_b') 'multi-select preserves exact case and object order'
    Assert (($snap | ConvertTo-Json -Depth 6 -Compress) -ceq $original) 'preview selection leaves original observations unchanged'
    # Removing a prerequisite or editing it into a conflicting action is rejected.
    Set-Answers @('Add','2','1','Add','3','1','Remove','1','Edit','1','1','1','Done')
    $selected=Read-DrsMaintenancePlan $snap
    Assert ($selected.Count -eq 2 -and $selected[0].Kind -eq 'DeleteSchedule' -and $selected[1].Kind -eq 'DeleteDevice') 'invalid removal/edit keeps the complete dependent plan unchanged'
    Set-Answers @('Add','1','1,2','Edit','2','2','2','Remove','1','Done')
    $selected=Read-DrsMaintenancePlan $snap
    Assert ($selected.Count -eq 1 -and $selected[0].Kind -eq 'DeleteSchedule' -and $selected[0].Name -ceq 'Case_b') 'valid edit and removal rebuild the remaining ordered plan'
    Set-Answers @('Add','2','1','Add','3','1','Remove','1,2','Done')
    Assert ((Read-DrsMaintenancePlan $snap).Count -eq 0) 'dependent actions can be removed together without implicit deletion of other selections'
    Set-Answers @('Cancel');$cancelled=$false
    try { Read-DrsMaintenancePlan $snap } catch [OperationCanceledException] { $cancelled=$true }
    Assert $cancelled 'preview Cancel has a distinct cancellation exception'
    Set-Answers @('Cancel');$cancelled=$false
    try { Read-UcTargetSelection @($target) } catch [OperationCanceledException] { $cancelled=$true }
    Assert $cancelled 'target selection Cancel uses the same cancellation contract'
    $ctxUi=[pscustomobject]@{PendingWrites=@();WriteAttempts=@();AllowLocalWrite=$true;CredentialMode='Ask'}
    Assert ((Get-UcFailureGuidance $ctxUi '192.0.2.1') -like 'No configuration writes*') 'failure guidance identifies a no-write attempt'
    $ctxUi.WriteAttempts=@([pscustomobject]@{Address='192.0.2.1'})
    Assert ((Get-UcFailureGuidance $ctxUi '192.0.2.1') -like 'Earlier writes*') 'failure guidance retains verified earlier work'
    $ctxUi.PendingWrites=@([pscustomobject]@{Address='192.0.2.1'})
    Assert ((Get-UcFailureGuidance $ctxUi '192.0.2.1') -like 'A write has no verification*') 'unresolved write guidance takes priority over earlier successes'
    Assert ((Get-UcFailureGuidance $ctxUi '192.0.2.2') -like 'No configuration writes*') 'failure guidance is specific to the failed target'
    $entryUi=[pscustomobject]@{Stored=$false};$script:SaveOffers=0
    function Save-ValidatedCredential { $script:SaveOffers++ }
    Set-Answers @('');Offer-SftpCredentialSave $ctxUi $entryUi
    Assert ($script:SaveOffers -eq 0) 'SFTP backup validation defaults to Skip without saving'
    Set-Answers @('Verified');Offer-SftpCredentialSave $ctxUi $entryUi
    Assert ($script:SaveOffers -eq 1) 'verified manual backup reaches the separate credential-save consent function'
    $entryUi.Stored=$true;Offer-SftpCredentialSave $ctxUi $entryUi
    $entryUi.Stored=$false;$ctxUi.AllowLocalWrite=$false;Offer-SftpCredentialSave $ctxUi $entryUi
    Assert ($script:SaveOffers -eq 1) 'stored or read-only credentials do not prompt for saving'
    $script:Messages=New-Object System.Collections.Generic.List[string]
    function Write-Host { param($Object,$ForegroundColor) $script:Messages.Add("$Object") }
    Show-DrsVerification 'Case_A' $snap
    $text=$script:Messages -join "`n"
    Assert ($text -match 'Verified by CLI readback: device name/type, schedule-to-device association, enabled status' -and $text -match 'Check in DRS.*device server, device path') 'verification display separates known fields from fields absent in CLI output'
    $snap.Devices[0] | Add-Member NoteProperty Server '192.0.2.50';$snap.Devices[0] | Add-Member NoteProperty Path 'Backups/Weekly'
    $script:Messages.Clear();Show-DrsVerification 'Case_A' $snap
    Assert ($script:Messages[1] -match 'device server, device path' -and $script:Messages[2] -notmatch 'device server|device path') 'displayed named server/path fields appear only in verified list'
}
Assert ($target.Port -eq 22) 'target normalization supplies SSH port'
Throws { ConvertTo-IPv4 '127.1' } 'reject shorthand IP'
Throws { ConvertTo-IPv4 "192.0.2.1`ncommand" } 'reject IP command injection'
Throws { Assert-Token 'x;delete' 'name' } 'reject unsafe CLI token'
Throws { ConvertTo-UcTarget ([pscustomobject]@{Site='x';Id='x';Technology='CER';Address='192.0.2.1';Username='admin';Password='bad'}) } 'reject credential field in inventory'
Throws { Test-TargetSet @($target,$target) } 'reject duplicate targets'
Assert ((Get-CredentialKey Lab ssh '192.0.2.10' 22 admin) -eq 'UC-DRS/Lab/ssh/192.0.2.10:22/admin') 'credential key includes site purpose endpoint and user'
Assert ((Get-CredentialKey Lab ssh '192.0.2.10' 22 admin) -ne (Get-CredentialKey Lab sftp '192.0.2.10' 22 admin)) 'SSH and SFTP namespaces differ'
Initialize-CredentialStore
Assert ($null -ne ('UcDrs.NativeVault' -as [type])) 'native wrapper compiles without calling Windows APIs'

$topology="192.0.2.10 cucm.lab cucm Publisher callmanager DBPub authenticated`n192.0.2.11 imp1.lab imp1 Subscriber cups DBPub authenticated`n192.0.2.12 imp2.lab imp2 Subscriber cups DBSub authenticated`nadmin:"
$nodes=@(ConvertFrom-UcTopology $topology '192.0.2.10')
Assert ($nodes.Count -eq 3 -and $nodes[1].DatabaseRole -eq 'Publisher') 'topology retains IM&P database role'
Throws { ConvertFrom-UcTopology $topology '192.0.2.11' } 'subscriber cannot become configuration endpoint'
Throws { ConvertFrom-UcTopology ($topology.Replace('DBSub authenticated','DBSub unauthenticated')) '192.0.2.10' } 'unauthenticated member blocks topology'
Throws { ConvertFrom-UcTopology ($topology+"`nunknown data") '192.0.2.10' } 'unknown topology row blocks partial success'
# Sanitized CUCM 14.0.1.16900-4 shape reported by an operator: authenticated
# nodes followed by a processnode footer mixing case-varied names and IPs.
$reportedNodes=@'
192.0.2.16 impub.example.test impub Subscriber cups DBPub authenticated using TCP since Fri Jul 17 14:11:57 2026
192.0.2.11 CMSUB.example.test CMSUB Subscriber callmanager DBSub authenticated using TCP since Fri Jul 17 14:05:57 2026
192.0.2.17 IMSUB.example.test IMSUB Subscriber cups DBSub authenticated using TCP since Fri Jul 17 14:05:48 2026
192.0.2.10 cmpub.example.test cmpub Publisher callmanager DBPub authenticated
'@
$footer="Server Table (processnode) Entries`n----------------------------------`nCMPUB`n192.0.2.16`nCMSUB`n192.0.2.17"
$reported="admin:show network cluster`n$reportedNodes`n`n$footer`nadmin:"
$reportedParsed=@(ConvertFrom-UcTopology $reported '192.0.2.10')
Assert ($reportedParsed.Count -eq 4) 'CUCM 14 mixed processnode footer retains four authenticated nodes'
Assert (($reportedParsed.Hostname -join ';') -ceq 'impub;CMSUB;IMSUB;cmpub') 'footer case does not rewrite canonical node names'
Assert ($reportedParsed[0].Role -eq 'Subscriber' -and $reportedParsed[0].DatabaseRole -eq 'Publisher') 'IM&P DBPub remains distinct from cluster Subscriber'
Assert (@(ConvertFrom-UcTopology ($reported -replace "`n","`r`n") '192.0.2.10').Count -eq 4) 'reported footer accepts CRLF terminal output'
Assert (@(ConvertFrom-UcTopology $reportedNodes '192.0.2.10').Count -eq 4) 'four-node response without footer remains supported'
Assert (@(ConvertFrom-UcTopology ($reported.Replace("`nCMPUB`n","`nCMPUB.EXAMPLE.TEST`n")) '192.0.2.10').Count -eq 4) 'footer FQDN identity reconciles case-insensitively'
Throws { ConvertFrom-UcTopology ($reportedNodes+"`nunknown row`n"+$footer) '192.0.2.10' } 'unknown row before footer still blocks'
Throws { ConvertFrom-UcTopology ($reported.Replace("`nCMPUB`n","`nunknown.example.test`n")) '192.0.2.10' } 'unknown footer identity blocks'
Throws { ConvertFrom-UcTopology ($reportedNodes+"`nServer Table (processnode) Entries") '192.0.2.10' } 'empty footer cannot establish complete topology'
Throws { ConvertFrom-UcTopology ($reported.Replace("`n192.0.2.17`nadmin:","`nadmin:")) '192.0.2.10' } 'missing footer member blocks'
Throws { ConvertFrom-UcTopology ($reported+"`nextra") '192.0.2.10' } 'extra footer member blocks'
Throws { ConvertFrom-UcTopology ($reported.Replace("`nCMSUB`n","`n192.0.2.10`n")) '192.0.2.10' } 'duplicate footer identity via name and address blocks'
Throws { ConvertFrom-UcTopology ($reported+"`n"+$reportedNodes.Split("`n")[0]) '192.0.2.10' } 'authenticated-shaped row after footer is not silently skipped'
Throws { ConvertFrom-UcTopology ($reported+"`nServer Table (processnode) Entries") '192.0.2.10' } 'repeated footer header blocks'
Throws { ConvertFrom-UcTopology ($footer+"`n"+$reportedNodes) '192.0.2.10' } 'footer before authenticated nodes blocks'
Throws { ConvertFrom-UcTopology ($reported.Replace('DBSub authenticated','DBSub unauthenticated')) '192.0.2.10' } 'footer never excuses unauthenticated member'
Throws { ConvertFrom-UcTopology ($reported.Replace('impub.example.test','cmpub')) '192.0.2.10' } 'ambiguous footer identity blocks'

# Exercise the actual entry-point parameter declaration without executing main.
$bindingAst=[Management.Automation.Language.Parser]::ParseFile($ScriptPath,[ref]$tokens,[ref]$errors)
$bindingAttributes=($bindingAst.ParamBlock.Attributes | ForEach-Object { $_.Extent.Text }) -join "`n"
$bindingProbe=[scriptblock]::Create($bindingAttributes+"`n"+$bindingAst.ParamBlock.Extent.Text+"`n[pscustomobject]@{Profile=`$Profile;Sources=`$SftpRemoteAddress;Setup=[bool]`$SetupLocalSftp}")
$bound=& $bindingProbe -Profile 'site.json'
Assert ($bound.Profile -eq 'site.json' -and -not $bound.Sources) 'single-hyphen named profile binds without remote firewall sources'
Throws { & $bindingProbe --Profile 'site.json' } 'double-hyphen Profile rejected at binding before main'
Throws { & $bindingProbe 'site.json' } 'unnamed positional input rejected before main'
$bound=& $bindingProbe -Profile 'site.json' -SetupLocalSftp -SftpRemoteAddress '192.0.2.0/24'
Assert ($bound.Setup -and $bound.Sources[0] -eq '192.0.2.0/24') 'named local SFTP setup arguments remain supported'

# Sanitized CUC 14.0.1.16900-10 output supplied by the operator.
$cucText="admin:show network cluster`n192.0.2.13 UCSUB.example.test UCSUB Subscriber connection DBSub authenticated using TCP since Fri Jul 17 14:08:12 2026`n192.0.2.12 ucpub.example.test ucpub Publisher connection DBPub authenticated`n`nServer Table (processnode) Entries`n----------------------------------`nUCPUB`nUCSUB"
$cucNodes=@(ConvertFrom-UcTopology $cucText '192.0.2.12')
Assert ($cucNodes.Count -eq 2 -and ($cucNodes.Hostname -join ';') -ceq 'UCSUB;ucpub') 'reported CUC pair uses shared footer parser and preserves case'
Assert ($cucNodes[1].Role -eq 'Publisher' -and $cucNodes[1].DatabaseRole -eq 'Publisher') 'reported CUC publisher role retained'
$cucTarget=ConvertTo-UcTarget ([pscustomobject]@{Site='Lab';Id='Messaging';Technology='CUC';Address='192.0.2.12';Username='admin';ExpectedNodes='ucpub;UCSUB';ImpTopology='None'})
# Registration evidence remains synthetic; no live show_registration output yet.
$cucRegs=@(foreach($n in $cucNodes){[pscustomobject]@{Node=$n.Hostname;Feature='CUC';Component='PLATFORM'}})
Assert ((Test-DrsCoverage $cucTarget $cucNodes $cucRegs).Status -eq 'registered_features_checked') 'reported CUC topology feeds synthetic CUC registration coverage'

$single=@(ConvertFrom-UcTopology "192.0.2.10 cucm.lab cucm Publisher authenticated`nadmin:" '192.0.2.10')
$reg=@(ConvertFrom-DrsRegistration "Feature  Component`nUCM PLATFORM`nUCM CCMDB`nadmin:" cucm)
Assert ($reg.Count -eq 2) 'registration table retains components'
$labels=@(ConvertFrom-DrsRegistration "Feature : UCM`nComponent : PLATFORM`nFeature : UCM`nComponent : CCMDB`nadmin:" cucm)
Assert ($labels.Count -eq 2) 'registration label format retains components'
Throws { ConvertFrom-DrsRegistration "UCM PLATFORM`nFeature : UCM" cucm } 'truncated registration blocks'
Throws { ConvertFrom-DrsRegistration "UCM PLATFORM`nunexpected row extra" cucm } 'partly parsed registration blocks'
Assert ((Test-DrsCoverage $target $single $reg).Status -eq 'registered_features_checked') 'CUCM-only coverage'
$impPub=@('PLATFORM','CLM','DB','PREFS','XCP','SYSLOGAGT','CDPAGT','TCT','BAT','CUP','REPORTER')
$impSub=@('PLATFORM','CLM','XCP','SYSLOGAGT','CDPAGT','TCT','CUP','REPORTER')
$all=@($reg)+@(foreach($c in $impPub){[pscustomobject]@{Node='imp1';Feature='IM_AND_PRESENCE';Component=$c}})+@(foreach($c in $impSub){[pscustomobject]@{Node='imp2';Feature='IM_AND_PRESENCE';Component=$c}})
$target.ImpTopology='Pair';$target.ImpPublisher='imp1';$target.ImpSubscriber='imp2'
$coverage=Test-DrsCoverage $target $nodes $all
Assert ($coverage.Status -eq 'registered_features_checked' -and 'IM_AND_PRESENCE' -in $coverage.Features) 'IM&P pair included in schedule features'
Assert ((Test-DrsCoverage $target $nodes @($all | Where-Object { -not ($_.Node -eq 'imp1' -and $_.Component -eq 'DB') })).Status -eq 'blocked') 'missing publisher DB component blocks'
Assert ((Test-DrsCoverage $target @($nodes[0],$nodes[1]) @($all | Where-Object Node -ne imp2)).Status -eq 'blocked') 'missing IM&P subscriber blocks'
$target.ImpTopology='PublisherOnly';$target.ImpSubscriber=''
Assert ((Test-DrsCoverage $target @($nodes[0],$nodes[1]) @($all | Where-Object Node -ne imp2)).Status -eq 'registered_features_checked') 'IM&P publisher-only coverage'
$target.ImpTopology='None';$target.ImpPublisher=''
Assert ((Test-DrsCoverage $target $nodes $all).Status -eq 'blocked') 'unexpected IM&P blocks None profile'
foreach ($tech in @('CUC','CER','UCCX')) {
    $t=New-TestTarget $tech; $feature=if($tech -eq 'CUC'){'CUC'}else{$tech}
    $r=@([pscustomobject]@{Node='cucm';Feature=$feature;Component='PLATFORM'})
    Assert ((Test-DrsCoverage $t $single $r).Status -eq 'registered_features_checked') "$tech single-node feature mapping"
    Assert ((Test-DrsCoverage $t $single $reg).Status -eq 'blocked') "$tech rejects mismatched technology registrations"
}
Assert ((Get-UcRelease 'Active Master Version: 14.0.1.16900-4' CUCM) -eq '14.0.1.16900-4') 'parse release'
Assert ((Get-UcRelease 'Active Master Version: 12.5.1.10000-1' UCCX) -like '12.5*') 'UCCX release uses separate policy'
Throws { Get-UcRelease 'Active Master Version: 14.0.1.10000-1' UCCX } 'reject nonexistent UCCX 14 adapter'

# v1.6.1 regressions exercise the integrated release and coverage callers.
Throws { Get-UcRelease 'Active Master Version: 12.50.1.10000-1' UCCX } 'UCCX 12.50 cannot pass the 12.5 minor-version gate'
Throws { Get-UcRelease 'Active Master Version: 12.51.1.10000-1' UCCX } 'UCCX 12.51 cannot pass the 12.5 minor-version gate'
Assert ((Get-UcRelease 'Active Version: 15.0.1.10000-1' UCCX) -eq '15.0.1.10000-1') 'UCCX 15 accepted with Active Version form'
Assert ((Get-UcRelease 'Active Master Version: 14.0.1.16900(4)' CUCM) -eq '14.0.1.16900(4)') 'parenthesized CUCM release preserved'
Throws { Get-UcRelease 'Active Version: 14.0.1' Unknown } 'unknown technology cannot bypass release policy'
$policyTarget=New-TestTarget CUCM; $policyTarget.ImpTopology='Discover'
$impOnly=[pscustomobject]@{Hostname='imp1';DatabaseRole='Publisher'}
$impOnlyRows=@('PLATFORM','CLM','XCP','SYSLOGAGT','CDPAGT','TCT','CUP','REPORTER','DB','PREFS','BAT' | ForEach-Object {
    [pscustomobject]@{Node='imp1';Feature='IM_AND_PRESENCE';Component=$_}
})
$coverage=Test-DrsCoverage $policyTarget @($impOnly) $impOnlyRows
Assert ($coverage.Status -eq 'blocked' -and ($coverage.Issues -join ' ') -like '*expected UCM*') 'IM&P-only declared CUCM is blocked despite complete IM&P components'
$ccmRow=[pscustomobject]@{Node='cucm';Feature='UCM';Component='synthetic'}
Assert ((Test-DrsCoverage $policyTarget @($impOnly) ($impOnlyRows+$ccmRow)).Status -eq 'blocked') 'UCM on an undiscovered node cannot satisfy CUCM coverage'
$cmNode=[pscustomobject]@{Hostname='cucm';DatabaseRole='Publisher';Role='Publisher';Address='192.0.2.10'}
Assert ((Test-DrsCoverage $policyTarget @($cmNode,$impOnly) ($impOnlyRows+$ccmRow)).Status -eq 'registered_features_checked') 'CUCM with IM&P remains accepted'
Assert ((Test-DrsCoverage $policyTarget @($cmNode) @($ccmRow)).Status -eq 'registered_features_checked') 'CUCM-only remains accepted'
$wrongCase=[pscustomobject]@{Node='CUCM';Feature='UCM';Component='synthetic'}
Assert ((Test-DrsCoverage $policyTarget @($cmNode) @($wrongCase)).Status -eq 'blocked') 'primary feature retains exact node-name matching'
foreach($product in @('CUC','CER','UCCX')) {
    $productTarget=New-TestTarget $product
    $feature=(Get-UcTechnologyPolicy $product).RequiredFeature
    $productRow=[pscustomobject]@{Node='cucm';Feature=$feature;Component='synthetic'}
    Assert ((Test-DrsCoverage $productTarget @($cmNode) @($productRow)).Status -eq 'registered_features_checked') "$product expected primary feature accepted"
    Assert ((Test-DrsCoverage $productTarget @($cmNode) @($ccmRow)).Status -eq 'blocked') "$product wrong primary feature blocked"
}
Assert ((Test-DrsCoverage $policyTarget @() @()).Status -eq 'blocked') 'empty discovered inventory cannot pass coverage'


# Sanitized operator registrations exercise actual feature tokens and IM&P checks.
$fixtures=Get-Content (Join-Path $PSScriptRoot 'registration-fixtures.json') -Raw | ConvertFrom-Json
$fixtureNodes=@(
    [pscustomobject]@{Hostname='voice-pub';Address='192.0.2.10';Role='Publisher';DatabaseRole='Publisher'},
    [pscustomobject]@{Hostname='VOICE-SUB';Address='192.0.2.11';Role='Subscriber';DatabaseRole='Subscriber'},
    [pscustomobject]@{Hostname='presence-pub';Address='192.0.2.16';Role='Subscriber';DatabaseRole='Publisher'},
    [pscustomobject]@{Hostname='PRESENCE-SUB';Address='192.0.2.17';Role='Subscriber';DatabaseRole='Subscriber'}
)
$fixtureRegs=@(foreach($n in $fixtureNodes){ConvertFrom-DrsRegistration $fixtures.($n.Hostname) $n.Hostname})
$fixtureTarget=New-TestTarget CUCM; $fixtureTarget.ImpTopology='Pair';$fixtureTarget.ImpPublisher='presence-pub';$fixtureTarget.ImpSubscriber='PRESENCE-SUB'
$fixtureCoverage=Test-DrsCoverage $fixtureTarget $fixtureNodes $fixtureRegs
Assert ($fixtureCoverage.Status -eq 'registered_features_checked' -and $fixtureRegs.Count -eq 46) 'operator CUCM and IM&P registrations pass with UCM feature'
Assert (($fixtureCoverage.Features -join ',') -eq 'CDR_CAR,IM_AND_PRESENCE,UCM') 'discovered CLI feature tokens preserved unchanged for scheduling'
$missingUcm=@($fixtureRegs | Where-Object { -not ($_.Node -eq 'VOICE-SUB' -and $_.Feature -eq 'UCM') })
Assert ((Test-DrsCoverage $fixtureTarget $fixtureNodes $missingUcm).Status -eq 'blocked') 'missing UCM subscriber registration still blocks'
Assert ((Test-DrsCoverage $fixtureTarget $fixtureNodes @($fixtureRegs | Where-Object { -not ($_.Node -eq 'presence-pub' -and $_.Component -eq 'DB') })).Status -eq 'blocked') 'operator fixture missing IM&P publisher DB still blocks'
Throws { ConvertFrom-DrsRegistration $fixtures.'MESSAGING-SUB' 'MESSAGING-SUB' } 'explicit no-registration response cannot count as coverage'
try { ConvertFrom-DrsRegistration $fixtures.'MESSAGING-SUB' 'MESSAGING-SUB' } catch { $noRegMessage=$_.Exception.Message }
Assert ($noRegMessage -like 'No registered DRS features/components*') 'no-registration output reports appliance condition instead of parser fallback'
Throws { ConvertFrom-DrsRegistration "UCM PLATFORM`nExecuted command unsuccessfully" voice } 'failed registration command with data still rejected'
$pubRegs=@([pscustomobject]@{Node='ucpub';Feature='CUC';Component='PLATFORM'})
$cucCoverage=Test-DrsCoverage $cucTarget $cucNodes $pubRegs
Assert ($cucCoverage.Status -eq 'registered_features_checked' -and $cucCoverage.Nodes.Count -eq 2 -and $cucCoverage.RegistrationNodes.Count -eq 1) 'CUC checks publisher registration and preserves both inventory nodes'
Assert ((Test-DrsCoverage $cucTarget $cucNodes @()).Status -eq 'blocked') 'CUC publisher without registrations remains blocked'
Assert ((Test-DrsCoverage $cucTarget $cucNodes @([pscustomobject]@{Node='UCSUB';Feature='CUC';Component='PLATFORM'})).Status -eq 'blocked') 'CUC subscriber registration cannot substitute for publisher'
$cucTarget.ExpectedNodes='ucpub'
Assert ((Test-DrsCoverage $cucTarget $cucNodes $pubRegs).Status -eq 'blocked') 'CUC subscriber inventory expectation still enforced'
$cucTarget.ExpectedNodes='ucpub;UCSUB'
Throws { Get-DrsRegistrationNodes $cucTarget @($cucNodes[0]) } 'CUC without selected publisher cannot define DRS scope'
$cucOutput=Show-Coverage $cucCoverage 6>&1 | Out-String
Assert ($cucOutput -like '*UCSUB*inventory only*publisher-only*') 'CUC subscriber is visibly inventory-only'
$actualCucRegs=@(ConvertFrom-DrsRegistration $fixtures.'messaging-pub' 'ucpub')
$actualCucCoverage=Test-DrsCoverage $cucTarget $cucNodes $actualCucRegs
Assert ($actualCucCoverage.Status -eq 'registered_features_checked' -and $actualCucRegs.Count -eq 9) 'operator CUC publisher response passes with nine component registrations'
Assert (($actualCucCoverage.Features -join ',') -eq 'CONNECTION_DATABASE,CONNECTION_GREETINGS_VOICENAMES,CONNECTION_HTML_NOTIFICATION,CONNECTION_MESSAGES_UNITYMBXDB1,CUC') 'all five reported CUC backup features retained'
$cucTarget.Settings=New-TestSettings
$actualCucDiscovery=[pscustomobject]@{Release='14.0.1.16900-10';Coverage=$actualCucCoverage;Snapshot=[pscustomobject]@{Devices=@();Schedules=@()}}
$actualCucPlan=New-DrsPlan $cucTarget $actualCucDiscovery ([datetime]'2026-11-17T23:00')
Assert (($actualCucPlan.Features -join ',') -eq ($actualCucCoverage.Features -join ',') -and $actualCucPlan.Actions.Count -eq 2) 'CUC schedule plan retains complete discovered publisher feature list'
# Exercise discovery command selection, not only the coverage helper.
& {
    $script:DiscoveryCommands=New-Object System.Collections.Generic.List[string]
    function Send-UcCommand {
        param($Context,$Connection,$Command)
        $script:DiscoveryCommands.Add($Command)
        $text=switch -Exact ($Command) {
            'show version active' { 'Active Master Version: 14.0.1.16900-10' }
            'show network cluster' { $cucText }
            'utils disaster_recovery show_registration ucpub' { $fixtures.'messaging-pub'.Replace('messaging-pub','ucpub') }
            default { throw "Unexpected discovery command: $Command" }
        }
        [pscustomobject]@{Text=$text}
    }
    function Write-Audit { param($Context,$Event,$Data) }
    function Get-DrsSnapshot { param($Context,$Connection) [pscustomobject]@{Devices=@();Schedules=@()} }
    $d=Get-DrsDiscovery $null $null $cucTarget
    Assert ($d.Coverage.Status -eq 'registered_features_checked' -and $script:DiscoveryCommands.Count -eq 3) 'CUC discovery queries publisher only and completes coverage'
    Assert ('utils disaster_recovery show_registration UCSUB' -notin $script:DiscoveryCommands) 'CUC discovery never queries subscriber registrations'
}

$devices=@(ConvertFrom-DrsList "device name  device type`nExisting  NETWORK`nadmin:" device)
$schedules=@(ConvertFrom-DrsList "schedule name  device name  Schedule Status`nExisting  Existing  disabled`nadmin:" schedule)
Assert ($devices.Count -eq 1 -and $schedules[0].Status -eq 'disabled') 'list parser preserves schedule enabled state'
Throws { ConvertFrom-DrsList 'garbled response' device } 'unknown list is not empty configuration'
Throws { ConvertFrom-DrsList "device name  device type`nExisting  NETWORK`nextra garbage" device } 'partial device list blocks'
Assert (@(ConvertFrom-DrsList 'No devices configured' device).Count -eq 0) 'explicit empty list accepted'
$empty=[pscustomobject]@{Devices=@();Schedules=@()}
$target=New-TestTarget; $target.Settings=New-TestSettings
$discovery=[pscustomobject]@{Release='14.0.1';Coverage=(Test-DrsCoverage $target $single $reg);Snapshot=$empty}
$plan=New-DrsPlan $target $discovery ([datetime]'2026-11-14T13:00')
Assert ($plan.Actions.Count -eq 2 -and @($plan.Actions | Where-Object Kind -ne CreatePair).Count -eq 0) 'new configuration plan has two create pairs'
Assert ($plan.Actions[0].Start -ge ([datetime]'2026-11-16T13:00')) 'weekly start respects minimum elapsed two days'
Assert ($plan.Actions[1].Start -eq ([datetime]'2026-12-01T02:00')) 'monthly scheduling is next calendar day not weekday'
$target.Settings.MonthlyDay=0
Assert ((New-DrsPlan $target $discovery ([datetime]'2026-11-14')).Actions.Count -eq 1) 'declining monthly creates no monthly device'
$target.Settings.MonthlyDay=1
$discovery.Snapshot=[pscustomobject]@{Devices=@([pscustomobject]@{Name='Weekly';Type='NETWORK'});Schedules=@([pscustomobject]@{Name='Weekly';Device='Weekly';Status='disabled'})}
$existingPlan=New-DrsPlan $target $discovery ([datetime]'2026-11-14')
Assert ($existingPlan.Actions[0].Kind -eq 'ReviewExisting' -and $existingPlan.Actions[0].State -eq 'unverified') 'disabled existing schedule is not already_ok'
Throws { Test-DestinationCollisions @($target,$target) } 'shared destinations rejected'
$after=[pscustomobject]@{Devices=@([pscustomobject]@{Name='Weekly';Type='NETWORK'});Schedules=@([pscustomobject]@{Name='Weekly';Device='Weekly';Status='enabled'})}
Assert-SnapshotPreserved $empty $after Weekly
Assert $true 'expected new pair preserves empty baseline'
Throws { Assert-SnapshotPreserved $discovery.Snapshot $empty Monthly } 'lost existing configuration detected'

Assert ((Get-UcPrompt "old admin:`nwork ongoing" None) -eq 'None') 'stale admin prompt cannot finish output'
Assert ((Get-UcPrompt "Status:`n" None) -eq 'None') 'colon status is not CLI prompt'
Assert ((Get-UcPrompt "Password:" None) -eq 'None') 'unexpected password prompt not treated as CLI'
Assert ((Get-UcPrompt "Enter password:" Password) -eq 'Password') 'expected password prompt recognized'
Assert ((Get-UcPrompt "Please enter week days:" Weekday) -eq 'Weekday') 'weekly prompt recognized'
Assert ((Get-UcPrompt "done`nadmin:`n" None) -eq 'CLI') 'final admin prompt accepts trailing newline'
Throws { Assert-CliSuccess 'Unrecognized output' } 'unverified command cannot continue anyway'
Throws { Assert-CliSuccess 'failed but previously saved successfully' } 'failure overrides success token'

# Credential lifecycle: native calls mocked, actual username/key/choice/save logic runs.
& {
    $script:VaultEvents=New-Object System.Collections.Generic.List[string]
    $script:VaultChoice='Use';$script:VaultPresent=$true;$script:VaultFail=$false;$script:VaultConsent=$true;$script:VaultAuditFail=$false
    function Read-Value { param($Prompt,$Default) $script:VaultEvents.Add('username'); return 'osadmin' }
    function Read-NativeCredential { param($Key) $script:VaultEvents.Add("read:$Key"); if ($script:VaultPresent) { return [net.networkcredential]::new('osadmin',(ConvertTo-SecureString 'dummy' -AsPlainText -Force)) } }
    function Write-NativeCredential { param($Entry) $script:VaultEvents.Add("write:$($Entry.Key)");if ($script:VaultFail) { throw 'mock native failure' } }
    function Remove-NativeCredential { param($Key) $script:VaultEvents.Add("delete:$Key") }
    function Read-Choice { param($Prompt,$Choices,$Default) $script:LastVaultChoices=$Choices;return $script:VaultChoice }
    function Read-Host { param($Prompt,[switch]$AsSecureString) $script:VaultEvents.Add('password');return (ConvertTo-SecureString 'dummy' -AsPlainText -Force) }
    function Confirm-Choice { param($Prompt) $script:VaultEvents.Add('consent');return $script:VaultConsent }
    function Write-Audit { param($Context,$Event,$Data) $script:VaultEvents.Add("audit:$Event");if($script:VaultAuditFail){throw 'mock audit failure'} }
    $vc=[pscustomobject]@{CredentialMode='Ask';AllowLocalWrite=$true}
    $e=Request-UcCredential $vc Lab ssh '192.0.2.10' 22 admin
    Assert (($script:VaultEvents -join '|') -eq 'username|read:UC-DRS/Lab/ssh/192.0.2.10:22/osadmin') 'confirmed username precedes vault lookup and saved use avoids password prompt'
    Assert ($e.Stored -and $e.Credential.UserName -eq 'osadmin') 'profile username override reuses matching saved account'
    $e.Credential.Password.Dispose()
    $script:VaultPresent=$false;$script:VaultEvents.Clear()
    $e=Request-UcCredential $vc Lab ssh '192.0.2.10' 22 admin
    Assert (-not $e.Stored -and ($script:VaultEvents -join '|') -eq 'username|read:UC-DRS/Lab/ssh/192.0.2.10:22/osadmin|password') 'missing confirmed-account credential prompts for password after lookup'
    $e.Credential.Password.Dispose();$script:VaultPresent=$true
    $script:VaultEvents.Clear();$script:VaultChoice='New'
    $e=Request-UcCredential $vc Lab ssh '192.0.2.10' 22 admin
    Assert (-not $e.Stored -and $script:VaultEvents[-1] -eq 'password' -and @($script:VaultEvents | Where-Object {$_ -like 'delete:*'}).Count -eq 0) 'New prompts without deleting existing credential'
    $script:VaultEvents.Clear();$script:VaultChoice='Forget'
    $e=Request-UcCredential $vc Lab ssh '192.0.2.10' 22 admin
    Assert (($script:VaultEvents -join '|') -like '*delete:UC-DRS/Lab/ssh/192.0.2.10:22/osadmin|audit:credential_forgotten|password') 'Forget deletes only confirmed account then prompts'
    $script:VaultChoice='Use';$script:VaultEvents.Clear();$vc.AllowLocalWrite=$false
    $e=Request-UcCredential $vc Lab ssh '192.0.2.10' 22 admin
    Assert ('Forget' -notin $script:LastVaultChoices -and $e.Stored) 'read-only allows saved use but excludes Forget'
    $e.Credential.Password.Dispose();$script:VaultEvents.Clear();$vc.CredentialMode='Never'
    $e=Request-UcCredential $vc Lab ssh '192.0.2.10' 22 admin
    Assert (($script:VaultEvents -join '|') -eq 'username|password') 'Never does not access native vault'
    $e.Credential.Password.Dispose();$script:VaultEvents.Clear();$vc.CredentialMode='Ask';$vc.AllowLocalWrite=$true
    $e=Request-UcCredential $vc Lab ssh '192.0.2.10' 22 admin -Fresh
    Assert (($script:VaultEvents -join '|') -eq 'username|password') 'fresh authentication retry bypasses rejected stored credential'
    $script:VaultEvents.Clear()
    $saveOutput=Save-ValidatedCredential $vc $e 6>&1 | Out-String
    Assert ($e.Stored -and $saveOutput -like '*Credential saved to Windows Credential Manager*') 'native write success gets explicit console confirmation'
    Assert (($script:VaultEvents -join '|') -eq 'consent|write:UC-DRS/Lab/ssh/192.0.2.10:22/osadmin|audit:credential_saved') 'save requires consent and records success after native write'
    $script:VaultEvents.Clear();Save-ValidatedCredential $vc $e
    Assert ($script:VaultEvents.Count -eq 0) 'already stored credential not saved again'
    $e.Stored=$false;$script:VaultFail=$true
    $failureOutput=Save-ValidatedCredential $vc $e 3>&1 6>&1 | Out-String
    Assert (-not $e.Stored -and $failureOutput -like '*Could not save*' -and 'audit:credential_saved' -notin $script:VaultEvents) 'native failure does not claim or log successful persistence'
    $script:VaultFail=$false;$script:VaultConsent=$false;$script:VaultEvents.Clear()
    $declined=Save-ValidatedCredential $vc $e 6>&1 | Out-String
    Assert (($script:VaultEvents -join '|') -eq 'consent' -and $declined -like '*not saved (declined)*') 'declined persistence is explicit and never writes'
    $script:VaultConsent=$true;$vc.AllowLocalWrite=$false;$script:VaultEvents.Clear();Save-ValidatedCredential $vc $e
    Assert ($script:VaultEvents.Count -eq 0) 'read-only or WhatIf context cannot save'
    $vc.AllowLocalWrite=$true;$vc.CredentialMode='Never';Save-ValidatedCredential $vc $e
    Assert ($script:VaultEvents.Count -eq 0) 'Never context cannot offer saving'
    $vc.CredentialMode='Ask';$script:VaultAuditFail=$true
    Throws { Save-ValidatedCredential $vc $e } 'audit failure after native success propagates instead of reporting native failure'
    Assert $e.Stored 'successful native write remains recorded in memory when audit fails'
    $e.Credential.Password.Dispose()
}
# Relative outputs follow PowerShell location, not the process working directory.
$locationTest=Join-Path ([IO.Path]::GetTempPath()) ('uc-drs-location-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $locationTest
Push-Location $locationTest
try {
    $relativeContext=New-RunContext './relative.jsonl' Never $false
    Assert ($relativeContext.LogPath -eq (Join-Path $locationTest 'relative.jsonl')) 'relative LogPath follows PowerShell location'
    Throws { New-RunContext './relative.jsonl' Never $false } 'relative existing log still refuses overwrite'
    Save-UcProfile @($target) './profile.json'
    Assert (Test-Path -LiteralPath (Join-Path $locationTest 'profile.json')) 'relative SaveProfile follows PowerShell location'
    Throws { Resolve-UcOutputPath 'Env:UC_DRS_TEST' } 'non-filesystem output provider rejected'
} finally { Pop-Location;Remove-Item -LiteralPath $locationTest -Recurse }

$testLog=Join-Path ([IO.Path]::GetTempPath()) ("uc-drs-tests-"+[guid]::NewGuid().ToString('N')+'.jsonl')
$ctx=New-RunContext $testLog Never $false
$ctx.Secrets.Add('secret"\\value')
Write-Audit $ctx 'test' @{Text='contains secret"\\value';Other="Password: hidden`nNext";Array=@('secret"\\value')}
$record=Get-Content -LiteralPath $testLog -Raw | ConvertFrom-Json
Assert ($record.Data.Text -eq 'contains [REDACTED]' -and $record.Data.Other -eq "Password: [REDACTED]`nNext") 'redaction preserves valid JSON and handles escaped secrets'
Assert ($record.Data.Array[0] -eq '[REDACTED]') 'nested log data redacted'
$ctx.Secrets.Clear()

# Fake streams exercise actual receive/send code. They cannot open a socket.
function New-FakeConnection([string]$Reply='admin:') {
    $stream=[pscustomobject]@{Queue=(New-Object System.Collections.Generic.Queue[string]);Sent=(New-Object System.Collections.Generic.List[string]);Reply=$Reply;Disposed=$false}
    $stream | Add-Member ScriptProperty DataAvailable { $this.Queue.Count -gt 0 }
    $stream | Add-Member ScriptMethod Read { $this.Queue.Dequeue() }
    $stream | Add-Member ScriptMethod WriteLine { param($value) $this.Sent.Add($value); $this.Queue.Enqueue($this.Reply) }
    $stream | Add-Member ScriptMethod Dispose { $this.Disposed=$true }
    return [pscustomobject]@{Address='192.0.2.10';Session=[pscustomobject]@{Connected=$true};Stream=$stream;Ready=$true;SecretExchange=$false}
}
$c=New-FakeConnection "Saved successfully`nadmin:"
Throws { Send-UcCommand $ctx $c 'utils disaster_recovery schedule enable x' None -Mutation } 'transport rejects writes when mode disables them'
Assert ($c.Stream.Sent.Count -eq 0) 'mode guard sends no bytes'
$ctx.AllowRemoteWrite=$true
$r=Send-UcCommand $ctx $c 'utils disaster_recovery schedule enable x' None -Mutation
Assert ($ctx.PendingWrites.Count -eq 1 -and $r.OperationId) 'write response does not resolve pending intent'
Complete-DrsWrite $ctx $r.OperationId 'test readback'
Assert ($ctx.PendingWrites.Count -eq 0) 'verified write resolves matching intent'
$c.Stream.Queue.Enqueue('unexpected')
Throws { Send-UcCommand $ctx $c 'show date' } 'stale buffered output stops next command'
$c=New-FakeConnection
$c.Session.Connected=$false
Throws { Receive-UcOutput $ctx $c 1 None } 'disconnect detected without timeout loop'
$c=New-FakeConnection
$c.SecretExchange=$true;$c.Stream.Queue.Enqueue('Password: supersecret')
Throws { Receive-UcOutput $ctx $c 1 None } 'secret-exchange timeout stops'
Assert (-not ((Get-Content -LiteralPath $testLog -Raw).Contains('supersecret'))) 'secret exchange omitted from timeout audit'
$script:Removed=0
function Remove-SSHSession { param($SSHSession,$ErrorAction) $script:Removed++ }
$c=New-FakeConnection;$stream=$c.Stream
Close-UcConnection $ctx $c
Assert ($stream.Disposed -and $script:Removed -eq 1 -and $null -eq $c.Session) 'normal cleanup disposes stream and removes own session'
$c=New-FakeConnection
$c.Stream | Add-Member ScriptMethod Dispose { throw 'simulated stream disposal failure' } -Force
Close-UcConnection $ctx $c
Assert ($ctx.CleanupFailed -and $script:Removed -eq 2) 'stream cleanup failure still removes session'

# Plan execution must stop on state drift before credentials or configuration I/O.
$originalSnapshot=${function:Get-DrsSnapshot}
function Get-DrsSnapshot { param($Context,$Connection) return $after }
$caller=[pscustomobject]@{}
$caller | Add-Member ScriptMethod ShouldProcess { param($Target,$Action) return $false }
Throws { Invoke-DrsPlan $ctx (New-FakeConnection) $plan $caller } 'state drift blocks execution before credential prompt'
function Get-DrsSnapshot { param($Context,$Connection) return $empty }
$outcomes=@(Invoke-DrsPlan $ctx (New-FakeConnection) $plan $caller)
Assert (@($outcomes | Where-Object Status -eq 'skipped').Count -eq 2) 'WhatIf/ShouldProcess refusal skips writes and credential requests'
Set-Item function:Get-DrsSnapshot $originalSnapshot
# Profile roundtrip contains no credential objects and refuses overwrite.
$profilePath=Join-Path ([IO.Path]::GetTempPath()) ("uc-drs-profile-"+[guid]::NewGuid().ToString('N')+'.json')
Save-UcProfile @($target) $profilePath
$imported=@(Import-UcTargets '' $profilePath)
Assert ($imported.Count -eq 1 -and $imported[0].Settings.SftpUsername -eq 'backup') 'nonsecret profile roundtrip'
Throws { Save-UcProfile @($target) $profilePath } 'profile cannot silently overwrite existing file'
Write-Host "`n$script:Passed checks passed. Windows vault and live Cisco behavior were not exercised."
# Appended to the offline harness; uses its assertions and pure fixtures.
$script:Simulation=[pscustomobject]@{Devices=@();Schedules=@();PendingDevice=$null;PendingSchedule=$null;Phase='command';Commands=(New-Object System.Collections.Generic.List[string])}
function New-SimulatedConnection {
    $stream=[pscustomobject]@{Queue=(New-Object System.Collections.Generic.Queue[string]);Disposed=$false}
    $stream | Add-Member ScriptProperty DataAvailable { $this.Queue.Count -gt 0 }
    $stream | Add-Member ScriptMethod Read { $this.Queue.Dequeue() }
    $stream | Add-Member ScriptMethod Dispose { $this.Disposed=$true }
    $stream | Add-Member ScriptMethod WriteLine {
        param($command)
        $sim=$script:Simulation
        $sim.Commands.Add($command)
        if ($sim.Phase -eq 'password') {
            $sim.Devices+= $sim.PendingDevice;$sim.PendingDevice=$null;$sim.Phase='command'
            # Simulate a server echo to exercise secret-exchange suppression.
            $this.Queue.Enqueue("$command`nDevice added successfully`nadmin:");return
        }
        if ($sim.Phase -eq 'weekday') {
            if ($command -ne 'Tuesday') { throw 'Wrong weekday response.' }
            $sim.Schedules+= $sim.PendingSchedule;$sim.PendingSchedule=$null;$sim.Phase='command'
            $this.Queue.Enqueue("Schedule saved successfully`nadmin:");return
        }
        switch -Regex ($command) {
            '^utils disaster_recovery device list$' {
                $lines=@('device name  device type')+@($sim.Devices | ForEach-Object { "$($_.Name)  $($_.Type)" })+@('admin:')
                $this.Queue.Enqueue(($lines -join "`n"));return
            }
            '^utils disaster_recovery schedule list$' {
                $lines=@('schedule name  device name  Schedule Status')+@($sim.Schedules | ForEach-Object { "$($_.Name)  $($_.Device)  $($_.Status)" })+@('admin:')
                $this.Queue.Enqueue(($lines -join "`n"));return
            }
            '^utils disaster_recovery device add network (\S+) (\S+) (\S+) (\S+) (\d+)$' {
                $sim.PendingDevice=[pscustomobject]@{Name=$Matches[1];Type='NETWORK'};$sim.Phase='password'
                $this.Queue.Enqueue('Enter password:');return
            }
            '^utils disaster_recovery schedule add (\S+) (\S+) (\S+) (\S+) (WEEKLY|MONTHLY)$' {
                $sim.PendingSchedule=[pscustomobject]@{Name=$Matches[1];Device=$Matches[2];Status='disabled'}
                if ($Matches[5] -eq 'WEEKLY') {$sim.Phase='weekday';$this.Queue.Enqueue('Please enter week days:')}
                else {$sim.Schedules+=$sim.PendingSchedule;$sim.PendingSchedule=$null;$this.Queue.Enqueue("Schedule saved successfully`nadmin:")}
                return
            }
            '^utils disaster_recovery schedule enable (\S+)$' {
                foreach($s in $sim.Schedules){if($s.Name -eq $Matches[1]){$s.Status='enabled'}}
                $this.Queue.Enqueue("Schedule enabled successfully`nadmin:");return
            }
            '^utils disaster_recovery schedule disable (\S+)$' {
                foreach($s in $sim.Schedules){if($s.Name -eq $Matches[1]){$s.Status='disabled'}}
                $this.Queue.Enqueue("Schedule disabled successfully`nadmin:");return
            }
            '^utils disaster_recovery schedule delete (\S+)$' {
                $name=$Matches[1];$sim.Schedules=@($sim.Schedules | Where-Object Name -ne $name)
                $this.Queue.Enqueue("Schedule deleted successfully`nadmin:");return
            }
            '^utils disaster_recovery device delete (\S+)$' {
                $name=$Matches[1];$sim.Devices=@($sim.Devices | Where-Object Name -ne $name)
                $this.Queue.Enqueue("Device deleted successfully`nadmin:");return
            }
            default { throw "Unexpected simulated command: $command" }
        }
    }
    return [pscustomobject]@{Address='192.0.2.10';Session=[pscustomobject]@{Connected=$true};Stream=$stream;Ready=$true;SecretExchange=$false}
}
$originalRequest=${function:Request-UcCredential}
function Request-UcCredential {
    param($Context,$Site,$Purpose,$Address,$Port,$Username,[switch]$Fresh)
    return [pscustomobject]@{Credential=[pscredential]::new('backup',(ConvertTo-SecureString 'test-only-echoed-secret' -AsPlainText -Force));Key='test';Stored=$false}
}
$caller | Add-Member ScriptMethod ShouldProcess { param($Target,$Action) return $true } -Force
$ctx.AllowRemoteWrite=$true
$ctx.CleanupFailed=$false
$simConnection=New-SimulatedConnection
$fullResults=@(Invoke-DrsPlan $ctx $simConnection $plan $caller)
Assert ($fullResults.Count -eq 2 -and @($fullResults | Where-Object Status -ne created_enabled_verified_limited).Count -eq 0) 'full simulated create workflow completes weekly and monthly'
Assert (@($script:Simulation.Schedules | Where-Object Status -eq enabled).Count -eq 2) 'simulated schedules enabled and read back'
Assert ($ctx.PendingWrites.Count -eq 0) 'all six simulated writes have matching verification receipts'
Assert (-not ((Get-Content -LiteralPath $testLog -Raw).Contains('test-only-echoed-secret'))) 'echoed SFTP password absent from full-run audit'
$rows=@(Get-Content -LiteralPath $testLog | ForEach-Object { $_ | ConvertFrom-Json })
Assert (@($rows | Where-Object Event -eq operation_before).Count -eq 2 -and @($rows | Where-Object Event -eq operation_after).Count -eq 2) 'full before and after configuration captured per operation'
$script:Simulation.Commands.Clear()
$repeatDiscovery=[pscustomobject]@{Release=$discovery.Release;Coverage=$discovery.Coverage;Snapshot=(Get-DrsSnapshot $ctx $simConnection)}
$repeatPlan=New-DrsPlan $target $repeatDiscovery ([datetime]'2026-11-14')
$repeatResults=@(Invoke-DrsPlan $ctx $simConnection $repeatPlan $caller)
Assert (@($repeatResults | Where-Object Status -eq unverified_existing).Count -eq 2) 'repeat run reports existing settings as unverified'
Assert (@($script:Simulation.Commands | Where-Object {$_ -match ' (add|enable|delete|disable) '}).Count -eq 0) 'repeat run sends no configuration writes'
Set-Item function:Request-UcCredential $originalRequest

# Main-mode guards run before any dependency/credential operation.
$oldOs=$env:OS; $env:OS='Windows_NT'
$ReadOnly=$true;$Apply=$true
Throws { Invoke-UcDrsMain $caller } 'contradictory read-only/apply flags rejected before setup'
$ReadOnly=$false;$Apply=$false;$ManageExisting=$true
Throws { Invoke-UcDrsMain $caller } 'maintenance requires explicit apply'
$ManageExisting=$false;$WhatIfPreference=$true;$InstallDependencies=$true
Throws { Invoke-UcDrsMain $caller } 'WhatIf forbids module installation'
$WhatIfPreference=$false;$InstallDependencies=$false;$env:OS=$oldOs
Write-Host "`nFINAL: $script:Passed offline checks passed. Live Windows/Cisco tests remain operator work."
$originalChoice=${function:Read-Choice};$originalValue=${function:Read-Value};$originalConfirm=${function:Confirm-Choice}
$script:Choices=New-Object System.Collections.Generic.Queue[string]
function Read-Choice { param($Prompt,$Choices,$Default) return $script:Choices.Dequeue() }
function Read-Value { param($Prompt,$Default) return 'Weekly' }
function Confirm-Choice { param($Prompt) return $true }
function Read-Host { param($Prompt,[switch]$AsSecureString) return 'DELETE Weekly' }
$script:Simulation.Commands.Clear()
$script:Choices.Enqueue('DeleteDevice');$script:Choices.Enqueue('Done')
Invoke-DrsMaintenance $ctx $simConnection (Get-DrsSnapshot $ctx $simConnection) $caller
Assert (@($script:Simulation.Commands | Where-Object {$_ -match ' delete '}).Count -eq 0) 'referenced device cannot be deleted'
$script:Choices.Enqueue('DisableSchedule');$script:Choices.Enqueue('Done')
Invoke-DrsMaintenance $ctx $simConnection (Get-DrsSnapshot $ctx $simConnection) $caller
Assert (@($script:Simulation.Schedules | Where-Object { $_.Name -eq 'Weekly' -and $_.Status -eq 'disabled' }).Count -eq 1) 'maintenance disables only selected schedule with readback'
$script:Choices.Enqueue('DeleteSchedule');$script:Choices.Enqueue('DeleteDevice');$script:Choices.Enqueue('Done')
Invoke-DrsMaintenance $ctx $simConnection (Get-DrsSnapshot $ctx $simConnection) $caller
Assert ($script:Simulation.Schedules.Count -eq 1 -and $script:Simulation.Devices.Count -eq 1 -and $script:Simulation.Schedules[0].Name -eq 'Monthly') 'explicit maintenance deletion preserves unrelated pair'
Assert ($ctx.PendingWrites.Count -eq 0) 'maintenance has matching intent verification receipts'
Set-Item function:Read-Choice $originalChoice;Set-Item function:Read-Value $originalValue;Set-Item function:Confirm-Choice $originalConfirm
Remove-Item function:Read-Host

# Appliance-local clock parsing: no host-timezone conversion or manual reformatting.
$parsedClock=ConvertFrom-UcDate "admin:show date`r`nTue Nov 17 23:55:17 EST 2026`r`nadmin:"
Assert ($parsedClock.LocalTime -eq [datetime]'2026-11-17T23:55:17' -and $parsedClock.TimeZone -ceq 'EST' -and $parsedClock.LocalTime.Kind -eq 'Unspecified') 'show date parsed as exact appliance-local time and reported timezone'
Assert ((ConvertFrom-UcDate 'Sat Nov  7 03:04:05 UTC 2026').LocalTime.Day -eq 7) 'show date accepts padded single-digit day'
# Live CUCM 15 SSH shell streams echo the command without an admin: prefix.
$bareEchoClock=ConvertFrom-UcDate "show date`r`nThu Nov 19 21:13:21 EST 2026`r`nadmin:"
Assert ($bareEchoClock.LocalTime -eq [datetime]'2026-11-19T21:13:21' -and $bareEchoClock.TimeZone -ceq 'EST') 'bare show date echo retains exact appliance clock'
Throws { ConvertFrom-UcDate "show date extra`nThu Nov 19 21:13:21 EST 2026" } 'unexpected command-like output still blocks clock parsing'
Throws { ConvertFrom-UcDate "show date`nshow date`nThu Nov 19 21:13:21 EST 2026" } 'repeated bare date echo is rejected'
Throws { ConvertFrom-UcDate "Thu Nov 19 21:13:21 EST 2026`nshow date" } 'trailing command echo is not silently discarded'

Throws { ConvertFrom-UcDate 'Mon Nov 17 23:55:17 EST 2026' } 'inconsistent weekday rejected'
Throws { ConvertFrom-UcDate 'Tue Nov 31 23:55:17 EST 2026' } 'invalid calendar date rejected'
Throws { ConvertFrom-UcDate 'Tue Nov 17 25:55:17 EST 2026' } 'invalid appliance clock time rejected'
Throws { ConvertFrom-UcDate "Tue Nov 17 23:55:17 EST 2026`nWed Nov 18 00:00:00 EST 2026" } 'ambiguous multi-line date response rejected'
Throws { ConvertFrom-UcDate '2026-11-17 23:55:17' } 'missing timezone never falls back to Windows clock'
& {
    function Send-UcCommand { [pscustomobject]@{Text='Tue Nov 17 23:55:17 EST 2026'} }
    function Read-Host { throw 'Clock parsing must not prompt' }
    $autoClock=Read-NodeClock $ctx $null
    Assert ($autoClock.TimeZone -eq 'EST') 'clock acquisition requires no operator input'
}

& {
    $t=New-TestTarget;$t.Settings=New-TestSettings;$t.Settings.MonthlyDay=0
    $clock=ConvertFrom-UcDate 'Tue Nov 17 23:55:17 EST 2026'
    $now=ConvertFrom-UcDate 'Wed Nov 18 00:05:00 EST 2026'
    $script:Simulation.Devices=@([pscustomobject]@{Name='Weekly';Type='NETWORK'},[pscustomobject]@{Name='Unrelated';Type='NETWORK'})
    $script:Simulation.Schedules=@([pscustomobject]@{Name='Weekly';Device='Weekly';Status='enabled'},[pscustomobject]@{Name='Unrelated';Device='Unrelated';Status='enabled'})
    $script:Simulation.Phase='command';$script:Simulation.Commands.Clear()
    $conn=New-SimulatedConnection
    $snapshot=Get-DrsSnapshot $ctx $conn
    $d=[pscustomobject]@{Release='14.0.1';Coverage=(Test-DrsCoverage $t $single $reg);Snapshot=$snapshot}
    $actions=@([pscustomobject]@{Kind='DisableSchedule';Name='Weekly'},[pscustomobject]@{Kind='DeleteSchedule';Name='Weekly'},[pscustomobject]@{Kind='DeleteDevice';Name='Weekly'})
    $projected=Get-DrsProjectedSnapshot $snapshot $actions
    Assert ($projected.Devices.Count -eq 1 -and $projected.Schedules.Count -eq 1 -and $snapshot.Devices.Count -eq 2 -and $snapshot.Schedules[0].Status -eq 'enabled') 'maintenance projection preserves source snapshot and unrelated objects'
    Throws { Get-DrsProjectedSnapshot $snapshot @($actions[2]) } 'projected device deletion rejects remaining schedule reference'
    Throws { Get-DrsProjectedSnapshot $snapshot @($actions[0],$actions[0]) } 'duplicate disable selection rejected'
    Throws { Get-DrsProjectedSnapshot $snapshot @([pscustomobject]@{Kind='DeleteDevice';Name='bad;command'}) } 'planned CLI name injection rejected'
    Throws { Get-DrsProjectedSnapshot $snapshot @([pscustomobject]@{Kind='DeleteEverything';Name='Weekly'}) } 'unknown planned mutation rejected'
    $fullPlan=New-DrsRunPlan $t $d $clock $actions $true
    Assert ($fullPlan.Actions.Count -eq 1 -and $fullPlan.Actions[0].Kind -eq 'CreatePair') 'creation is planned against projected post-maintenance state'
    $maintenanceOnly=New-DrsRunPlan $t $d $clock $actions $false
    Assert ($maintenanceOnly.Actions.Count -eq 0 -and $maintenanceOnly.MaintenanceActions.Count -eq 3) 'maintenance-only saved plan excludes additions'
    $justAdd=New-DrsRunPlan $t $d $clock @() $true
    Assert ($justAdd.Actions[0].Kind -eq 'ReviewExisting') 'additions without deletion preserve existing names'
    & {
        $script:PlanChoices=New-Object System.Collections.Generic.Queue[string]
        # Two schedules: disable Weekly, delete its schedule, then its device.
        foreach($v in @('Add','1','1','Add','2','1','Add','3','1','Done')){$script:PlanChoices.Enqueue($v)}
        function Read-Host { if(-not $script:PlanChoices.Count){throw 'Unexpected prompt'};$script:PlanChoices.Dequeue() }
        function Send-UcCommand { throw 'Preview must not send commands' }
        $chosen=Read-DrsMaintenancePlan $snapshot
        Assert ($chosen.Count -eq 3 -and $chosen[2].Kind -eq 'DeleteDevice') 'interactive planning collects numbered ordered selections without remote commands'
        Assert ($script:PlanChoices.Count -eq 0) 'planning consumes only the expected prompts'
    }
    $entry=New-DrsSavedEntry $t $d $clock $actions $true $fullPlan
    $dir=Join-Path ([IO.Path]::GetTempPath()) ('uc-drs-plans-'+[guid]::NewGuid().ToString('N'))
    $null=New-Item -ItemType Directory $dir
    try {
        $path=Save-DrsPreviewPlan @($entry) (Join-Path $dir 'preview.plan.json')
        $loaded=Read-DrsSavedPlan $path
        Assert ($loaded.Count -eq 1 -and $loaded[0].MaintenanceActions.Count -eq 3) 'saved preview roundtrip retains exact maintenance selections'
        Assert (-not ((Get-Content $path -Raw) -match 'Credential|Password')) 'saved plan contains no credential or password fields'
        Throws { Save-DrsPreviewPlan @($entry) $path } 'saved preview plan cannot overwrite existing evidence'
        $onlyEntry=New-DrsSavedEntry $t $d $clock $actions $false $maintenanceOnly
        $onlyPath=Save-DrsPreviewPlan @($onlyEntry) (Join-Path $dir 'maintenance-only.plan.json')
        $onlyLoaded=Read-DrsSavedPlan $onlyPath
        Assert ((Resolve-DrsSavedPlan $onlyLoaded[0] $d $now).Actions.Count -eq 0) 'maintenance-only plan roundtrip preserves empty additions'
        $addEntry=New-DrsSavedEntry $t $d $clock @() $true $justAdd
        $addPath=Save-DrsPreviewPlan @($addEntry) (Join-Path $dir 'additions-only.plan.json')
        $addLoaded=Read-DrsSavedPlan $addPath
        Assert ((Resolve-DrsSavedPlan $addLoaded[0] $d $now).MaintenanceActions.Count -eq 0) 'additions-only plan roundtrip preserves empty maintenance'
        $secondEntry=$entry | ConvertTo-Json -Depth 20 | ConvertFrom-Json
        $secondEntry.Target.Id='Cluster2';$secondEntry.Target.Address='192.0.2.20'
        $secondEntry.Target.Settings.WeeklyPath='Lab2/Weekly/';$secondEntry.Target.Settings.MonthlyPath='Lab2/Monthly/'
        $multiPath=Save-DrsPreviewPlan @($entry,$secondEntry) (Join-Path $dir 'multi.plan.json')
        $multiLoaded=Read-DrsSavedPlan $multiPath
        Assert ($multiLoaded.Count -eq 2 -and $multiLoaded[1].Target.Id -eq 'Cluster2') 'multi-target saved plans preserve target order and settings'
        $resolved=Resolve-DrsSavedPlan $loaded[0] $d $now
        Assert ($resolved.Actions[0].Start -eq $fullPlan.Actions[0].Start) 'apply preserves saved start time rather than recalculating it'
        $drift=[pscustomobject]@{Release='15.0.1';Coverage=$d.Coverage;Snapshot=$d.Snapshot}
        Throws { Resolve-DrsSavedPlan $loaded[0] $drift $now } 'saved plan rejects release drift'
        $drift=[pscustomobject]@{Release=$d.Release;Coverage=$d.Coverage;Snapshot=$projected}
        Throws { Resolve-DrsSavedPlan $loaded[0] $drift $now } 'saved plan rejects changed DRS objects'
        $changedCoverage=$d.Coverage | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $changedCoverage.Nodes[0].Address='192.0.2.99'
        $drift=[pscustomobject]@{Release=$d.Release;Coverage=$changedCoverage;Snapshot=$d.Snapshot}
        Throws { Resolve-DrsSavedPlan $loaded[0] $drift $now } 'saved plan rejects topology drift'
        $changedCoverage=$d.Coverage | ConvertTo-Json -Depth 10 | ConvertFrom-Json
        $changedCoverage.Registrations[0].Component='CHANGED'
        $drift=[pscustomobject]@{Release=$d.Release;Coverage=$changedCoverage;Snapshot=$d.Snapshot}
        Throws { Resolve-DrsSavedPlan $loaded[0] $drift $now } 'saved plan rejects registration drift'
        $otherZone=ConvertFrom-UcDate 'Wed Nov 18 00:05:00 UTC 2026'
        Throws { Resolve-DrsSavedPlan $loaded[0] $d $otherZone } 'saved plan rejects changed appliance timezone'
        Throws { Resolve-DrsSavedPlan $loaded[0] $d (ConvertFrom-UcDate 'Tue Nov 17 23:00:00 EST 2026') } 'saved plan rejects appliance clock moving backward'
        Throws { Resolve-DrsSavedPlan $loaded[0] $d (ConvertFrom-UcDate 'Tue Nov 24 01:00:00 EST 2026') } 'saved plan rejects elapsed start time'
        $loaded[0].CreationActions[0].Name='Tampered'
        Throws { Resolve-DrsSavedPlan $loaded[0] $d $now } 'saved action description cannot diverge from reconstructed plan'
        $loaded=Read-DrsSavedPlan $path
        $bad=Get-Content $path -Raw | ConvertFrom-Json
        $bad.Targets[0].Target | Add-Member NoteProperty Password 'not-a-real-secret'
        $badPath=Join-Path $dir 'invalid.plan.json';$bad | ConvertTo-Json -Depth 20 | Set-Content $badPath
        Throws { Read-DrsSavedPlan $badPath } 'saved target rejects embedded secret fields'
        $bad=Get-Content $path -Raw | ConvertFrom-Json;$bad.Targets[0].MaintenanceActions[0].Kind='RunCommand'
        $bad | ConvertTo-Json -Depth 20 | Set-Content $badPath
        Throws { Read-DrsSavedPlan $badPath } 'saved plan rejects unsupported executable action'
        $bad=Get-Content $path -Raw | ConvertFrom-Json;$bad.CandidateRevision=2
        $bad | ConvertTo-Json -Depth 20 | Set-Content $badPath
        Throws { Read-DrsSavedPlan $badPath } 'saved plan rejects incompatible candidate schema'

        # Confirm all destructive selections before the first write.
        $script:DeletionAccepted=$false;$script:TestCredentialRequests=0
        function Confirm-Choice { param($Prompt) if($Prompt -like 'Have you recorded*'){return $script:DeletionAccepted};return $true }
        function Read-Host { param($Prompt,[switch]$AsSecureString) return 'DELETE Weekly' }
        function Request-UcCredential { $script:TestCredentialRequests++;[pscustomobject]@{Credential=[pscredential]::new('backup',(ConvertTo-SecureString 'dummy' -AsPlainText -Force));Stored=$false;Key='test'} }
        $script:Simulation.Commands.Clear()
        $declined=@(Invoke-DrsRunPlan $ctx $conn $resolved $caller)
        Assert ($declined[0].Status -eq 'skipped' -and @($script:Simulation.Commands | Where-Object {$_ -match ' (add|enable|disable|delete) '}).Count -eq 0 -and $script:TestCredentialRequests -eq 0) 'declining a later deletion prevents earlier disable and all additions'
        & {
            $script:DeletionAccepted=$true
            function Request-UcCredential { [pscustomobject]@{Credential=[pscredential]::new('wrong-account',(ConvertTo-SecureString 'dummy' -AsPlainText -Force));Stored=$false;Key='test'} }
            $script:Simulation.Commands.Clear()
            Throws { Invoke-DrsRunPlan $ctx $conn $resolved $caller } 'SFTP identity change is rejected before maintenance'
            Assert (@($script:Simulation.Commands | Where-Object {$_ -match ' (add|enable|disable|delete) '}).Count -eq 0) 'SFTP input rejection leaves existing schedules and devices intact'
        }
        $script:DeletionAccepted=$true;$ctx.AllowRemoteWrite=$false;$script:Simulation.Commands.Clear()
        $null=Invoke-DrsRunPlan $ctx $conn $resolved $caller
        Assert (@($script:Simulation.Commands | Where-Object {$_ -match ' (add|enable|disable|delete) '}).Count -eq 0) 'WhatIf/no-write context cannot apply maintenance or additions'
        $ctx.AllowRemoteWrite=$true;$script:Simulation.Commands.Clear()
        $combined=@(Invoke-DrsRunPlan $ctx $conn $resolved $caller)
        $mutations=@($script:Simulation.Commands | Where-Object { $_ -match '^utils disaster_recovery (schedule|device) (disable|delete|add|enable) ' })
        Assert ($mutations.Count -eq 6 -and $mutations[0] -eq 'utils disaster_recovery schedule disable Weekly' -and $mutations[1] -eq 'utils disaster_recovery schedule delete Weekly' -and $mutations[2] -eq 'utils disaster_recovery device delete Weekly' -and $mutations[3] -like '*device add*') 'combined plan executes disable delete-schedule delete-device then creation in order'
        Assert ($combined.Count -eq 4 -and $ctx.PendingWrites.Count -eq 0) 'combined maintenance and creation writes have verified receipts'
        Assert (@($script:Simulation.Schedules | Where-Object {$_.Name -eq 'Unrelated' -and $_.Status -eq 'enabled'}).Count -eq 1 -and @($script:Simulation.Devices | Where-Object Name -eq Unrelated).Count -eq 1) 'combined execution preserves unrelated schedule and device'
        $script:Simulation.Devices+= [pscustomobject]@{Name='Drift';Type='NETWORK'};$script:Simulation.Commands.Clear()
        Throws { Invoke-DrsRunPlan $ctx $conn $resolved $caller } 'live configuration drift before first operation rejects execution'
        Assert (@($script:Simulation.Commands | Where-Object {$_ -match ' (add|enable|disable|delete) '}).Count -eq 0) 'drift rejection sends no configuration commands'
        $script:Simulation.Devices=@($script:Simulation.Devices | Where-Object Name -ne Drift)
        & {
            $realMaintenance=${function:Invoke-DrsMaintenanceAction};$script:ActionCalls=0
            function Invoke-DrsMaintenanceAction {
                param($Context,$Connection,$Snapshot,$Action)
                $script:ActionCalls++
                if($script:ActionCalls -eq 2){throw 'simulated later maintenance failure'}
                & $realMaintenance $Context $Connection $Snapshot $Action
            }
            $script:Simulation.Commands.Clear()
            Throws { Invoke-DrsRunPlan $ctx $conn $resolved $caller } 'later maintenance failure aborts remaining sequence'
            Assert (@($script:Simulation.Commands | Where-Object {$_ -match ' (add|delete|enable) '}).Count -eq 0 -and @($script:Simulation.Schedules | Where-Object {$_.Name -eq 'Weekly' -and $_.Status -eq 'disabled'}).Count -eq 1) 'earlier verified disable remains visible after failure without blind rollback'
        }
        # Main entry point writes a preview plan and loads it without repeating choices.
        & {
            $oldOs=$env:OS;$env:OS='Windows_NT'
            try {
                $Apply=$false;$ReadOnly=$false;$ManageExisting=$false;$SetupLocalSftp=$false;$PlanFile='';$Profile='mock-profile';$Csv='';$SaveProfile='';$SftpRemoteAddress=@();$WhatIfPreference=$false;$InstallDependencies=$false
                $LogPath=Join-Path $dir 'preview-run.jsonl'
                $script:MainDiscovery=$d;$script:MainClock=$clock;$script:SelectionCalls=0;$script:MaintenanceChoices=0;$script:ApplyCalls=0
                function Initialize-PoshSsh { 'mock' }
                function Import-UcTargets { @($t) }
                function Read-UcTargetSelection { param($Targets) $script:SelectionCalls++;$Targets }
                function Open-UcConnection { New-SimulatedConnection }
                function Get-DrsDiscovery { $script:MainDiscovery }
                function Read-NodeClock { $script:MainClock }
                function Read-DrsMaintenancePlan { $script:MaintenanceChoices++;return ,$actions }
                function Read-Choice { 'Yes' }
                function Confirm-Choice { $true }
                function Invoke-DrsRunPlan { param($Context,$Connection,$Plan,$Caller) $script:ApplyCalls++;$script:AppliedPlan=$Plan;@([pscustomobject]@{Name='Weekly';Status='created_enabled_verified_limited'}) }
                $code=Invoke-UcDrsMain $caller
                $writtenPlan=[IO.Path]::ChangeExtension($LogPath,'plan.json')
                Assert ($code -eq 0 -and (Test-Path $writtenPlan) -and $script:ApplyCalls -eq 0) 'normal preview writes a saved plan without invoking execution'
                $Apply=$true;$PlanFile=$writtenPlan;$Profile='';$LogPath=Join-Path $dir 'apply-run.jsonl';$script:MainClock=$now
                $code=Invoke-UcDrsMain $caller
                Assert ($code -eq 0 -and $script:ApplyCalls -eq 1 -and $script:SelectionCalls -eq 1 -and $script:MaintenanceChoices -eq 1) 'apply loads saved selections without repeating target or maintenance selection'
                Assert ($script:AppliedPlan.MaintenanceActions.Count -eq 3) 'saved maintenance actions reach the apply executor unchanged'
                $script:MainDiscovery=[pscustomobject]@{Release='15.0.1';Coverage=$d.Coverage;Snapshot=$d.Snapshot};$LogPath=Join-Path $dir 'stale-run.jsonl'
                $code=Invoke-UcDrsMain $caller
                Assert ($code -eq 1 -and $script:ApplyCalls -eq 1) 'main rejects stale plan before execution'
                $PlanFile='';$Profile='mock-profile'
                Throws { Invoke-UcDrsMain $caller } 'normal apply requires a saved preview plan'
                $Apply=$false;$LogPath=Join-Path $dir 'failed-preview.jsonl'
                function Get-DrsDiscovery { throw 'simulated inspection error' }
                $code=Invoke-UcDrsMain $caller
                $failedLog=@(Get-Content $LogPath | ForEach-Object { $_ | ConvertFrom-Json })
                Assert ($code -eq 1 -and -not (Test-Path ([IO.Path]::ChangeExtension($LogPath,'plan.json')))) 'failed preview writes no saved plan'
                Assert (@($failedLog | Where-Object Event -eq 'target_stopped')[0].Data.Action -like 'No configuration writes*') 'failed preview audit supplies no-write recovery guidance'
                function Get-DrsDiscovery { $script:MainDiscovery }
                $Apply=$false;$LogPath=Join-Path $dir 'cancel-selection.jsonl'
                function Read-UcTargetSelection { throw [OperationCanceledException]::new('Cancelled before connecting.') }
                $code=Invoke-UcDrsMain $caller
                $cancelLog=@(Get-Content $LogPath | ForEach-Object { $_ | ConvertFrom-Json })
                Assert ($code -eq 3 -and $cancelLog[-1].Event -eq 'run_cancelled' -and -not (Test-Path ([IO.Path]::ChangeExtension($LogPath,'plan.json')))) 'main cancellation exits 3, records cancellation and saves no plan'
                function Read-UcTargetSelection { param($Targets) $Targets }
                $script:MainDiscovery=$d;$LogPath=Join-Path $dir 'cancel-connected.jsonl'
                function Read-DrsMaintenancePlan { throw [OperationCanceledException]::new('Preview cancelled. No plan saved.') }
                $code=Invoke-UcDrsMain $caller
                $cancelLog=@(Get-Content $LogPath | ForEach-Object { $_ | ConvertFrom-Json })
                Assert ($code -eq 3 -and @($cancelLog | Where-Object Event -eq 'target_result')[0].Data.ConfigurationStatus -eq 'cancelled') 'connected preview cancellation records target result and returns ordinary cancellation'
                $LogPath=Join-Path $dir 'cancel-cleanup-failed.jsonl'
                function Close-UcConnection { param($Context,$Connection) $Context.CleanupFailed=$true }
                $code=Invoke-UcDrsMain $caller
                Assert ($code -eq 1) 'cleanup failure takes precedence over cancellation exit code'

            } finally { $env:OS=$oldOs }
        }
    } finally { Remove-Item -LiteralPath $dir -Recurse }
}

# Authentication retry uses the same exception-chain classification as Posh-SSH.
Add-Type -TypeDefinition 'namespace Renci.SshNet.Common { public class SshAuthenticationException : System.Exception { public SshAuthenticationException(string message):base(message){} } }'
$script:ConnectCount=0;$script:FailAlways=$false;$script:SavedCalls=0
$originalSave=${function:Save-ValidatedCredential}
function Request-UcCredential {
    param($Context,$Site,$Purpose,$Address,$Port,$Username,[switch]$Fresh)
    [pscustomobject]@{Credential=[pscredential]::new('admin',(ConvertTo-SecureString 'dummy' -AsPlainText -Force));Key='test';Stored=$false}
}
function Save-ValidatedCredential { param($Context,$Entry) $script:SavedCalls++ }
function Confirm-Choice { param($Prompt) return $true }
function New-SSHSession {
    param($ComputerName,$Port,$Credential,$ConnectionTimeout,$ErrorAction)
    $script:ConnectCount++
    if ($script:ConnectCount -eq 1 -or $script:FailAlways) { throw [Renci.SshNet.Common.SshAuthenticationException]::new('mock authentication failure') }
    [pscustomobject]@{Connected=$true}
}
function New-SSHShellStream {
    param($SSHSession,$TerminalName,$Columns,$Rows,$Width,$Height,$ErrorAction)
    $fake=New-FakeConnection;$fake.Stream.Queue.Enqueue('admin:');return $fake.Stream
}
$connected=Open-UcConnection $ctx $target
Assert ($script:ConnectCount -eq 2 -and $connected.Ready) 'authentication rejection gets exactly one fresh attempt'
Assert ($script:SavedCalls -eq 1) 'credential save offered only after authentication success'
Close-UcConnection $ctx $connected
$script:ConnectCount=0;$script:FailAlways=$true;$script:SavedCalls=0
Throws { Open-UcConnection $ctx $target } 'second authentication rejection stops target'
Assert ($script:ConnectCount -eq 2 -and $script:SavedCalls -eq 0) 'failed credentials never saved and retry is bounded'
$script:ConnectCount=1;$script:FailAlways=$false;$script:SavedCalls=0
function New-SSHShellStream { throw 'simulated CLI startup stream failure' }
$removedBefore=$script:Removed
Throws { Open-UcConnection $ctx $target } 'CLI startup stream failure stops target after successful authentication'
Assert ($script:SavedCalls -eq 1 -and $script:Removed -eq ($removedBefore+1)) 'save occurs before CLI startup and later failure still cleans SSH session'
Set-Item function:Request-UcCredential $originalRequest;Set-Item function:Save-ValidatedCredential $originalSave;Set-Item function:Confirm-Choice $originalConfirm
$roundtrip=@(Import-UcTargets '' $profilePath)
Assert ($roundtrip[0].Settings.Retention -eq 2) 'nested settings validated during profile import'
Write-Host "`nFINAL: $script:Passed offline checks passed. These offline checks do not test native Windows or live Cisco behavior."
$pathRows=@(ConvertFrom-DrsList "device name  device type  device path`nsftpdevice  NETWORK  192.0.2.50 : /root`nadmin:" device)
Assert ($pathRows[0].Server -eq '192.0.2.50' -and $pathRows[0].Path -eq '/root') 'documented device server/path retained for verification'
$helpTokens=$null;$helpErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($ScriptPath,[ref]$helpTokens,[ref]$helpErrors)
Assert ($ast.GetHelpContent().Synopsis -like '*Preview and configure*') 'Get-Help synopsis is discoverable'
Write-Host "`nFINAL: $script:Passed offline checks passed. These offline checks do not test native Windows or live Cisco behavior."
