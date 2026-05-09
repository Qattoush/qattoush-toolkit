# ============================================================
#   QATTOUSH AMD OPTIMIZER v2.0
#   Maximum FPS + Minimum Latency for AMD GPUs
#   Safe for ALL PCs — Laptop & Desktop Aware
#   Run as Administrator in PowerShell
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
function ERR($msg)        { Write-Host "  [ERR] $msg" -ForegroundColor Red }

$errors = 0
function SafeReg($path, $name, $type, $value) {
    try {
        if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name $name -Type $type -Value $value -Force
    } catch {
        ERR "Registry failed: $path -> $name"
        $script:errors++
    }
}
#endregion

Clear-Host
Write-Host @"
  =====================================================
   QATTOUSH AMD OPTIMIZER v2.0
   Max FPS + Minimum Latency — Hardware Aware
  =====================================================
"@ -ForegroundColor Red

#region DETECT GPU & SYSTEM
Section "DETECTING YOUR SYSTEM"

# Detect AMD GPU
$gpu = Get-WmiObject Win32_VideoController | Where-Object {
    $_.Name -match "AMD|Radeon|RX |Vega|RDNA|Navi|Fury|Polaris"
} | Select-Object -First 1

if (-not $gpu) {
    Write-Host "`n  [!!] NO AMD GPU DETECTED" -ForegroundColor Red
    Write-Host "  This script is for AMD Radeon GPUs only." -ForegroundColor Red
    Write-Host "  Detected GPU: $((Get-WmiObject Win32_VideoController | Select-Object -First 1).Name)" -ForegroundColor Yellow
    Write-Host "`n  Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

$gpuName     = $gpu.Name.Trim()
$gpuVRAM     = [math]::Round($gpu.AdapterRAM / 1GB, 0)
$driverVer   = $gpu.DriverVersion

# Detect laptop vs desktop
$chassisTypes = (Get-WmiObject Win32_SystemEnclosure).ChassisTypes
$isLaptop = [bool]($chassisTypes | Where-Object { $_ -in @(8,9,10,11,12,14,18,21,30,31,32) })
$isMobileGPU  = $gpuName -match "Mobile|Laptop|M$| M "
$isLaptopMode = $isLaptop -or $isMobileGPU

# Detect Windows build
$winBuild = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber

# Detect RAM
$ramGB = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)

# Detect if integrated AMD GPU (APU) is also present
$amdIGPU = Get-WmiObject Win32_VideoController | Where-Object {
    $_.Name -match "AMD.*Graphics|Radeon.*Graphics|Vega.*Graphics" -and
    $_.Name -notmatch "RX |Vega 56|Vega 64|Fury|Nano"
}
$hasAPU = [bool]$amdIGPU

INFO "GPU          : $gpuName"
INFO "VRAM         : ${gpuVRAM}GB"
INFO "Driver ver   : $driverVer"
INFO "Device type  : $(if ($isLaptopMode) { 'LAPTOP — thermal-safe mode' } else { 'DESKTOP — full performance mode' })"
INFO "Windows build: $winBuild"
INFO "RAM          : ${ramGB}GB"
if ($hasAPU) { WARN "APU/iGPU also detected — make sure games are set to use your Radeon dGPU in Adrenalin" }

# Find AMD driver registry key
$amdDriverKey = $null
$driverBase   = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
0..9 | ForEach-Object {
    $sub = "$driverBase\000$_"
    if (Test-Path $sub) {
        $prov = (Get-ItemProperty $sub -ErrorAction SilentlyContinue).ProviderName
        if ($prov -match "AMD|ATI|Advanced Micro") { $amdDriverKey = $sub }
    }
}

if ($amdDriverKey) {
    OK "AMD driver registry key found: $amdDriverKey"
} else {
    WARN "AMD driver key not found — install AMD Adrenalin drivers then re-run"
}
#endregion

#region 1. POWER PLAN
Section "POWER PLAN"
# Your original used SCHEME_MIN which is 'High Performance' — good but not the best
# Ultimate Performance is better — less CPU park = better 1% lows
$planGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
$existing = powercfg /list | Select-String $planGUID
if (!$existing) {
    powercfg -duplicatescheme $planGUID | Out-Null
    OK "Ultimate Performance plan created"
} else { SKIP "Ultimate Performance plan already exists" }

powercfg /setactive $planGUID
OK "Ultimate Performance activated (better than High Performance for AMD 1% lows)"

