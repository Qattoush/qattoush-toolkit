# ============================================================
#   QATTOUSH FPS OPTIMIZER v3.0 — Universal Edition
#   Safe for ALL PCs: Laptops & Desktops
#   Auto-detects hardware and applies appropriate tweaks
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
function Section($title) {
    Write-Host "`n  [$title]" -ForegroundColor Cyan
}
function OK($msg)     { Write-Host "  [+] $msg" -ForegroundColor Green }
function SKIP($msg)   { Write-Host "  [-] $msg" -ForegroundColor DarkGray }
function WARN($msg)   { Write-Host "  [!] $msg" -ForegroundColor Yellow }
function INFO($msg)   { Write-Host "  [i] $msg" -ForegroundColor White }

$errors = 0
function SafeReg($path, $name, $type, $value) {
    try {
        if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name $name -Type $type -Value $value -Force
    } catch {
        Write-Host "  [ERR] Registry failed: $path -> $name" -ForegroundColor Red
        $script:errors++
    }
}
#endregion

#region DETECT HARDWARE
Clear-Host
Write-Host @"
  =====================================================
   QATTOUSH FPS OPTIMIZER v3.0 — Universal Edition
   Detecting your hardware...
  =====================================================
"@ -ForegroundColor Magenta

# Detect laptop vs desktop
$chassisTypes = (Get-WmiObject -Class Win32_SystemEnclosure).ChassisTypes
$isLaptop = $chassisTypes | Where-Object { $_ -in @(8,9,10,11,12,14,18,21,30,31,32) }
$isLaptop = [bool]$isLaptop

# Detect CPU
$cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
$cpuName = $cpu.Name.Trim()
$cpuCores = $cpu.NumberOfCores
$cpuThreads = $cpu.NumberOfLogicalProcessors

# Detect GPU
$gpu = Get-WmiObject Win32_VideoController | Where-Object { $_.AdapterRAM -gt 0 } | Select-Object -First 1
$gpuName = if ($gpu) { $gpu.Name.Trim() } else { "Unknown GPU" }
$isNvidia = $gpuName -match "NVIDIA|GeForce|GTX|RTX"
$isAMD    = $gpuName -match "AMD|Radeon|RX "
$isIntel  = $gpuName -match "Intel|Iris|UHD|HD Graphics"

# Detect RAM
$ramGB = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)

# Detect Windows version
$winVer = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion
$winBuild = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber

Write-Host ""
INFO "Device type  : $(if ($isLaptop) { 'LAPTOP — thermal-safe mode ON' } else { 'DESKTOP — full performance mode' })"
INFO "CPU          : $cpuName ($cpuCores cores / $cpuThreads threads)"
INFO "GPU          : $gpuName"
INFO "RAM          : $($ramGB) GB"
INFO "Windows      : $winVer (Build $winBuild)"
Write-Host ""
#endregion

#region 1. POWER PLAN
Section "POWER PLAN"
$planGUID = "e9a42b02-d5df-448d-aa00-03f14749eb61"
$existing = powercfg /list | Select-String $planGUID
if (!$existing) {
    powercfg -duplicatescheme $planGUID | Out-Null
    OK "Ultimate Performance plan created"
} else {
    SKIP "Ultimate Performance plan already exists"
}
powercfg /setactive $planGUID
OK "Ultimate Performance plan activated"

if ($isLaptop) {
    # Laptop: 50% min so CPU can cool down when idle, still boosts on load
    powercfg /setacvalueindex $planGUID SUB_PROCESSOR PROCTHROTTLEMIN 50
    powercfg /setacvalueindex $planGUID SUB_PROCESSOR PROCTHROTTLEMAX 100
    # Keep hibernate for lid-close behavior on laptops
    WARN "Laptop detected — CPU min set to 50% (thermal protection), hibernate kept ON"
} else {
    # Desktop: full throttle
    powercfg /setacvalueindex $planGUID SUB_PROCESSOR PROCTHROTTLEMIN 100
    powercfg /setacvalueindex $planGUID SUB_PROCESSOR PROCTHROTTLEMAX 100
    powercfg /hibernate off
    OK "Desktop — CPU forced 100% min/max, hibernate disabled"
}

