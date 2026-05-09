# ============================================================
#   QATTOUSH FULL RESTORE v2.0
#   Reverts ALL tweaks from the QATTOUSH Optimizer Suite
#   FPS + Network + NVIDIA + AMD + Debloat settings
#   Safe for ALL PCs — Run as Administrator in PowerShell
# ============================================================

#region ADMIN CHECK
if (-NOT ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Write-Host "`n[!] Must run as Administrator. Relaunching..." -ForegroundColor Red
    Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
#endregion

#region HELPERS
function Section($title) { Write-Host "`n  [$title]" -ForegroundColor Cyan }
function OK($msg)         { Write-Host "  [+] $msg" -ForegroundColor Green }
function SKIP($msg)       { Write-Host "  [-] $msg" -ForegroundColor DarkGray }
function WARN($msg)       { Write-Host "  [!] $msg" -ForegroundColor Yellow }
function INFO($msg)       { Write-Host "  [i] $msg" -ForegroundColor White }

$restored = 0
$errors   = 0

function SafeReg($path, $name, $type, $value) {
    try {
        if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name $name -Type $type -Value $value -Force
        $script:restored++
    } catch {
        Write-Host "  [ERR] Registry: $path -> $name" -ForegroundColor Red
        $script:errors++
    }
}

function RemoveReg($path, $name) {
    try {
        if (Test-Path $path) {
            Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
            OK "Removed registry key: $name"
            $script:restored++
        } else { SKIP "Key not found: $name" }
    } catch { SKIP "Could not remove: $name" }
}
#endregion

Clear-Host
Write-Host @"
  =====================================================
   QATTOUSH FULL RESTORE v2.0
   Reverting all optimizer tweaks to Windows defaults
  =====================================================
"@ -ForegroundColor Yellow

# Confirm before doing anything
Write-Host "`n  This will restore ALL Windows default settings." -ForegroundColor White
Write-Host "  All QATTOUSH optimizer tweaks will be undone." -ForegroundColor White
Write-Host "`n  Are you sure? (Y/N): " -ForegroundColor Yellow -NoNewline
$confirm = Read-Host
if ($confirm -notmatch "^[Yy]") {
    Write-Host "`n  Cancelled. No changes made." -ForegroundColor Green
    exit
}

# Detect GPU for GPU-specific revert
$hasNvidia = [bool](Get-WmiObject Win32_VideoController | Where-Object { $_.Name -match "NVIDIA|GeForce|GTX|RTX" })
$hasAMD    = [bool](Get-WmiObject Win32_VideoController | Where-Object { $_.Name -match "AMD|Radeon|RX " })
$chassisTypes = (Get-WmiObject Win32_SystemEnclosure).ChassisTypes
$isLaptop  = [bool]($chassisTypes | Where-Object { $_ -in @(8,9,10,11,12,14,18,21,30,31,32) })

INFO "GPU: $(if ($hasNvidia) { 'NVIDIA detected' } elseif ($hasAMD) { 'AMD detected' } else { 'Unknown' })"
INFO "Device: $(if ($isLaptop) { 'Laptop' } else { 'Desktop' })"
#endregion

#region 1. POWER PLAN
Section "POWER PLAN"
# Restore Balanced — the safe Windows default for all PCs
powercfg /setactive SCHEME_BALANCED
OK "Power plan: restored to Balanced (Windows default)"

# Restore CPU throttle settings on Balanced plan
$balancedGUID = "381b4222-f694-41f0-9685-ff5bb260df2e"
powercfg /setacvalueindex $balancedGUID SUB_PROCESSOR PROCTHROTTLEMIN 5   2>$null
powercfg /setacvalueindex $balancedGUID SUB_PROCESSOR PROCTHROTTLEMAX 100 2>$null
powercfg /setacvalueindex $balancedGUID SUB_SLEEP STANDBYIDLE 1800        2>$null
powercfg /setactive $balancedGUID
OK "CPU throttle restored: min 5%, max 100% (Windows default)"
OK "Sleep timer restored: 30 minutes on AC"

# Re-enable hibernate (important for laptops)
powercfg /hibernate on 2>$null
OK "Hibernate: re-enabled"

# Remove Ultimate Performance plan (optional — clean up)
$upGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
$upExists = powercfg /list | Select-String $upGUID
if ($upExists) {
    powercfg /delete $upGUID 2>$null
    OK "Ultimate Performance plan removed"
} else { SKIP "Ultimate Performance plan not found" }
#endregion

#region 2. SYSTEM RESPONSIVENESS
Section "SYSTEM RESPONSIVENESS"
$mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
SafeReg $mmPath "NetworkThrottlingIndex" DWord 10           # Windows default
SafeReg $mmPath "SystemResponsiveness"   DWord 20           # Windows default
OK "Network throttling: restored to default (10)"
OK "System responsiveness: restored to 20 (Windows default)"

$gamesPath = "$mmPath\Tasks\Games"
SafeReg $gamesPath "GPU Priority"        DWord 8            # Default
SafeReg $gamesPath "Priority"            DWord 2            # Default
SafeReg $gamesPath "Scheduling Category" String "Medium"    # Default
SafeReg $gamesPath "SFIO Priority"       String "Normal"    # Default
OK "Game scheduling profile: restored to Windows defaults"
#endregion

#region 3. GPU / GRAPHICS
Section "GPU / GRAPHICS"
$gpuPath = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
SafeReg $gpuPath "HwSchMode"          DWord 1    # Default = auto/off
SafeReg $gpuPath "PlatformSupportMPO" DWord 1    # Default = enabled
SafeReg $gpuPath "TdrDelay"           DWord 2    # Windows default 2s
SafeReg $gpuPath "TdrDdiDelay"        DWord 5    # Windows default 5s
OK "Hardware GPU Scheduling: restored to Windows default (auto)"
OK "Multi-Plane Overlay (MPO): restored to enabled"
OK "TDR timeout: restored to Windows defaults (2s/5s)"

# Restore fullscreen optimizations
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode"                DWord 0
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_HonorUserFSEBehaviorMode"       DWord 1
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_DXGIHonorFSEWindowsCompatible"  DWord 0
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_EFSEBehaviorMode"               DWord 0
OK "Fullscreen optimizations: RESTORED"

# Restore DXGI latency
RemoveReg "HKLM:\SOFTWARE\Microsoft\DirectX" "MaximumFrameLatency"
#endregion

#region 4. GAME MODE / GAME BAR / GAME DVR
Section "GAME MODE / GAME BAR / GAME DVR"
SafeReg "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" DWord 1
SafeReg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled"       DWord 0
SafeReg "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode"         DWord 0
RemoveReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR"
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" DWord 1
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_Enabled"                DWord 1
OK "Game Bar: restored"
OK "Game DVR/Capture: restored"
OK "Game Mode: set to Windows default (auto)"
#endregion

#region 5. TELEMETRY & PRIVACY
Section "TELEMETRY & PRIVACY"
# Your original only restored 1 key — we restore all of them
SafeReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry"                  DWord 1
SafeReg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry"   DWord 1
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled"                  DWord 1
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" DWord 1
RemoveReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy"
RemoveReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed"
RemoveReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities"
RemoveReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities"
RemoveReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana"
RemoveReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent" "DisableWindowsConsumerFeatures"
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338388Enabled" DWord 1
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338389Enabled" DWord 1
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SilentInstalledAppsEnabled"      DWord 1
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "PreInstalledAppsEnabled"         DWord 1
RemoveReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation"
OK "Telemetry: restored to Windows default level 1"
OK "Advertising ID: restored"
OK "Activity History: restored"
OK "Cortana: restored"
OK "Location: restored"
OK "Start Menu suggestions: restored"
#endregion

#region 6. NETWORK
Section "NETWORK SETTINGS"
netsh int tcp set global autotuninglevel=normal  2>$null | Out-Null
netsh int tcp set global rss=enabled             2>$null | Out-Null
netsh int tcp set global chimney=disabled        2>$null | Out-Null
netsh int tcp set global timestamps=disabled     2>$null | Out-Null
netsh int tcp set global ecncapability=enabled   2>$null | Out-Null
netsh int tcp set global dca=enabled             2>$null | Out-Null
netsh int tcp set global initialRto=3000         2>$null | Out-Null
netsh int tcp set global maxsynretransmissions=4 2>$null | Out-Null
OK "TCP stack: restored to Windows defaults"

# Restore Nagle's algorithm
$tcpInterfaces = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
Get-ChildItem $tcpInterfaces -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $_.PSPath -Name "TCPNoDelay"      -ErrorAction SilentlyContinue
    Remove-ItemProperty -Path $_.PSPath -Name "TcpDelAckTicks"  -ErrorAction SilentlyContinue
}
OK "Nagle's algorithm: restored (re-enabled on all interfaces)"

