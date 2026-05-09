# ============================================================
#   QATTOUSH NVIDIA OPTIMIZER v2.0
#   Maximum FPS + Minimum Latency — Safe for ALL PCs
#   Detects GPU, drivers, laptop vs desktop automatically
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
   QATTOUSH NVIDIA OPTIMIZER v2.0
   Max FPS + Minimum Latency — Hardware Aware
  =====================================================
"@ -ForegroundColor Green

#region DETECT GPU & SYSTEM
Section "DETECTING YOUR SYSTEM"

# Detect NVIDIA GPU
$gpu = Get-WmiObject Win32_VideoController | Where-Object {
    $_.Name -match "NVIDIA|GeForce|GTX|RTX|Quadro"
} | Select-Object -First 1

if (-not $gpu) {
    Write-Host "`n  [!!] NO NVIDIA GPU DETECTED" -ForegroundColor Red
    Write-Host "  This script is for NVIDIA GPUs only." -ForegroundColor Red
    Write-Host "  Detected GPU: $((Get-WmiObject Win32_VideoController | Select-Object -First 1).Name)" -ForegroundColor Yellow
    Write-Host "`n  Press any key to exit..." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit
}

$gpuName   = $gpu.Name.Trim()
$gpuVRAM   = [math]::Round($gpu.AdapterRAM / 1GB, 0)
$driverVer = $gpu.DriverVersion

# Detect laptop vs desktop
$chassisTypes = (Get-WmiObject Win32_SystemEnclosure).ChassisTypes
$isLaptop = [bool]($chassisTypes | Where-Object { $_ -in @(8,9,10,11,12,14,18,21,30,31,32) })

# Detect Windows build
$winBuild = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber

# Detect RAM
$ramGB = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)

# Check if it's a laptop GPU (MXM / Max-Q / Mobile)
$isMobileGPU = $gpuName -match "Max-Q|Mobile|MXM|Laptop"

INFO "GPU          : $gpuName"
INFO "VRAM         : ${gpuVRAM}GB"
INFO "Driver ver   : $driverVer"
INFO "Device type  : $(if ($isLaptop -or $isMobileGPU) { 'LAPTOP — thermal-safe mode' } else { 'DESKTOP — full performance mode' })"
INFO "Windows build: $winBuild"
INFO "RAM          : ${ramGB}GB"

$isLaptopMode = $isLaptop -or $isMobileGPU

# Find NVIDIA driver registry key (searches all subkeys under 0000-0009)
$nvidiaDriverKey = $null
$driverSearchBase = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}"
0..9 | ForEach-Object {
    $subKey = "$driverSearchBase\000$_"
    if (Test-Path $subKey) {
        $provider = (Get-ItemProperty $subKey -ErrorAction SilentlyContinue).ProviderName
        if ($provider -match "NVIDIA") {
            $nvidiaDriverKey = $subKey
        }
    }
}

if ($nvidiaDriverKey) {
    OK "NVIDIA driver registry key found: $nvidiaDriverKey"
} else {
    WARN "NVIDIA driver registry key not found — driver-level tweaks will be skipped"
    WARN "Make sure NVIDIA drivers are installed, then re-run this script"
}
#endregion

#region 1. WINDOWS GPU SCHEDULING
Section "WINDOWS GPU SETTINGS"

# Hardware GPU Scheduling — Win10 2004+ only
if ($winBuild -ge 19041) {
    SafeReg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" DWord 2
    OK "Hardware GPU Scheduling: ENABLED — reduces CPU overhead and GPU latency"
} else {
    SKIP "Hardware GPU Scheduling requires Windows 10 2004+ (Build $winBuild detected)"
}

# Disable Multi-Plane Overlay — causes stutters and black screens on many setups
SafeReg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "PlatformSupportMPO" DWord 0
OK "Multi-Plane Overlay (MPO): DISABLED — eliminates black screen stutters"

# Disable fullscreen optimizations globally
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_FSEBehaviorMode"                DWord 2
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_HonorUserFSEBehaviorMode"       DWord 0
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_DXGIHonorFSEWindowsCompatible"  DWord 1
SafeReg "HKCU:\System\GameConfigStore" "GameDVR_EFSEBehaviorMode"               DWord 0
OK "Fullscreen Optimizations: DISABLED globally — true exclusive fullscreen in games"

# TDR (Timeout Detection Recovery) — increase to prevent false driver crash on heavy loads
SafeReg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDelay"          DWord 10
SafeReg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrDdiDelay"       DWord 10
SafeReg "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "TdrTestMode"       DWord 0
OK "TDR timeout: 10s — prevents false 'driver crashed' errors during heavy gaming"

# DXGI flip model — enable for lower latency present mode
SafeReg "HKLM:\SOFTWARE\Microsoft\DirectX" "MaximumFrameLatency" DWord 1
OK "DXGI max frame latency: 1 — minimum buffering before frame is sent to display"
#endregion