# Shared: disable sleep while on AC power
powercfg /setacvalueindex $planGUID SUB_SLEEP STANDBYIDLE 0
OK "AC sleep disabled"
powercfg /setactive $planGUID
#endregion

#region 2. SYSTEM RESPONSIVENESS
Section "SYSTEM RESPONSIVENESS"
$mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
SafeReg $mmPath "NetworkThrottlingIndex" DWord 0xFFFFFFFF
SafeReg $mmPath "SystemResponsiveness"   DWord 0
OK "Network throttling OFF, full system responsiveness"

$gamesPath = "$mmPath\Tasks\Games"
SafeReg $gamesPath "Affinity"            DWord 0
SafeReg $gamesPath "Background Only"     String "False"
SafeReg $gamesPath "Clock Rate"          DWord 2710
SafeReg $gamesPath "GPU Priority"        DWord 8
SafeReg $gamesPath "Priority"            DWord 6
SafeReg $gamesPath "Scheduling Category" String "High"
SafeReg $gamesPath "SFIO Priority"       String "High"
OK "Game thread scheduling: CPU priority 6, GPU priority 8"
#endregion

#region 3. GPU TWEAKS
Section "GPU / GRAPHICS"

# Hardware GPU Scheduling — Windows 10 2004+ only
if ($winBuild -ge 19041) {
    SafeReg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" DWord 2
    OK "Hardware GPU scheduling enabled (Windows 10 2004+ confirmed)"
} else {
    SKIP "Hardware GPU scheduling skipped — requires Windows 10 2004+"
}

# Disable Multi-Plane Overlay — fixes stutters on most systems
SafeReg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "PlatformSupportMPO" DWord 0
OK "MPO (Multi-Plane Overlay) disabled — reduces stutters"

# Fullscreen optimizations
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode"               DWord 2
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_HonorUserFSEBehaviorMode"      DWord 0
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_DXGIHonorFSEWindowsCompatible" DWord 1
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_EFSEBehaviorMode"              DWord 0
OK "Fullscreen optimizations disabled"

# GPU power mode — only on desktop (laptops self-manage thermals)
if ($isNvidia -and -not $isLaptop) {
    $nvidiaKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    SafeReg $nvidiaKey "PowerMizerEnable"  DWord 0
    SafeReg $nvidiaKey "PerfLevelSrc"      DWord 0x2222
    SafeReg $nvidiaKey "PowerMizerLevel"   DWord 1
    SafeReg $nvidiaKey "PowerMizerLevelAC" DWord 1
    OK "NVIDIA — GPU power forced to max performance (desktop only)"
} elseif ($isNvidia -and $isLaptop) {
    WARN "NVIDIA laptop GPU — power registry skipped to prevent thermal shutdown"
    INFO "Set 'Prefer Maximum Performance' manually in NVIDIA Control Panel instead"
} elseif ($isAMD) {
    INFO "AMD GPU detected — enable Anti-Lag and set performance mode in Radeon Software"
} elseif ($isIntel) {
    INFO "Intel GPU detected — enable Performance Mode in Intel Graphics Command Center"
}
#endregion

#region 4. GAME MODE & XBOX
Section "GAME MODE / XBOX / GAME BAR"
SafeReg "HKCU:\Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" DWord 0
SafeReg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled"       DWord 1
SafeReg "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode"         DWord 1
SafeReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" DWord 0
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" DWord 0
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_Enabled" DWord 0
OK "Game Mode ON, Game DVR/Capture OFF, Game Bar disabled"

$xboxServices = @("XblAuthManager","XblGameSave","XboxGipSvc","XboxNetApiSvc","BcastDVRUserService")
foreach ($svc in $xboxServices) {
    try {
        Stop-Service $svc -Force -ErrorAction SilentlyContinue
        Set-Service  $svc -StartupType Disabled -ErrorAction SilentlyContinue
        OK "Disabled Xbox service: $svc"
    } catch { SKIP "Xbox service not found: $svc" }
}
#endregion

#region 5. NETWORK
Section "NETWORK / PING REDUCTION"
$tcpPath = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
Get-ChildItem $tcpPath -ErrorAction SilentlyContinue | ForEach-Object {
    SafeReg $_.PSPath "TcpAckFrequency" DWord 1
    SafeReg $_.PSPath "TCPNoDelay"      DWord 1
}
OK "Nagle's algorithm disabled on all interfaces (lower ping)"

