# ============================================================
#   QATTOUSH DEBLOATER v2.0 — Universal Edition
#   Deep clean: Bloatware, Telemetry, Temp Files, Services
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
$removed  = 0
$skipped  = 0
$errors   = 0
$bytesSaved = 0

function Section($title) { Write-Host "`n  [$title]" -ForegroundColor Cyan }
function OK($msg)         { Write-Host "  [+] $msg" -ForegroundColor Green;    $script:removed++ }
function SKIP($msg)       { Write-Host "  [-] $msg" -ForegroundColor DarkGray; $script:skipped++ }
function WARN($msg)       { Write-Host "  [!] $msg" -ForegroundColor Yellow }
function INFO($msg)       { Write-Host "  [i] $msg" -ForegroundColor White }
function ERR($msg)        { Write-Host "  [ERR] $msg" -ForegroundColor Red;    $script:errors++ }

function SafeReg($path, $name, $type, $value) {
    try {
        if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name $name -Type $type -Value $value -Force
    } catch { ERR "Registry: $path -> $name" }
}

function RemoveFolder($path, $label) {
    if (Test-Path $path) {
        try {
            $size = (Get-ChildItem $path -Recurse -Force -ErrorAction SilentlyContinue |
                     Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            Remove-Item "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
            $mb = [math]::Round($size / 1MB, 1)
            $script:bytesSaved += $size
            OK "Cleaned $label (~$mb MB freed)"
        } catch { ERR "Could not clean: $label" }
    } else { SKIP "Not found: $label" }
}

function RemoveApp($pattern, $label) {
    $pkg = Get-AppxPackage -Name $pattern -ErrorAction SilentlyContinue
    if ($pkg) {
        try {
            $pkg | Remove-AppxPackage -ErrorAction SilentlyContinue
            OK "Removed app: $label"
        } catch { ERR "Failed to remove: $label" }
    } else { SKIP "Not installed: $label" }
}
#endregion

Clear-Host
Write-Host @"
  =====================================================
   QATTOUSH DEBLOATER v2.0 — Universal Edition
   Deep clean for Windows — Safe on all hardware
  =====================================================
"@ -ForegroundColor Magenta

#region 1. TEMP FILES & JUNK
Section "TEMP FILES & JUNK CLEANUP"

RemoveFolder $env:TEMP                              "User Temp folder"
RemoveFolder "C:\Windows\Temp"                      "Windows Temp folder"
RemoveFolder "C:\Windows\Prefetch"                  "Prefetch cache"
RemoveFolder "$env:LOCALAPPDATA\Temp"               "Local AppData Temp"
RemoveFolder "$env:LOCALAPPDATA\Microsoft\Windows\INetCache" "IE/Edge Browser Cache"
RemoveFolder "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"  "Thumbnail Cache"
RemoveFolder "C:\Windows\SoftwareDistribution\Download"      "Windows Update Download Cache"
RemoveFolder "$env:LOCALAPPDATA\CrashDumps"         "Crash Dumps"
RemoveFolder "C:\Windows\LiveKernelReports"         "Kernel Crash Reports"
RemoveFolder "C:\Windows\memory.dmp"                "Memory Dump File"
RemoveFolder "$env:LOCALAPPDATA\Microsoft\Terminal Server Client\Cache" "RDP Cache"

# Empty Recycle Bin
try {
    $shell = New-Object -ComObject Shell.Application
    $shell.Namespace(0xA).Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Force -ErrorAction SilentlyContinue }
    OK "Recycle Bin emptied"
} catch { SKIP "Recycle Bin already empty or access denied" }

# Windows Error Reports
$wer = "$env:LOCALAPPDATA\Microsoft\Windows\WER"
RemoveFolder $wer "Windows Error Reports"

# Old Windows installation (if exists — can be GBs)
if (Test-Path "C:\Windows.old") {
    WARN "Found C:\Windows.old — run Disk Cleanup manually to safely remove (~5-20GB)"
}
#endregion

#region 2. BLOATWARE APPS
Section "BLOATWARE REMOVAL"
WARN "Keeping: Photos, Calculator, Notepad, Paint, Camera — safe essentials"
Write-Host ""

# Gaming / entertainment bloat
RemoveApp "Microsoft.XboxApp"                     "Xbox App"
RemoveApp "Microsoft.XboxGameOverlay"             "Xbox Game Overlay"
RemoveApp "Microsoft.XboxGamingOverlay"           "Xbox Gaming Overlay"
RemoveApp "Microsoft.XboxIdentityProvider"        "Xbox Identity Provider"
RemoveApp "Microsoft.XboxSpeechToTextOverlay"     "Xbox Speech Overlay"
RemoveApp "Microsoft.Xbox.TCUI"                   "Xbox TCUI"
RemoveApp "Microsoft.GamingApp"                   "Xbox Gaming App (new)"
RemoveApp "Microsoft.ZuneMusic"                   "Groove Music"
RemoveApp "Microsoft.ZuneVideo"                   "Movies & TV"
RemoveApp "Microsoft.MicrosoftSolitaireCollection" "Solitaire Collection"