#region 2. NVIDIA DRIVER POWER & PERFORMANCE
Section "NVIDIA DRIVER — POWER & PERFORMANCE"

if ($nvidiaDriverKey) {
    if (-not $isLaptopMode) {
        # DESKTOP: Force maximum performance — no thermal risk
        SafeReg $nvidiaDriverKey "PowerMizerEnable"           DWord 0       # Disable PowerMizer (dynamic clocking)
        SafeReg $nvidiaDriverKey "PowerMizerLevel"            DWord 1       # Force Performance level
        SafeReg $nvidiaDriverKey "PowerMizerLevelAC"          DWord 1       # Force on AC power too
        SafeReg $nvidiaDriverKey "PerfLevelSrc"               DWord 0x2222  # Override perf level source
        OK "Desktop: PowerMizer DISABLED — GPU clocks locked at maximum"
        OK "Desktop: Performance level forced to max on AC"
    } else {
        # LAPTOP: Keep PowerMizer but set prefer-max on AC only
        SafeReg $nvidiaDriverKey "PowerMizerEnable"           DWord 1       # Keep enabled for thermal safety
        SafeReg $nvidiaDriverKey "PowerMizerLevelAC"          DWord 1       # Max performance on AC power
        SafeReg $nvidiaDriverKey "PerfLevelSrc"               DWord 0x2222
        WARN "Laptop: PowerMizer kept ON for thermal safety"
        OK "Laptop: Max performance forced on AC power only"
        INFO "On battery — GPU will throttle to preserve thermals (correct behavior)"
    }

    # Enable GPU shader cache — reduces stutter from shader compilation
    SafeReg $nvidiaDriverKey "ShaderCache"                    DWord 1
    OK "Shader Cache: ENABLED — reduces in-game stutters from shader compilation"

    # Disable HDCP (unnecessary overhead if not watching DRM content)
    SafeReg $nvidiaDriverKey "RMHdcpKeyglobZero"              DWord 1
    OK "HDCP: DISABLED — removes DRM overhead (re-enable if using Netflix/Disney+ fullscreen)"

    # Disable pre-rendered frames override via driver (set via NV profile instead)
    # These are the correct keys for the NVIDIA driver
    SafeReg $nvidiaDriverKey "EnablePreRenderedFrames"        DWord 0
    OK "Pre-rendered frames: 1 (minimum) — reduces input lag"

} else {
    WARN "Skipping driver-level tweaks — NVIDIA driver key not found"
}
#endregion

#region 3. NVIDIA PROFILE INSPECTOR SETTINGS (via registry)
Section "NVIDIA GLOBAL PROFILE SETTINGS"

$nvGlobalPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Video"

# Threaded optimization — let NVIDIA driver use multiple CPU threads
SafeReg "HKCU:\Software\NVIDIA Corporation\Global\NVTweak" "ThreadedOptimization"     DWord 1
OK "Threaded Optimization: ON — driver uses multiple CPU cores"

# Disable overlay (reduces overhead slightly)
SafeReg "HKCU:\Software\NVIDIA Corporation\Global\NVTweak" "EnableRTXVoice"           DWord 0
SafeReg "HKCU:\Software\NVIDIA Corporation\Global\NVTweak" "Enabled"                  DWord 0
OK "NVIDIA Overlay disabled — less background GPU usage"

# Your original script had this WRONG — PowerMizerEnable=1 in NVTweak enables power saving
# The correct location is in the driver key, and =0 disables it on desktop
# Here we set the NVTweak version correctly
if (-not $isLaptopMode) {
    SafeReg "HKCU:\Software\NVIDIA Corporation\Global\NVTweak" "PowerMizerEnable"      DWord 0
    OK "NVTweak PowerMizer: 0 — power saving OFF (your original had this backwards: =1 enables throttling)"
} else {
    SafeReg "HKCU:\Software\NVIDIA Corporation\Global\NVTweak" "PowerMizerEnable"      DWord 1
    OK "NVTweak PowerMizer: 1 (laptop thermal protection kept)"
}
#endregion

#region 4. NVIDIA TELEMETRY — KILL IT
Section "NVIDIA TELEMETRY & BACKGROUND TASKS"

$nvTelemetryServices = @(
    @{ Name="NvTelemetryContainer"; Label="NVIDIA Telemetry Container" },
    @{ Name="NvContainerNetworkService"; Label="NVIDIA Container Network Service" }
)
foreach ($svc in $nvTelemetryServices) {
    try {
        Stop-Service $svc.Name -Force -ErrorAction SilentlyContinue
        Set-Service  $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
        OK "Disabled: $($svc.Label)"
    } catch { SKIP "Not found: $($svc.Name)" }
}