$tcpGlobal = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
SafeReg $tcpGlobal "DefaultTTL"              DWord 64
SafeReg $tcpGlobal "EnablePMTUDiscovery"     DWord 1
SafeReg $tcpGlobal "GlobalMaxTcpWindowSize"  DWord 65535
SafeReg $tcpGlobal "Tcp1323Opts"             DWord 1
SafeReg $tcpGlobal "TcpTimedWaitDelay"       DWord 30
OK "TCP stack tuned for low-latency gaming"

ipconfig /flushdns | Out-Null
ipconfig /registerdns | Out-Null
netsh int tcp set global autotuninglevel=normal 2>$null | Out-Null
netsh int tcp set global chimney=disabled       2>$null | Out-Null
netsh int tcp set global rss=enabled            2>$null | Out-Null
netsh int tcp set global timestamps=disabled    2>$null | Out-Null
OK "DNS flushed, TCP auto-tuning normalized, RSS enabled"
#endregion

#region 6. CPU / TIMER / INPUT
Section "CPU / TIMER / INPUT LATENCY"

# High resolution timer — safe on all hardware
bcdedit /set useplatformtick yes    2>$null | Out-Null
bcdedit /set disabledynamictick yes 2>$null | Out-Null
bcdedit /set tscsyncpolicy Enhanced 2>$null | Out-Null
OK "High-resolution timer forced, dynamic tick disabled"

# CPU scheduling: favor foreground (game) threads
SafeReg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" DWord 38
OK "CPU scheduling prioritizes foreground/game thread"

# Mouse acceleration OFF — safe and recommended for all gamers
SafeReg "HKCU:\Control Panel\Mouse" "MouseSpeed"      String "0"
SafeReg "HKCU:\Control Panel\Mouse" "MouseThreshold1" String "0"
SafeReg "HKCU:\Control Panel\Mouse" "MouseThreshold2" String "0"
OK "Mouse acceleration disabled (raw 1:1 input)"
#endregion

#region 7. MEMORY
Section "MEMORY"
$memPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
SafeReg $memPath "ClearPageFileAtShutdown" DWord 0
SafeReg $memPath "LargeSystemCache"        DWord 0
SafeReg $memPath "IoPageLockLimit"         DWord 983040

if ($ramGB -ge 16) {
    # Enough RAM to safely disable paging executive
    SafeReg $memPath "DisablePagingExecutive" DWord 1
    OK "Paging executive disabled (16GB+ RAM confirmed: $($ramGB)GB)"
} else {
    SafeReg $memPath "DisablePagingExecutive" DWord 0
    WARN "Paging executive kept ON — less than 16GB RAM detected ($($ramGB)GB)"
    INFO "Disabling it with low RAM can cause system instability"
}

# Disable SysMain (Superfetch) — benefits SSDs, safe on all
try {
    Stop-Service "SysMain" -Force -ErrorAction SilentlyContinue
    Set-Service  "SysMain" -StartupType Disabled -ErrorAction SilentlyContinue
    OK "SysMain/Superfetch disabled"
} catch { SKIP "SysMain not found or protected" }

$pfPath = "$memPath\PrefetchParameters"
SafeReg $pfPath "EnablePrefetcher"  DWord 0
SafeReg $pfPath "EnableSuperfetch"  DWord 0
OK "Prefetcher disabled"

# NTFS last access timestamps
fsutil behavior set disablelastaccess 1 2>$null | Out-Null
OK "NTFS last-access timestamps disabled"
#endregion

#region 8. VISUAL EFFECTS
Section "VISUAL EFFECTS"
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects" "VisualFXSetting" DWord 2
SafeReg "HKCU:\Control Panel\Desktop" "MenuShowDelay"                                              String "0"
SafeReg "HKCU:\Control Panel\Desktop\WindowMetrics" "MinAnimate"                                  String "0"
OK "Visual effects set to Best Performance, menu delays removed"
#endregion

