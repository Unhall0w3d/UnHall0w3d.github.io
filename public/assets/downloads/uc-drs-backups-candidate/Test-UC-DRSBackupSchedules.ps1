# Offline deterministic tests. No Posh-SSH module, Windows vault or remote access.
param([string]$ScriptPath=(Join-Path $PSScriptRoot 'Set-UC-DRSBackupSchedules-v1.6.1.ps1'))
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
$single=@(ConvertFrom-UcTopology "192.0.2.10 cucm.lab cucm Publisher authenticated`nadmin:" '192.0.2.10')
$reg=@(ConvertFrom-DrsRegistration "Feature  Component`nCCM PLATFORM`nCCM CCMDB`nadmin:" cucm)
Assert ($reg.Count -eq 2) 'registration table retains components'
$labels=@(ConvertFrom-DrsRegistration "Feature : CCM`nComponent : PLATFORM`nFeature : CCM`nComponent : CCMDB`nadmin:" cucm)
Assert ($labels.Count -eq 2) 'registration label format retains components'
Throws { ConvertFrom-DrsRegistration "CCM PLATFORM`nFeature : CCM" cucm } 'truncated registration blocks'
Throws { ConvertFrom-DrsRegistration "CCM PLATFORM`nunexpected row extra" cucm } 'partly parsed registration blocks'
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
    $t=New-TestTarget $tech; $feature=if($tech -eq 'CUC'){'CONNECTION'}else{$tech}
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
Assert ($coverage.Status -eq 'blocked' -and ($coverage.Issues -join ' ') -like '*expected CCM*') 'IM&P-only declared CUCM is blocked despite complete IM&P components'
$ccmRow=[pscustomobject]@{Node='cucm';Feature='CCM';Component='synthetic'}
Assert ((Test-DrsCoverage $policyTarget @($impOnly) ($impOnlyRows+$ccmRow)).Status -eq 'blocked') 'CCM on an undiscovered node cannot satisfy CUCM coverage'
$cmNode=[pscustomobject]@{Hostname='cucm';DatabaseRole='Publisher'}
Assert ((Test-DrsCoverage $policyTarget @($cmNode,$impOnly) ($impOnlyRows+$ccmRow)).Status -eq 'registered_features_checked') 'CUCM with IM&P remains accepted'
Assert ((Test-DrsCoverage $policyTarget @($cmNode) @($ccmRow)).Status -eq 'registered_features_checked') 'CUCM-only remains accepted'
$wrongCase=[pscustomobject]@{Node='CUCM';Feature='CCM';Component='synthetic'}
Assert ((Test-DrsCoverage $policyTarget @($cmNode) @($wrongCase)).Status -eq 'blocked') 'primary feature retains exact node-name matching'
foreach($product in @('CUC','CER','UCCX')) {
    $productTarget=New-TestTarget $product
    $feature=(Get-UcTechnologyPolicy $product).RequiredFeature
    $productRow=[pscustomobject]@{Node='cucm';Feature=$feature;Component='synthetic'}
    Assert ((Test-DrsCoverage $productTarget @($cmNode) @($productRow)).Status -eq 'registered_features_checked') "$product expected primary feature accepted"
    Assert ((Test-DrsCoverage $productTarget @($cmNode) @($ccmRow)).Status -eq 'blocked') "$product wrong primary feature blocked"
}
Assert ((Test-DrsCoverage $policyTarget @() @()).Status -eq 'blocked') 'empty discovered inventory cannot pass coverage'


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
Set-Item function:Request-UcCredential $originalRequest;Set-Item function:Save-ValidatedCredential $originalSave;Set-Item function:Confirm-Choice $originalConfirm
$roundtrip=@(Import-UcTargets '' $profilePath)
Assert ($roundtrip[0].Settings.Retention -eq 2) 'nested settings validated during profile import'
Write-Host "`nFINAL: $script:Passed offline checks passed. Windows vault and live Cisco behavior remain untested."
$pathRows=@(ConvertFrom-DrsList "device name  device type  device path`nsftpdevice  NETWORK  192.0.2.50 : /root`nadmin:" device)
Assert ($pathRows[0].Server -eq '192.0.2.50' -and $pathRows[0].Path -eq '/root') 'documented device server/path retained for verification'
$helpTokens=$null;$helpErrors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($ScriptPath,[ref]$helpTokens,[ref]$helpErrors)
Assert ($ast.GetHelpContent().Synopsis -like '*Preview and configure*') 'Get-Help synopsis is discoverable'
Write-Host "`nFINAL: $script:Passed offline checks passed. Windows vault and live Cisco behavior remain untested."