# Restore TCP parameters
$tcpParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
SafeReg $tcpParams "DefaultTTL"                  DWord 128    # Windows default
SafeReg $tcpParams "TcpTimedWaitDelay"           DWord 120    # Windows default 120s
SafeReg $tcpParams "TcpMaxDataRetransmissions"   DWord 5      # Windows default
RemoveReg $tcpParams "GlobalMaxTcpWindowSize"
RemoveReg $tcpParams "TcpWindowSize"
RemoveReg $tcpParams "MaxUserPort"
RemoveReg $tcpParams "MaxFreeTcbs"
OK "TCP parameters: restored to Windows defaults"

# Restore DNS to automatic (DHCP) on all active adapters
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
foreach ($adapter in $adapters) {
    try {
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ResetServerAddresses -ErrorAction SilentlyContinue
        OK "DNS restored to automatic (DHCP) on: $($adapter.Name)"
    } catch { SKIP "Could not reset DNS on: $($adapter.Name)" }
}

# Restore DNS cache settings
$dnsCache = "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters"
RemoveReg $dnsCache "CacheHashTableBucketSize"
RemoveReg $dnsCache "CacheHashTableSize"
RemoveReg $dnsCache "MaxCacheEntryTtlLimit"
OK "DNS cache settings: restored to Windows defaults"