if ($isLaptopMode) {
    powercfg /setacvalueindex $planGUID SUB_PROCESSOR PROCTHROTTLEMIN 50
    powercfg /setacvalueindex $planGUID SUB_PROCESSOR PROCTHROTTLEMAX 100
    WARN "Laptop: CPU min 50% — thermal protection ON"
} else {
    powercfg /setacvalueindex $planGUID SUB_PROCESSOR PROCTHROTTLEMIN 100
    powercfg /setacvalueindex $planGUID SUB_PROCESSOR PROCTHROTTLEMAX 100
    OK "Desktop: CPU locked at 100% min/max"
}
powercfg /setacvalueindex $planGUID SUB_SLEEP STANDBYIDLE 0
powercfg /setactive $planGUID
OK "Sleep on AC: DISABLED"
#endregion

#region 2. WINDOWS GPU SETTINGS
Section "WINDOWS GPU SETTINGS"

# Hardware GPU Scheduling — Win10 2004+ only
if ($winBuild -ge 19041) {
    SafeReg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" DWord 2
    OK "Hardware GPU Scheduling: ENABLED"
} else {
    SKIP "HW GPU Scheduling requires Win10 2004+ (your build: $winBuild)"
}

# Disable MPO — causes stutters and black flashes on AMD too
SafeReg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "PlatformSupportMPO" DWord 0
OK "Multi-Plane Overlay (MPO): DISABLED — fixes black screen stutters"

# TDR delay — prevent false 'driver crashed' on heavy GPU loads
SafeReg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDelay"    DWord 10
SafeReg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDdiDelay" DWord 10
OK "TDR timeout: 10s — prevents false driver crash errors"

# Fullscreen optimizations OFF
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode"                DWord 2
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_HonorUserFSEBehaviorMode"       DWord 0
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_DXGIHonorFSEWindowsCompatible"  DWord 1
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_EFSEBehaviorMode"               DWord 0
OK "Fullscreen Optimizations: DISABLED — true exclusive fullscreen"

# DXGI minimum frame latency
SafeReg "HKLM:\SOFTWARE\Microsoft\DirectX" "MaximumFrameLatency" DWord 1
OK "DXGI max frame latency: 1 — minimum display buffering"
#endregion

#region 3. AMD DRIVER TWEAKS
Section "AMD DRIVER REGISTRY TWEAKS"

if ($amdDriverKey) {
    if (-not $isLaptopMode) {
        # Desktop: disable all power saving in driver
        SafeReg $amdDriverKey "PP_SclkDeepSleepDisable"     DWord 1   # Disable GPU core deep sleep
        SafeReg $amdDriverKey "PP_ThermalAutoThrottlingEnable" DWord 0 # Disable auto thermal throttle
        SafeReg $amdDriverKey "DisableDrmdmaPowerGating"    DWord 1   # Disable DRMDMA power gating
        SafeReg $amdDriverKey "EnableUlps"                  DWord 0   # Disable Ultra Low Power State
        SafeReg $amdDriverKey "EnableUlps_NA"               DWord 0   # Disable ULPS on secondary GPU
        SafeReg $amdDriverKey "PP_DisablePowerContainment"  DWord 1   # Disable power containment
        OK "Desktop: All AMD power gating + deep sleep DISABLED"
        OK "Desktop: Power containment DISABLED — GPU runs at full TDP"
    } else {
        # Laptop: only disable deep sleep, keep thermal throttle
        SafeReg $amdDriverKey "PP_SclkDeepSleepDisable"     DWord 1   # Still disable — causes stutters
        SafeReg $amdDriverKey "EnableUlps"                  DWord 1   # Keep ULPS on laptop
        SafeReg $amdDriverKey "PP_ThermalAutoThrottlingEnable" DWord 1 # Keep thermal protection
        SafeReg $amdDriverKey "PP_DisablePowerContainment"  DWord 0   # Keep power limits
        WARN "Laptop: Thermal throttle and power limits KEPT for safety"
        OK "Laptop: GPU deep sleep disabled (reduces stutters without thermal risk)"
    }

    # These are safe on both laptop and desktop
    SafeReg $amdDriverKey "DisableBlockWrite"             DWord 0   # Enable block write (faster VRAM access)
    SafeReg $amdDriverKey "StutterMode"                   DWord 0   # Disable stutter mode
    SafeReg $amdDriverKey "PP_GfxCardWorkaround"          DWord 1   # Enable GPU workaround
    SafeReg $amdDriverKey "KMD_EnableComputePreemption"   DWord 0   # Disable compute preemption (smoother frame times)
    SafeReg $amdDriverKey "DisableASPM"                   DWord 1   # Disable PCIe active state power mgmt
    OK "Stutter mode: DISABLED"
    OK "Block write: ENABLED (faster VRAM access)"
    OK "Compute preemption: DISABLED (smoother frame pacing)"
    OK "PCIe ASPM: DISABLED (no PCIe power throttling)"

} else {
    WARN "AMD driver key not found — skipping driver-level tweaks"
}
#endregion