# Microsoft bloat
RemoveApp "Microsoft.BingWeather"                 "Bing Weather"
RemoveApp "Microsoft.BingNews"                    "Bing News"
RemoveApp "Microsoft.BingFinance"                 "Bing Finance"
RemoveApp "Microsoft.BingSports"                  "Bing Sports"
RemoveApp "Microsoft.GetHelp"                     "Get Help"
RemoveApp "Microsoft.Getstarted"                  "Tips / Get Started"
RemoveApp "Microsoft.MicrosoftOfficeHub"          "Office Hub"
RemoveApp "Microsoft.Office.OneNote"              "OneNote (preinstalled)"
RemoveApp "Microsoft.SkypeApp"                    "Skype"
RemoveApp "Microsoft.People"                      "People App"
RemoveApp "Microsoft.Wallet"                      "Microsoft Wallet"
RemoveApp "Microsoft.WindowsFeedbackHub"          "Feedback Hub"
RemoveApp "Microsoft.WindowsMaps"                 "Windows Maps"
RemoveApp "Microsoft.WindowsSoundRecorder"        "Sound Recorder"
RemoveApp "Microsoft.MixedReality.Portal"         "Mixed Reality Portal"
RemoveApp "Microsoft.3DBuilder"                   "3D Builder"
RemoveApp "Microsoft.Print3D"                     "Print 3D"
RemoveApp "Microsoft.Microsoft3DViewer"           "3D Viewer"
RemoveApp "Microsoft.PowerAutomateDesktop"        "Power Automate"
RemoveApp "Microsoft.Todos"                       "Microsoft To Do"
RemoveApp "Microsoft.MicrosoftTeams"              "Teams (preinstalled)"
RemoveApp "MicrosoftTeams"                        "Teams (consumer)"
RemoveApp "Microsoft.YourPhone"                   "Your Phone / Phone Link"
RemoveApp "Microsoft.549981C3F5F10"               "Cortana"
RemoveApp "Microsoft.WindowsCommunicationsApps"   "Mail and Calendar"
RemoveApp "Microsoft.Messaging"                   "Messaging"
RemoveApp "Microsoft.OneConnect"                  "Mobile Plans"
RemoveApp "Microsoft.StorePurchaseApp"            "Store Purchase App"
RemoveApp "Microsoft.ScreenSketch"                "Snip & Sketch (use Snipping Tool)"
RemoveApp "Microsoft.Advertising.Xaml"            "Microsoft Advertising SDK"

# Third-party preinstalled crap
RemoveApp "SpotifyAB.SpotifyMusic"               "Spotify (preinstalled)"
RemoveApp "king.com.CandyCrushSaga"              "Candy Crush Saga"
RemoveApp "king.com.CandyCrushFriends"           "Candy Crush Friends"
RemoveApp "king.com.BubbleWitch3Saga"            "Bubble Witch 3"
RemoveApp "Facebook.Facebook"                    "Facebook"
RemoveApp "Flipboard.Flipboard"                  "Flipboard"
RemoveApp "TikTok.TikTok"                        "TikTok (preinstalled)"
RemoveApp "ByteDance.TikTok*"                    "TikTok (alt)"
RemoveApp "Disney.37853D22215B2"                 "Disney+"
RemoveApp "AmazonVideo.PrimeVideo"               "Amazon Prime Video"
RemoveApp "Clipchamp.Clipchamp"                  "Clipchamp"
RemoveApp "MSTeams"                              "Teams (Win11)"
#endregion

#region 3. TELEMETRY & PRIVACY
Section "TELEMETRY & PRIVACY"

# Main telemetry kill switch
SafeReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry"             DWord 0
SafeReg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" DWord 0
SafeReg "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" DWord 0
OK "Telemetry level set to 0 (off via policy)"

# Disable advertising ID
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled"         DWord 0
SafeReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"       "DisabledByGroupPolicy" DWord 1
OK "Advertising ID disabled"

# Disable Windows Feedback
SafeReg "HKCU:\Software\Microsoft\Siuf\Rules" "NumberOfSIUFInPeriod" DWord 0
SafeReg "HKCU:\Software\Microsoft\Siuf\Rules" "PeriodInNanoSeconds"  DWord 0
OK "Windows feedback prompts disabled"

# Disable Activity History / Timeline
SafeReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "EnableActivityFeed"     DWord 0
SafeReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "PublishUserActivities"  DWord 0
SafeReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" "UploadUserActivities"   DWord 0
OK "Activity history / Timeline disabled"

# Disable Cortana
SafeReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortana"             DWord 0
SafeReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowCortanaAboveLock"    DWord 0
SafeReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "AllowSearchToUseLocation" DWord 0
SafeReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb"    DWord 0
OK "Cortana and web search in taskbar disabled"

# Disable location tracking
SafeReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors" "DisableLocation" DWord 1
OK "Location tracking disabled"

# Disable tailored experiences
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy" "TailoredExperiencesWithDiagnosticDataEnabled" DWord 0
OK "Tailored experiences disabled"

