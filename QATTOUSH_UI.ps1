# ================================================================
#  QATTOUSH TOOLKIT UI v4.0
#  Run via QATTOUSH_TOOLKIT.bat (handles admin)
# ================================================================
param()

$Host.UI.RawUI.WindowTitle = "QATTOUSH TOOLKIT v4.0"

# ── Colors ───────────────────────────────────────────────────────
$E   = [char]27
$PU  = "$E[38;2;180;0;255m"
$LP  = "$E[38;2;210;120;255m"
$CY  = "$E[96m"
$WH  = "$E[97m"
$GR  = "$E[92m"
$YE  = "$E[93m"
$RE  = "$E[91m"
$DG  = "$E[90m"
$BD  = "$E[1m"
$RS  = "$E[0m"

$BASE = "https://raw.githubusercontent.com/Qattoush/qattoush-toolkit/main"

# ── System info ───────────────────────────────────────────────────
$script:GPU   = try { (Get-WmiObject Win32_VideoController | Where-Object {$_.AdapterRAM -gt 0} | Select-Object -First 1).Name.Trim() } catch { "Unknown" }
$script:CPU   = try { $n = (Get-WmiObject Win32_Processor | Select-Object -First 1).Name.Trim(); ($n -replace '\(R\)|\(TM\)|CPU |@ [\d.]+GHz', '' -replace '\s+', ' ').Trim() } catch { "Unknown" }
$script:RAM   = try { "$([math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 0)) GB" } catch { "?" }
$script:CORES = try { $p = Get-WmiObject Win32_Processor | Select-Object -First 1; "$($p.NumberOfCores)C / $($p.NumberOfLogicalProcessors)T" } catch { "" }
$script:hasNV = $script:GPU -match "NVIDIA|GeForce|GTX|RTX"
$script:hasAM = $script:GPU -match "AMD|Radeon|RX "
$script:kills = 0
$script:BW    = 70
$script:BP    = "  "