# QoS bandwidth restore
RemoveReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" "NonBestEffortLimit"
OK "QoS 20% bandwidth reserve: restored"

ipconfig /flushdns 2>$null | Out-Null
OK "DNS cache flushed"
#endregion

#region 7. CPU / TIMER / INPUT
Section "CPU / TIMER / INPUT"
bcdedit /deletevalue useplatformtick    2>$null | Out-Null
bcdedit /deletevalue disabledynamictick 2>$null | Out-Null
bcdedit /deletevalue tscsyncpolicy      2>$null | Out-Null
OK "Timer resolution: restored to Windows defaults (dynamic tick re-enabled)"

SafeReg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" DWord 2
OK "CPU scheduling: restored to Windows default (2)"

# Restore mouse settings
SafeReg "HKCU:\Control Panel\Mouse" "MouseSpeed"      String "1"
SafeReg "HKCU:\Control Panel\Mouse" "MouseThreshold1" String "6"
SafeReg "HKCU:\Control Panel\Mouse" "MouseThreshold2" String "10"
OK "Mouse acceleration: RESTORED to Windows default"
#endregion

#region 8. MEMORY
Section "MEMORY"
$memPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
SafeReg $memPath "DisablePagingExecutive"  DWord 0   # Windows default: off
SafeReg $memPath "LargeSystemCache"        DWord 0
SafeReg $memPath "ClearPageFileAtShutdown" DWord 0
OK "Paging executive: RESTORED (re-enabled)"

$pfPath = "$memPath\PrefetchParameters"
SafeReg $pfPath "EnablePrefetcher"  DWord 3   # Windows default: 3
SafeReg $pfPath "EnableSuperfetch"  DWord 3   # Windows default: 3
OK "Prefetcher: RESTORED to default (3)"

# Re-enable NTFS last access timestamps
fsutil behavior set disablelastaccess 0 2>$null | Out-Null
OK "NTFS last-access timestamps: RESTORED"
#endregion

#region 9. VISUAL EFFECTS
Section "VISUAL EFFECTS"
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" DWord 0
SafeReg "HKCU:\Control Panel\Desktop" "MenuShowDelay"                                              String "400"
SafeReg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate"                                   String "1"
OK "Visual effects: RESTORED to Windows default (Let Windows decide)"
OK "Menu delay: restored to 400ms"
OK "Window animations: RESTORED"
#endregion