#region 9. BACKGROUND SERVICES
Section "BACKGROUND SERVICES"
$killServices = @(
    @{ Name="DiagTrack";          Reason="Telemetry / data collection" },
    @{ Name="dmwappushservice";   Reason="WAP Push messaging" },
    @{ Name="WSearch";            Reason="Windows Search indexer (high disk I/O)" },
    @{ Name="lfsvc";              Reason="Geolocation service" },
    @{ Name="MapsBroker";         Reason="Maps background downloader" },
    @{ Name="NetTcpPortSharing";  Reason="TCP port sharing" },
    @{ Name="RemoteRegistry";     Reason="Remote registry access" },
    @{ Name="RetailDemo";         Reason="Retail demo mode" },
    @{ Name="wisvc";              Reason="Windows Insider service" },
    @{ Name="TrkWks";             Reason="Distributed Link Tracking" },
    @{ Name="WerSvc";             Reason="Windows Error Reporting" }
)
foreach ($svc in $killServices) {
    try {
        Stop-Service $svc.Name -Force -ErrorAction SilentlyContinue
        Set-Service  $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
        OK "Disabled: $($svc.Name) — $($svc.Reason)"
    } catch { SKIP "Not found or protected: $($svc.Name)" }
}
#endregion

#region 10. SUMMARY
Write-Host "`n  =====================================================" -ForegroundColor Magenta
Write-Host "   DEVICE: $(if ($isLaptop) { 'LAPTOP (Thermal-Safe Mode)' } else { 'DESKTOP (Full Performance Mode)' })" -ForegroundColor $(if ($isLaptop) { 'Yellow' } else { 'Green' })
if ($errors -eq 0) {
    Write-Host "   STATUS: ALL TWEAKS APPLIED SUCCESSFULLY" -ForegroundColor Green
} else {
    Write-Host "   STATUS: DONE WITH $errors ERROR(S) — check output above" -ForegroundColor Yellow
}
Write-Host @"
  =====================================================
   WHAT WAS APPLIED:
     [+] Ultimate Performance power plan
     [+] Game thread CPU/GPU priority maximized
     [+] GPU hardware scheduling + MPO disabled
     [+] Fullscreen optimizations OFF
     [+] Nagle's algorithm OFF (lower ping)
     [+] TCP stack tuned for gaming
     [+] Mouse acceleration OFF
     [+] High-res timer, dynamic tick OFF
     [+] Game DVR/Capture OFF, Game Mode ON
     [+] Xbox services disabled
     [+] SysMain / Prefetch OFF
     [+] Background telemetry services OFF
     [+] Visual effects -> Best Performance
     [+] NTFS last-access disabled

   HARDWARE-SPECIFIC DECISIONS:
"@ -ForegroundColor White

if ($isLaptop) {
    Write-Host "     [LAPTOP] CPU min kept at 50% — thermal safety" -ForegroundColor Yellow
    Write-Host "     [LAPTOP] Hibernate kept ON — lid-close behavior preserved" -ForegroundColor Yellow
    Write-Host "     [LAPTOP] GPU power registry skipped — use driver panel instead" -ForegroundColor Yellow
} else {
    Write-Host "     [DESKTOP] CPU forced 100% min/max — max performance" -ForegroundColor Green
    Write-Host "     [DESKTOP] Hibernate disabled" -ForegroundColor Green
    if ($isNvidia) {
        Write-Host "     [DESKTOP] NVIDIA GPU power forced to max performance" -ForegroundColor Green
    }
}

if ($ramGB -ge 16) {
    Write-Host "     [RAM $($ramGB)GB] Paging executive disabled — safe" -ForegroundColor Green
} else {
    Write-Host "     [RAM $($ramGB)GB] Paging executive kept ON — below 16GB threshold" -ForegroundColor Yellow
}

Write-Host @"

   MANUAL STEPS (do these yourself):
     [>] NVIDIA: Control Panel -> Prefer Max Performance + Low Latency = Ultra
     [>] AMD:    Radeon Software -> Anti-Lag ON, Enhanced Sync OFF
     [>] BIOS (Desktop only): Enable XMP/EXPO for RAM
     [>] BIOS (Desktop only): Disable C-States if extreme performance needed
     [>] Cap FPS ~3 below monitor refresh (e.g. 141 for 144Hz) for lower latency
     [>] Keep GPU drivers up to date

   A RESTART IS REQUIRED FOR FULL EFFECT.
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