# ── Helpers ───────────────────────────────────────────────────────
function Strip([string]$s) { $s -replace '\x1b\[[0-9;]*m', '' }
function GW   { $Host.UI.RawUI.WindowSize.Width }
function GH   { $Host.UI.RawUI.WindowSize.Height }
function WK   { $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") }

function CW([string]$col) {
    $w = GW; $r = Strip $col
    $p = [math]::Max(0, [math]::Floor(($w - $r.Length) / 2))
    Write-Host (' ' * $p + $col)
}

function HR([string]$ch = '─', [string]$c = $DG) {
    $w = GW
    Write-Host "  ${c}$($ch * [math]::Max(0, $w - 4))${RS}"
}

function SetBox {
    $w = GW
    $script:BW = [math]::Max(28, [math]::Min($w - 8, 82))
    $script:BP = ' ' * [math]::Max(0, [math]::Floor(($w - $script:BW - 2) / 2))
}

function BTop([string]$c = $PU) { Write-Host "$($script:BP)${c}${BD}╔$('═' * $script:BW)╗${RS}" }
function BBot([string]$c = $PU) { Write-Host "$($script:BP)${c}${BD}╚$('═' * $script:BW)╝${RS}" }
function BDiv([string]$c = $PU) { Write-Host "$($script:BP)${c}${BD}╠$('═' * $script:BW)╣${RS}" }
function BE                     { Write-Host "$($script:BP)${DG}║${RS}$(' ' * $script:BW)${DG}║${RS}" }

function BS([string]$t, [string]$c = $LP) {
    $inner = "  ${c}${BD}${t}${RS}"
    $sp = [math]::Max(0, $script:BW - (Strip $inner).Length)
    Write-Host "$($script:BP)${DG}║${RS}${inner}$(' ' * $sp)${DG}║${RS}"
}

function BL([string]$l, [string]$r = '') {
    $vl = (Strip $l).Length; $vr = (Strip $r).Length
    $sp = [math]::Max(0, $script:BW - $vl - $vr)
    Write-Host "$($script:BP)${DG}║${RS}${l}$(' ' * $sp)${r}${DG}║${RS}"
}

# ── Animated loading bar ──────────────────────────────────────────
function Show-LoadBar([string]$label, [int]$ms = 500) {
    $w = GW
    $bw = [math]::Min($w - 24, 36)
    $bp = ' ' * [math]::Max(2, [math]::Floor(($w - $bw - $label.Length - 8) / 2))
    $steps = 20
    $delay = [math]::Max(1, [math]::Round($ms / $steps))
    for ($i = 1; $i -le $steps; $i++) {
        $fill = [math]::Round($bw * $i / $steps)
        $bar  = "${GR}$('█' * $fill)${DG}$('░' * ($bw - $fill))${RS}"
        $pct  = ([math]::Round(100 * $i / $steps)).ToString().PadLeft(3)
        Write-Host -NoNewline "`r  ${bp}${DG}[${RS}${bar}${DG}]${RS} ${WH}${pct}%%${RS}  ${DG}${label}${RS}   "
        Start-Sleep -Milliseconds $delay
    }
    Write-Host ""
}

# ── Kill feed ─────────────────────────────────────────────────────
function Show-KillFeed {
    $script:kills++
    $msg  = " X  MR RAED HAS BEEN ELIMINATED BY QATTOUSH  X "
    $bdr  = "╔$('═' * $msg.Length)╗"
    $mid  = "║${msg}║"
    $bot  = "╚$('═' * $msg.Length)╝"
    $streak = switch ($script:kills) {
        1       { "First blood!" }
        2       { "Double kill!" }
        3       { "TRIPLE KILL!" }
        default { "UNSTOPPABLE!" }
    }
    Write-Host ""
    for ($i = 0; $i -lt 3; $i++) {
        CW "${RE}${BD}${bdr}${RS}"; CW "${RE}${BD}${mid}${RS}"; CW "${RE}${BD}${bot}${RS}"
        Start-Sleep -Milliseconds 220
        if ($i -lt 2) {
            Write-Host "$([char]27)[3A" -NoNewline
            CW "${DG}${bdr}${RS}"; CW "${DG}${mid}${RS}"; CW "${DG}${bot}${RS}"
            Start-Sleep -Milliseconds 160
            Write-Host "$([char]27)[3A" -NoNewline
        }
    }
    Write-Host ""
    CW "${DG}Kill #$($script:kills)  •  ${YE}${BD}${streak}${RS}"
    Write-Host ""
    Start-Sleep -Milliseconds 1800
}

# ── Title art ─────────────────────────────────────────────────────
function Show-Title {
    $w = GW; Write-Host ""
    if ($w -ge 86) {
        CW "${PU}${BD} ██████╗  █████╗ ████████╗████████╗ ██████╗ ██╗   ██╗███████╗██╗  ██╗${RS}"
        CW "${PU}${BD}██╔═══██╗██╔══██╗╚══██╔══╝╚══██╔══╝██╔═══██╗██║   ██║██╔════╝██║  ██║${RS}"
        CW "${PU}${BD}██║   ██║███████║   ██║      ██║   ██║   ██║██║   ██║███████╗███████║ ${RS}"
        CW "${PU}${BD}██║▄▄ ██║██╔══██║   ██║      ██║   ██║   ██║██║   ██║╚════██║██╔══██║${RS}"
        CW "${PU}${BD}╚██████╔╝██║  ██║   ██║      ██║   ╚██████╔╝╚██████╔╝███████║██║  ██║${RS}"
        CW "${PU}${BD} ╚══▀▀═╝ ╚═╝  ╚═╝   ╚═╝      ╚═╝    ╚═════╝  ╚═════╝ ╚══════╝╚═╝  ╚═╝${RS}"
    } elseif ($w -ge 58) {
        CW "${PU}${BD}  ___  _   _____  _____  ___   _   _  ___  _  _ ${RS}"
        CW "${PU}${BD} / _ \/_\ |_   _||_   _|/ _ \ | | | |/ __|| || |${RS}"
        CW "${PU}${BD}| (_)/ _ \ | |    | | | (_) || |_| |\__ \| __ |${RS}"
        CW "${PU}${BD} \__//_/ \_\|_|    |_|  \___/  \___/ |___/|_||_|${RS}"
    } elseif ($w -ge 28) {
        CW "${PU}${BD}╔═══════════════════════╗${RS}"
        CW "${PU}${BD}║    Q A T T O U S H    ║${RS}"
        CW "${PU}${BD}╚═══════════════════════╝${RS}"
    } else {
        CW "${PU}${BD}QATTOUSH${RS}"
    }
    Write-Host ""
}

# ── Main menu ─────────────────────────────────────────────────────
function Show-Menu {
    SetBox
    $w    = GW
    $wide = $script:BW -ge 62

    Clear-Host
    Show-Title
    HR '─'
    CW "${LP}${BD}GAMING PERFORMANCE TOOLKIT  •  v4.0${RS}"
    HR '─'
    Write-Host ""

    $nvBadge = if ($script:hasNV) { "${GR}${BD}[YOUR GPU]${RS}" } else { "${DG}[N/A]     ${RS}" }
    $amBadge = if ($script:hasAM) { "${GR}${BD}[YOUR GPU]${RS}" } else { "${DG}[N/A]     ${RS}" }
    $gpuD    = $script:GPU
    if ($gpuD.Length -gt ($w - 46)) { $gpuD = $gpuD.Substring(0, [math]::Max(8, $w - 46)) + "..." }

    CW "${DG}CPU ${WH}$($script:CPU) ${DG}($($script:CORES))   RAM ${WH}$($script:RAM)   GPU ${WH}${gpuD}${RS}"
    Write-Host ""

    BTop
    BE
    BS "  PERFORMANCE" $CY
    BE
    if ($wide) {
        BL "    ${CY}${BD}[ 1 ]${RS}  ${WH}FPS Boost           ${RS}" "${DG}CPU/GPU priority + power tweaks    ${RS}"
        BL "    ${CY}${BD}[ 2 ]${RS}  ${WH}Debloat Windows     ${RS}" "${DG}Remove bloat + kill telemetry      ${RS}"
        BL "    ${CY}${BD}[ 3 ]${RS}  ${WH}Network Optimizer   ${RS}" "${DG}Low ping + Nagle off + DNS tuning  ${RS}"
    } else {
        BL "    ${CY}${BD}[ 1 ]${RS}  ${WH}FPS Boost${RS}"
        BL "    ${CY}${BD}[ 2 ]${RS}  ${WH}Debloat Windows${RS}"
        BL "    ${CY}${BD}[ 3 ]${RS}  ${WH}Network Optimizer${RS}"
    }
    BE
    BDiv
    BE
    BS "  GPU SPECIFIC" $PU
    BE
    if ($wide) {
        BL "    ${PU}${BD}[ 4 ]${RS}  ${WH}NVIDIA Optimizer    ${RS}" "${DG}Driver + latency tweaks        ${nvBadge}${RS}"
        BL "    ${PU}${BD}[ 5 ]${RS}  ${WH}AMD Optimizer       ${RS}" "${DG}Driver + Adrenalin guide       ${amBadge}${RS}"
    } else {
        BL "    ${PU}${BD}[ 4 ]${RS}  ${WH}NVIDIA Optimizer    ${RS}" $nvBadge
        BL "    ${PU}${BD}[ 5 ]${RS}  ${WH}AMD Optimizer       ${RS}" $amBadge
    }
    BE
    BDiv
    BE
    BS "  TOOLS" $YE
    BE
    if ($wide) {
        BL "    ${GR}${BD}[ 6 ]${RS}  ${WH}Run ALL (Auto)      ${RS}" "${DG}FPS + Network + GPU in one go      ${RS}"
        BL "    ${YE}${BD}[ 7 ]${RS}  ${WH}System Info         ${RS}" "${DG}Full hardware + driver report      ${RS}"
        BL "    ${RE}${BD}[ 8 ]${RS}  ${WH}Revert All          ${RS}" "${DG}Undo every change, restore defaults${RS}"
        BL "    ${DG}${BD}[ 9 ]${RS}  ${WH}Exit${RS}"
    } else {
        BL "    ${GR}${BD}[ 6 ]${RS}  ${WH}Run ALL (Auto)${RS}"
        BL "    ${YE}${BD}[ 7 ]${RS}  ${WH}System Info${RS}"
        BL "    ${RE}${BD}[ 8 ]${RS}  ${WH}Revert All${RS}"
        BL "    ${DG}${BD}[ 9 ]${RS}  ${WH}Exit${RS}"
    }
    BE
    BBot
    Write-Host ""
    HR '─'
    if ($script:kills -gt 0) {
        CW "${RE}${BD}☠  QATTOUSH eliminated MR RAED $($script:kills) time$(if($script:kills -ne 1){'s'}) this session  ☠${RS}"
    }
    Write-Host ""
}

# ── Run header ────────────────────────────────────────────────────
function Show-RunHeader([string]$label, [string]$c = $PU) {
    Clear-Host; Write-Host ""; Show-Title
    $inner = "  $label  "
    $w     = GW
    $pad   = ' ' * [math]::Max(0, [math]::Floor(($w - $inner.Length - 2) / 2))
    Write-Host "${pad}${c}${BD}╔$('═' * $inner.Length)╗${RS}"
    Write-Host "${pad}${c}${BD}║${WH}${inner}${c}${BD}║${RS}"
    Write-Host "${pad}${c}${BD}╚$('═' * $inner.Length)╝${RS}"
    Write-Host ""
}

# ── Script runner ─────────────────────────────────────────────────
function Run-Script([string]$file, [string]$label, [bool]$confirm = $false, [string]$color = $CY) {
    Show-RunHeader $label $color
    if ($confirm) {
        Write-Host "  ${YE}[!] ${WH}This will make significant system changes.${RS}"
        Write-Host "  ${DG}Continue? ${WH}(Y/N): ${RS}" -NoNewline
        if ((Read-Host) -notmatch '^[Yy]') {
            Write-Host "  ${DG}Cancelled.${RS}"
            Start-Sleep -Milliseconds 700
            return
        }
        Write-Host ""
    }
    Show-LoadBar "Downloading $file..." 400
    try {
        Write-Host ""
        Invoke-Expression (Invoke-RestMethod "$BASE/$file")
    } catch {
        Write-Host "  ${RE}[ERR] ${RS}$_"
        Write-Host "  ${YE}[!] Check your internet or update the BASE URL in QATTOUSH_UI.ps1${RS}"
        Write-Host "  ${DG}Press any key to return...${RS}"
        WK
        return
    }
    Write-Host ""
    Show-KillFeed
}

function No-GPU([string]$brand) {
    Write-Host ""
    Write-Host "  ${RE}╔══════════════════════════════════════╗${RS}"
    Write-Host "  ${RE}║  No ${brand} GPU found on this PC.   ║${RS}"
    Write-Host "  ${RE}╚══════════════════════════════════════╝${RS}"
    Write-Host "  ${DG}Press any key...${RS}"
    WK
}

# ── System info ───────────────────────────────────────────────────
function Show-SysInfo {
    Show-RunHeader "SYSTEM INFORMATION" $YE
    Show-LoadBar "Scanning hardware..." 500
    Write-Host ""
    $w   = GW
    $bw  = [math]::Min($w - 8, 68)
    $pad = ' ' * [math]::Max(2, [math]::Floor(($w - $bw) / 2))

    $items = @(
        @{ L = "OS";            V = try { (Get-WmiObject Win32_OperatingSystem).Caption + " " + ((Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion) } catch { "Unknown" } },
        @{ L = "Processor";     V = try { (Get-WmiObject Win32_Processor | Select-Object -First 1).Name.Trim() } catch { "Unknown" } },
        @{ L = "Cores/Threads"; V = try { $p = Get-WmiObject Win32_Processor | Select-Object -First 1; "$($p.NumberOfCores) cores / $($p.NumberOfLogicalProcessors) threads" } catch { "Unknown" } },
        @{ L = "RAM";           V = try { "$([math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)) GB" } catch { "Unknown" } },
        @{ L = "GPU";           V = $script:GPU },
        @{ L = "VRAM";          V = try { "$([math]::Round((Get-WmiObject Win32_VideoController | Where-Object { $_.AdapterRAM -gt 0 } | Select-Object -First 1).AdapterRAM / 1GB, 0)) GB" } catch { "Unknown" } },
        @{ L = "GPU Driver";    V = try { (Get-WmiObject Win32_VideoController | Where-Object { $_.AdapterRAM -gt 0 } | Select-Object -First 1).DriverVersion } catch { "Unknown" } },
        @{ L = "Primary Disk";  V = try { $d = Get-WmiObject Win32_DiskDrive | Select-Object -First 1; "$($d.Model.Trim()) — $([math]::Round($d.Size / 1GB, 0)) GB" } catch { "Unknown" } },
        @{ L = "Windows Build"; V = try { (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber } catch { "Unknown" } }
    )

    $lw = ($items | ForEach-Object { $_.L.Length } | Measure-Object -Maximum).Maximum
    Write-Host "${pad}${PU}${BD}╔$('═' * $bw)╗${RS}"
    foreach ($item in $items) {
        $row = "  ${DG}$($item.L.PadRight($lw))${RS}  ${WH}$($item.V)${RS}"
        $sp  = [math]::Max(0, $bw - (Strip $row).Length)
        Write-Host "${pad}${PU}${BD}║${RS}${row}$(' ' * $sp)${PU}${BD}║${RS}"
    }
    Write-Host "${pad}${PU}${BD}╚$('═' * $bw)╝${RS}"
    Write-Host ""
    Write-Host "  ${DG}Press any key to return...${RS}"
    WK
}

# ── Main loop ─────────────────────────────────────────────────────
try {
    while ($true) {
        Show-Menu
        $ch = (Read-Host "  ${LP}${BD}  Enter option [1-9]${RS}").Trim()
        switch ($ch) {
            "1" { Run-Script "fps.ps1"     "FPS BOOST"         $false $CY }
            "2" { Run-Script "debloat.ps1" "DEBLOAT WINDOWS"   $true  $YE }
            "3" { Run-Script "network.ps1" "NETWORK OPTIMIZER" $false $CY }
            "4" { if ($script:hasNV) { Run-Script "nvidia.ps1" "NVIDIA OPTIMIZER" $false $GR } else { No-GPU "NVIDIA" } }
            "5" { if ($script:hasAM) { Run-Script "amd.ps1"    "AMD OPTIMIZER"    $false $RE } else { No-GPU "AMD"    } }
            "6" {
                Run-Script "fps.ps1"     "FPS BOOST [1/3]"         $false $CY
                Run-Script "network.ps1" "NETWORK OPTIMIZER [2/3]" $false $CY
                if      ($script:hasNV) { Run-Script "nvidia.ps1" "NVIDIA OPTIMIZER [3/3]" $false $GR }
                elseif  ($script:hasAM) { Run-Script "amd.ps1"    "AMD OPTIMIZER [3/3]"    $false $RE }
                else { Write-Host "  ${YE}[!] GPU not recognized — skipping GPU step.${RS}"; Start-Sleep 2 }
            }
            "7" { Show-SysInfo }
            "8" { Run-Script "revert.ps1" "REVERT ALL" $true $RE }
            "9" {
                Clear-Host; Write-Host ""; Show-Title
                if ($script:kills -gt 0) {
                    CW "${RE}${BD}☠  MR RAED eliminated $($script:kills) time$(if($script:kills -ne 1){'s'}) today  ☠${RS}"
                    Write-Host ""
                }
                CW "${LP}Restart your PC for all changes to take full effect.${RS}"
                Write-Host ""; CW "${DG}Goodbye.${RS}"; Write-Host ""
                Start-Sleep -Milliseconds 1200
                exit 0
            }
            "" { }
            default {
                Write-Host "  ${RE}[!] '$ch' is not valid — use 1 through 9.${RS}"
                Start-Sleep -Milliseconds 900
            }
        }
    }
} catch {
    Write-Host ""
    Write-Host "  ${RE}╔═══════════════════════════════════════════╗${RS}"
    Write-Host "  ${RE}║  TOOLKIT CRASHED — error below            ║${RS}"
    Write-Host "  ${RE}╚═══════════════════════════════════════════╝${RS}"
    Write-Host ""
    Write-Host "  ${YE}$($_.ToString())${RS}"
    Write-Host ""
    Read-Host "  Press Enter to close"
}