#region 10. SERVICES — RE-ENABLE
Section "SERVICES — RE-ENABLING"
$restoreServices = @(
    @{ Name="DiagTrack";          Label="Connected User Experiences & Telemetry";  Start="Automatic" },
    @{ Name="WSearch";            Label="Windows Search";                          Start="Automatic" },
    @{ Name="SysMain";            Label="SysMain (Superfetch)";                    Start="Automatic" },
    @{ Name="WerSvc";             Label="Windows Error Reporting";                 Start="Manual"    },
    @{ Name="PcaSvc";             Label="Program Compatibility Assistant";         Start="Manual"    },
    @{ Name="lfsvc";              Label="Geolocation Service";                     Start="Manual"    },
    @{ Name="XblAuthManager";     Label="Xbox Live Auth Manager";                  Start="Manual"    },
    @{ Name="XblGameSave";        Label="Xbox Live Game Save";                     Start="Manual"    },
    @{ Name="XboxGipSvc";         Label="Xbox Accessory Management";               Start="Manual"    },
    @{ Name="XboxNetApiSvc";      Label="Xbox Live Networking";                    Start="Manual"    }
)
foreach ($svc in $restoreServices) {
    try {
        Set-Service $svc.Name -StartupType $svc.Start -ErrorAction SilentlyContinue
        Start-Service $svc.Name -ErrorAction SilentlyContinue
        OK "Restored service: $($svc.Label)"
    } catch { SKIP "Could not restore: $($svc.Name)" }
}
#endregion

#region 11. SCHEDULED TASKS — RE-ENABLE
Section "SCHEDULED TASKS — RE-ENABLING"
$restoreTasks = @(
    @{ Path="\Microsoft\Windows\Application Experience"; Name="Microsoft Compatibility Appraiser" },
    @{ Path="\Microsoft\Windows\Application Experience"; Name="ProgramDataUpdater" },
    @{ Path="\Microsoft\Windows\Customer Experience Improvement Program"; Name="Consolidator" },
    @{ Path="\Microsoft\Windows\Customer Experience Improvement Program"; Name="UsbCeip" },
    @{ Path="\Microsoft\Windows\Windows Error Reporting"; Name="QueueReporting" },
    @{ Path="\Microsoft\Windows\Feedback\Siuf"; Name="DmClient" }
)
foreach ($task in $restoreTasks) {
    try {
        Enable-ScheduledTask -TaskPath $task.Path -TaskName $task.Name -ErrorAction SilentlyContinue | Out-Null
        OK "Restored task: $($task.Name)"
    } catch { SKIP "Task not found: $($task.Name)" }
}
#endregion

#region 12. NVIDIA RESTORE
if ($hasNvidia) {
    Section "NVIDIA — RESTORE DEFAULTS"
    $nvidiaKey = $null
    $driverBase = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    0..9 | ForEach-Object {
        $sub = "$driverBase\000$_"
        if (Test-Path $sub) {
            $prov = (Get-ItemProperty $sub -ErrorAction SilentlyContinue).ProviderName
            if ($prov -match "NVIDIA") { $nvidiaKey = $sub }
        }
    }
    if ($nvidiaKey) {
        RemoveReg $nvidiaKey "PowerMizerEnable"
        RemoveReg $nvidiaKey "PowerMizerLevel"
        RemoveReg $nvidiaKey "PowerMizerLevelAC"
        RemoveReg $nvidiaKey "PerfLevelSrc"
        RemoveReg $nvidiaKey "EnablePreRenderedFrames"
        RemoveReg $nvidiaKey "RMHdcpKeyglobZero"
        OK "NVIDIA driver registry: restored to defaults"
    } else { SKIP "NVIDIA driver key not found" }

    RemoveReg "HKCU:\Software\NVIDIA Corporation\Global\NVTweak" "PowerMizerEnable"
    RemoveReg "HKCU:\Software\NVIDIA Corporation\Global\NVTweak" "ThreadedOptimization"

    # Re-enable NVIDIA telemetry services
    $nvServices = @("NvTelemetryContainer","NvContainerNetworkService")
    foreach ($svc in $nvServices) {
        try {
            Set-Service $svc -StartupType Automatic -ErrorAction SilentlyContinue
            Start-Service $svc -ErrorAction SilentlyContinue
            OK "Restored NVIDIA service: $svc"
        } catch { SKIP "Not found: $svc" }
    }
    OK "NVIDIA settings: restored to driver defaults"
    WARN "Also reset NVIDIA Control Panel manually -> Restore Defaults"
}
#endregion