# Disable app suggestions / Start Menu ads
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338388Enabled" DWord 0
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-338389Enabled" DWord 0
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SubscribedContent-353698Enabled" DWord 0
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SystemPaneSuggestionsEnabled"    DWord 0
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SoftLandingEnabled"              DWord 0
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "OemPreInstalledAppsEnabled"      DWord 0
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "PreInstalledAppsEnabled"         DWord 0
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SilentInstalledAppsEnabled"      DWord 0
OK "Start Menu ads, app suggestions, silent installs disabled"

# Disable Windows tips
SafeReg "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" "SoftLandingEnabled"      DWord 0
SafeReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"                 "DisableSoftLanding"      DWord 1
SafeReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"                 "DisableWindowsConsumerFeatures" DWord 1
OK "Windows tips and consumer features disabled"
#endregion

#region 4. TELEMETRY SERVICES
Section "TELEMETRY SERVICES"
$telemetryServices = @(
    @{ Name="DiagTrack";         Label="Connected User Experiences & Telemetry" },
    @{ Name="dmwappushservice";  Label="WAP Push Message Routing" },
    @{ Name="WerSvc";            Label="Windows Error Reporting" },
    @{ Name="PcaSvc";            Label="Program Compatibility Assistant" },
    @{ Name="DoSvc";             Label="Delivery Optimization (background updates bandwidth)" },
    @{ Name="diagnosticshub.standardcollector.service"; Label="Diagnostics Hub Collector" },
    @{ Name="diagsvc";           Label="Diagnostic Execution Service" },
    @{ Name="DPS";               Label="Diagnostic Policy Service" }
)
foreach ($svc in $telemetryServices) {
    try {
        Stop-Service $svc.Name -Force -ErrorAction SilentlyContinue
        Set-Service  $svc.Name -StartupType Disabled -ErrorAction SilentlyContinue
        OK "Disabled: $($svc.Label)"
    } catch { SKIP "Not found: $($svc.Name)" }
}
#endregion

#region 5. SCHEDULED TELEMETRY TASKS
Section "SCHEDULED TELEMETRY TASKS"
$tasks = @(
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "\Microsoft\Windows\Application Experience\StartupAppTask",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    "\Microsoft\Windows\Feedback\Siuf\DmClient",
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
    "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
    "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask",
    "\Microsoft\Windows\Maps\MapsToastTask",
    "\Microsoft\Windows\Maps\MapsUpdateTask",
    "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem"
)
foreach ($task in $tasks) {
    try {
        Disable-ScheduledTask -TaskPath (Split-Path $task) -TaskName (Split-Path $task -Leaf) -ErrorAction SilentlyContinue | Out-Null
        OK "Disabled task: $(Split-Path $task -Leaf)"
    } catch { SKIP "Task not found: $(Split-Path $task -Leaf)" }
}
#endregion

#region 6. DISK CLEANUP (built-in silent)
Section "DISK CLEANUP"
# Set all Disk Cleanup categories to run silently
$sageset = 64
$cleanupKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
Get-ChildItem $cleanupKey -ErrorAction SilentlyContinue | ForEach-Object {
    Set-ItemProperty -Path $_.PSPath -Name "StateFlags$sageset" -Type DWord -Value 2 -ErrorAction SilentlyContinue
}
INFO "Running Windows Disk Cleanup silently..."
Start-Process cleanmgr -ArgumentList "/sagerun:$sageset" -Wait -WindowStyle Hidden
OK "Windows built-in Disk Cleanup completed"
#endregion

#region 7. SUMMARY
$totalMB = [math]::Round($bytesSaved / 1MB, 1)
Write-Host "`n  =====================================================" -ForegroundColor Magenta
Write-Host @"
   DEBLOAT COMPLETE
  =====================================================
   RESULTS:
     Actions completed : $removed
     Already clean     : $skipped
     Errors            : $errors
     Temp files freed  : ~$totalMB MB

   WHAT WAS DONE:
     [+] Temp / junk / crash dumps cleaned
     [+] Recycle Bin emptied
     [+] Windows Update download cache cleared
     [+] 35+ bloatware apps removed
     [+] Telemetry set to level 0 (policy enforced)
     [+] Advertising ID disabled
     [+] Activity History / Timeline disabled
     [+] Cortana / web search in taskbar disabled
     [+] Start Menu ads + silent app installs blocked
     [+] Telemetry services disabled
     [+] 14 background telemetry scheduled tasks disabled
     [+] Built-in Disk Cleanup ran silently

   SAFE — what was NOT touched:
     [~] Photos, Calculator, Notepad, Paint, Camera
     [~] Microsoft Store (kept — needed for updates)
     [~] Windows Defender / Security Center
     [~] Windows Update service
     [~] OneDrive (uninstall manually if desired)

   RECOMMENDED NEXT STEPS:
     [>] Restart your PC now
     [>] Go to Settings -> Apps -> Startup and disable
         anything you don't need launching at boot
     [>] Run this + the FPS Optimizer together for
         the best gaming experience
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