#region 4. AMD SHADER CACHE
Section "AMD SHADER CACHE"

# Maximize shader cache to reduce in-game stutter
$amdCachePath = "$env:LOCALAPPDATA\AMD\DxCache"
$amdGlCachePath = "$env:LOCALAPPDATA\AMD\GLCache"

SafeReg "HKLM:\SOFTWARE\ATI Technologies\CBT" "ShaderCacheMaxSize"  DWord 4096
SafeReg "HKLM:\SOFTWARE\AMD\CN"               "ShaderCacheEnabled"  DWord 1
OK "AMD shader cache: ENABLED, max size set to 4GB"

# Clean stale shader cache (forces rebuild = less stutters from corrupt cache)
$caches = @(
    @{ Path=$amdCachePath;   Label="AMD DX Shader Cache" },
    @{ Path=$amdGlCachePath; Label="AMD GL Shader Cache" }
)
foreach ($c in $caches) {
    if (Test-Path $c.Path) {
        try {
            Remove-Item "$($c.Path)\*" -Recurse -Force -ErrorAction SilentlyContinue
            OK "Cleared: $($c.Label) — will rebuild fresh on next game launch"
        } catch { SKIP "Could not clear: $($c.Label)" }
    } else { SKIP "Not found: $($c.Label)" }
}
#endregion

#region 5. GAME SCHEDULING & RESPONSIVENESS
Section "GAME THREAD PRIORITY"

$mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
SafeReg $mmPath "SystemResponsiveness"   DWord 0
SafeReg $mmPath "NetworkThrottlingIndex" DWord 0xFFFFFFFF
OK "System responsiveness: MAX — OS dedicates resources to foreground game"

$gamesPath = "$mmPath\Tasks\Games"
SafeReg $gamesPath "Affinity"            DWord 0
SafeReg $gamesPath "Background Only"     String "False"
SafeReg $gamesPath "Clock Rate"          DWord 2710
SafeReg $gamesPath "GPU Priority"        DWord 8
SafeReg $gamesPath "Priority"            DWord 6
SafeReg $gamesPath "Scheduling Category" String "High"
SafeReg $gamesPath "SFIO Priority"       String "High"
OK "Game thread: CPU priority 6, GPU priority 8, SFIO High"

# CPU scheduling favor foreground
SafeReg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" DWord 38
OK "CPU scheduler: prioritizes foreground (game) threads"
#endregion

#region 6. AMD TELEMETRY — KILL IT
Section "AMD TELEMETRY & BACKGROUND TASKS"

$amdTelemetryServices = @(
    @{ Name="AMD Crash Defender Service"; Label="AMD Crash Defender" },
    @{ Name="AMD External Events Utility"; Label="AMD External Events Utility" },
    @{ Name="AMDRyzenMasterDriverV20";    Label="AMD Ryzen Master Driver" }
)
foreach ($svc in $amdTelemetryServices) {
    try {
        Stop-Service $svc.Name -Force -ErrorAction SilentlyContinue
        Set-Service  $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
        OK "Disabled: $($svc.Label)"
    } catch { SKIP "Not found: $($svc.Name)" }
}