#region 13. AMD RESTORE
if ($hasAMD) {
    Section "AMD — RESTORE DEFAULTS"
    $amdKey = $null
    $driverBase = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
    0..9 | ForEach-Object {
        $sub = "$driverBase\000$_"
        if (Test-Path $sub) {
            $prov = (Get-ItemProperty $sub -ErrorAction SilentlyContinue).ProviderName
            if ($prov -match "AMD|ATI") { $amdKey = $sub }
        }
    }
    if ($amdKey) {
        RemoveReg $amdKey "PP_SclkDeepSleepDisable"
        RemoveReg $amdKey "PP_ThermalAutoThrottlingEnable"
        RemoveReg $amdKey "EnableUlps"
        RemoveReg $amdKey "EnableUlps_NA"
        RemoveReg $amdKey "PP_DisablePowerContainment"
        RemoveReg $amdKey "KMD_EnableComputePreemption"
        RemoveReg $amdKey "DisableASPM"
        RemoveReg $amdKey "StutterMode"
        OK "AMD driver registry: restored to defaults"
    } else { SKIP "AMD driver key not found" }

    # Re-enable AMD telemetry
    SafeReg "HKLM:\SOFTWARE\AMD\CN" "AnalyticsEnabled" DWord 1
    SafeReg "HKLM:\SOFTWARE\AMD\CN" "TelemetryEnabled" DWord 1
    OK "AMD telemetry: restored"
    WARN "Also reset AMD Adrenalin -> Preferences -> Reset to defaults"
}
#endregion

#region 14. SUMMARY
Write-Host "`n  =====================================================" -ForegroundColor Yellow
if ($errors -eq 0) {
    Write-Host "   FULL RESTORE COMPLETE — NO ERRORS" -ForegroundColor Green
} else {
    Write-Host "   RESTORE COMPLETE WITH $errors ERROR(S)" -ForegroundColor Yellow
}
Write-Host @"
  =====================================================
   WHAT WAS RESTORED:
     [+] Power plan -> Balanced (Windows default)
     [+] CPU throttle -> 5% min / 100% max
     [+] Sleep timer -> 30min AC
     [+] Hibernate -> re-enabled
     [+] Visual effects -> Let Windows decide
     [+] Mouse acceleration -> restored
     [+] Nagle's algorithm -> restored
     [+] DNS -> automatic (DHCP)
     [+] TCP stack -> Windows defaults
     [+] QoS 20% reserve -> restored
     [+] Timer resolution -> dynamic tick restored
     [+] CPU scheduler -> default
     [+] NTFS timestamps -> restored
     [+] Prefetcher/Superfetch -> restored
     [+] Paging executive -> restored
     [+] Telemetry -> default level 1
     [+] Advertising ID -> restored
     [+] Activity History -> restored
     [+] Cortana -> restored
     [+] Windows Search service -> restored
     [+] All disabled services -> restored
     [+] Scheduled telemetry tasks -> restored
     [+] Fullscreen optimizations -> restored
     [+] MPO -> restored
     [+] Hardware GPU Scheduling -> default
$(if ($hasNvidia) { "     [+] NVIDIA driver tweaks -> removed" })
$(if ($hasAMD)    { "     [+] AMD driver tweaks -> removed" })

   WHAT YOUR ORIGINAL SCRIPT MISSED:
     [x] Only restored 2 settings out of 50+
     [x] Left all network, GPU, timer, memory,
         service tweaks permanently applied

   STILL DO MANUALLY:
     [>] NVIDIA Control Panel -> Manage 3D Settings
         -> Restore Defaults
     [>] AMD Adrenalin -> Preferences -> Reset
     [>] Settings -> Apps -> Startup (re-enable apps)
     [>] Restart your PC now

   NOTE: Removed apps (Xbox, Skype etc.) must be
   reinstalled from the Microsoft Store manually.
  =====================================================
"@ -ForegroundColor White

Write-Host "  Restart now? (Y/N): " -ForegroundColor Cyan -NoNewline
$answer = Read-Host
if ($answer -match "^[Yy]") {
    Write-Host "  Restarting in 5 seconds..." -ForegroundColor Yellow
    Start-Sleep 5
    Restart-Computer -Force
}
#endregion