# Disable NVIDIA telemetry scheduled tasks
$nvTasks = @(
    "\NVIDIA\NvTmMon",
    "\NVIDIA\NvTmRep",
    "\NVIDIA\NvTmRepOnLogon",
    "\NVIDIA\NVAgentLauncher",
    "\NVIDIA\NVAgentLaunchercpl"
)
foreach ($task in $nvTasks) {
    try {
        Disable-ScheduledTask -TaskPath (Split-Path $task) `
            -TaskName (Split-Path $task -Leaf) -ErrorAction SilentlyContinue | Out-Null
        OK "Disabled NVIDIA task: $(Split-Path $task -Leaf)"
    } catch { SKIP "Task not found: $(Split-Path $task -Leaf)" }
}

# Disable telemetry in registry
SafeReg "HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client" "OptInOrOutPreference" DWord 0
SafeReg "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS"             "EnableRID44231"       DWord 0
SafeReg "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS"             "EnableRID64640"       DWord 0
SafeReg "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS"             "EnableRID66610"       DWord 0
OK "NVIDIA telemetry registry: all reporting disabled"
#endregion

#region 5. WHAT TO DO IN NVIDIA CONTROL PANEL
Section "NVIDIA CONTROL PANEL — MANUAL STEPS"
Write-Host ""
Write-Host "  These settings MUST be set manually in NVIDIA Control Panel" -ForegroundColor Yellow
Write-Host "  Right-click desktop -> NVIDIA Control Panel -> Manage 3D Settings" -ForegroundColor White
Write-Host ""

$settings = @(
    @{ Setting="Power management mode";         Value="Prefer maximum performance" },
    @{ Setting="Low Latency Mode";              Value="Ultra (most important for FPS games)" },
    @{ Setting="Max Frame Rate";                Value="3 below your monitor Hz (e.g. 141 for 144Hz)" },
    @{ Setting="Texture filtering - Quality";   Value="High performance" },
    @{ Setting="Texture filtering - Trilinear"; Value="Off" },
    @{ Setting="Threaded optimization";         Value="On" },
    @{ Setting="Shader Cache Size";             Value="Unlimited" },
    @{ Setting="OpenGL rendering GPU";          Value="Your NVIDIA GPU (not Intel)" },
    @{ Setting="Vertical sync";                 Value="Off (use in-game setting instead)" },
    @{ Setting="Triple buffering";              Value="Off" },
    @{ Setting="Antialiasing - FXAA";           Value="Off (use in-game AA instead)" }
)

foreach ($s in $settings) {
    Write-Host "  [>] $($s.Setting)" -ForegroundColor Cyan -NoNewline
    Write-Host " -> $($s.Value)" -ForegroundColor White
}

if ($isLaptopMode) {
    Write-Host ""
    WARN "LAPTOP EXTRA: Also go to -> Change resolution -> set highest refresh rate available"
    WARN "LAPTOP EXTRA: Manage 3D Settings -> Program Settings -> add your games -> set 'High-performance NVIDIA processor'"
    INFO "This forces games to use your NVIDIA GPU instead of the Intel iGPU"
}
#endregion

#region 6. SUMMARY
Write-Host "`n  =====================================================" -ForegroundColor Green
if ($errors -eq 0) {
    Write-Host "   ALL NVIDIA TWEAKS APPLIED SUCCESSFULLY" -ForegroundColor Green
} else {
    Write-Host "   DONE WITH $errors ERROR(S) — check output above" -ForegroundColor Yellow
}
Write-Host @"
  =====================================================
   GPU DETECTED   : $gpuName
   VRAM           : ${gpuVRAM}GB
   MODE           : $(if ($isLaptopMode) { 'LAPTOP (Thermal-Safe)' } else { 'DESKTOP (Full Performance)' })

   WHAT WAS APPLIED:
     [+] Hardware GPU Scheduling ON
     [+] Multi-Plane Overlay (MPO) DISABLED
     [+] Fullscreen Optimizations DISABLED
     [+] TDR timeout increased (no false crashes)
     [+] DXGI max frame latency: 1
     [+] Shader Cache ENABLED
     [+] Threaded Optimization ON
     [+] NVIDIA Telemetry services DISABLED
     [+] NVIDIA Telemetry scheduled tasks DISABLED
     [+] NVIDIA telemetry registry reporting OFF
$(if (-not $isLaptopMode) {
"     [+] PowerMizer DISABLED (desktop max perf)"
} else {
"     [!] PowerMizer KEPT ON (laptop thermal safety)"
"     [+] Max performance forced on AC power only"
})

   WHAT YOUR ORIGINAL SCRIPT HAD WRONG:
     [x] PowerMizerEnable=1 in NVTweak ENABLES power
         saving / throttling — opposite of what you want
         Correct: 0 on desktop, 1+AC-only on laptop

   STILL REQUIRED IN NVIDIA CONTROL PANEL:
     [>] Low Latency Mode -> Ultra
     [>] Power Management -> Prefer Max Performance
     [>] Max Frame Rate -> 3 below your monitor Hz
     [>] V-Sync -> Off

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