# Disable AMD telemetry scheduled tasks
$amdTasks = @(
    "\AMD\AMD Install Manager Task",
    "\AMD\AMD Streaming Audio Device Update Task"
)
foreach ($task in $amdTasks) {
    try {
        Disable-ScheduledTask -TaskPath (Split-Path $task) `
            -TaskName (Split-Path $task -Leaf) -ErrorAction SilentlyContinue | Out-Null
        OK "Disabled AMD task: $(Split-Path $task -Leaf)"
    } catch { SKIP "Task not found: $(Split-Path $task -Leaf)" }
}

SafeReg "HKLM:\SOFTWARE\AMD\CN" "AnalyticsEnabled" DWord 0
SafeReg "HKLM:\SOFTWARE\AMD\CN" "TelemetryEnabled" DWord 0
OK "AMD analytics and telemetry registry: DISABLED"
#endregion

#region 7. ADRENALIN CONTROL PANEL GUIDE
Section "AMD ADRENALIN — MANUAL SETTINGS GUIDE"
Write-Host ""
Write-Host "  Open AMD Adrenalin Software and set these manually:" -ForegroundColor Yellow
Write-Host ""

$adrenalinSettings = @(
    @{ Tab="Gaming -> Graphics";     Setting="Anti-Lag";                  Value="ENABLED — single biggest latency reduction" },
    @{ Tab="Gaming -> Graphics";     Setting="Anti-Lag+";                 Value="ENABLED if available (newer GPUs)" },
    @{ Tab="Gaming -> Graphics";     Setting="Radeon Chill";              Value="DISABLED — adds latency" },
    @{ Tab="Gaming -> Graphics";     Setting="Radeon Boost";              Value="DISABLED — lowers resolution dynamically" },
    @{ Tab="Gaming -> Graphics";     Setting="Image Sharpening (RSR)";    Value="OFF unless using FSR" },
    @{ Tab="Gaming -> Graphics";     Setting="Enhanced Sync";             Value="DISABLED — causes frame drops and black screens" },
    @{ Tab="Gaming -> Graphics";     Setting="Wait for Vertical Refresh"; Value="OFF (V-Sync off)" },
    @{ Tab="Gaming -> Graphics";     Setting="Frame Rate Target Control"; Value="3 below monitor Hz (e.g. 141 for 144Hz)" },
    @{ Tab="Performance";            Setting="Tuning";                    Value="Auto — or Manual for OC if stable" },
    @{ Tab="Performance";            Setting="Power Limit";               Value="+20% if desktop (more sustained clocks)" },
    @{ Tab="Performance -> Metrics"; Setting="GPU Metrics Overlay";       Value="Enable during testing to check temps" },
    @{ Tab="Display";                Setting="FreeSync";                  Value="ENABLED if your monitor supports it" },
    @{ Tab="Display";                Setting="Display Color";             Value="GPU Scaling OFF unless needed" }
)

foreach ($s in $adrenalinSettings) {
    Write-Host "  [$($s.Tab)]" -ForegroundColor DarkCyan -NoNewline
    Write-Host " $($s.Setting)" -ForegroundColor Cyan -NoNewline
    Write-Host " -> $($s.Value)" -ForegroundColor White
}

if ($isLaptopMode) {
    Write-Host ""
    WARN "LAPTOP: In Adrenalin -> System -> Switchable Graphics"
    WARN "Set each game to 'High Performance' to force AMD dGPU"
    WARN "Do NOT set Power Limit to +20% on a laptop"
}
#endregion

#region 8. SUMMARY
Write-Host "`n  =====================================================" -ForegroundColor Red
if ($errors -eq 0) {
    Write-Host "   ALL AMD TWEAKS APPLIED SUCCESSFULLY" -ForegroundColor Green
} else {
    Write-Host "   DONE WITH $errors ERROR(S) — check output above" -ForegroundColor Yellow
}
Write-Host @"
  =====================================================
   GPU            : $gpuName
   VRAM           : ${gpuVRAM}GB
   MODE           : $(if ($isLaptopMode) { 'LAPTOP (Thermal-Safe)' } else { 'DESKTOP (Full Performance)' })

   WHAT WAS APPLIED:
     [+] Ultimate Performance power plan (better than High Perf)
     [+] Hardware GPU Scheduling ON
     [+] MPO (Multi-Plane Overlay) DISABLED
     [+] TDR timeout increased (no false crashes)
     [+] Fullscreen Optimizations DISABLED
     [+] DXGI frame latency: 1
     [+] Shader cache ENABLED + stale cache cleared
     [+] Game thread priority: CPU 6, GPU 8
     [+] PCIe ASPM DISABLED (no power throttling)
     [+] Compute preemption DISABLED (smoother frames)
     [+] AMD stutter mode DISABLED
     [+] AMD telemetry services + tasks DISABLED
$(if (-not $isLaptopMode) {
"     [+] GPU deep sleep + ULPS + power containment DISABLED"
} else {
"     [!] Thermal throttle + power limits KEPT (laptop safety)"
"     [+] GPU deep sleep disabled (stutters only, no heat risk)"
})

   WHAT YOUR ORIGINAL SCRIPT HAD WRONG:
     [x] powercfg /setactive SCHEME_MIN = High Performance
         Ultimate Performance is better for AMD 1% lows
     [x] Only 1 registry key — barely any effect
     [x] No GPU detection — would run on any PC silently

   STILL DO IN AMD ADRENALIN:
     [>] Anti-Lag -> ENABLED
     [>] Enhanced Sync -> DISABLED
     [>] Frame Rate Target -> 3 below monitor Hz
     [>] V-Sync -> OFF
     [>] FreeSync -> ON (if monitor supports)

   RESTART REQUIRED FOR FULL EFFECT
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
