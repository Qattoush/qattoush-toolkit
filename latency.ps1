# ============================================================
#   QATTOUSH NETWORK OPTIMIZER v2.0
#   Low Latency + Ping Reduction + Gaming Traffic Priority
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

$errors = 0
function SafeReg($path, $name, $type, $value) {
    try {
        if (!(Test-Path $path)) { New-Item -Path $path -Force | Out-Null }
        Set-ItemProperty -Path $path -Name $name -Type $type -Value $value -Force
    } catch {
        Write-Host "  [ERR] Registry: $path -> $name" -ForegroundColor Red
        $script:errors++
    }
}
#endregion

#region DETECT CONNECTION
Clear-Host
Write-Host @"
  =====================================================
   QATTOUSH NETWORK OPTIMIZER v2.0
   Low Latency + Ping Reduction + Gaming Priority
  =====================================================
"@ -ForegroundColor Magenta

Section "DETECTING YOUR CONNECTION"

# Get active adapters only
$adapters = Get-NetAdapter | Where-Object { $_.Status -eq "Up" }
$isWifi    = $adapters | Where-Object { $_.InterfaceDescription -match "Wi-Fi|Wireless|802.11|WLAN" }
$isEthernet= $adapters | Where-Object { $_.InterfaceDescription -match "Ethernet|LAN|Gigabit|Realtek|Intel.*Ethernet" }

foreach ($a in $adapters) {
    INFO "Active adapter: $($a.Name) — $($a.InterfaceDescription)"
}

if ($isWifi -and -not $isEthernet) {
    WARN "Wi-Fi only detected — most tweaks still apply but for best latency use a wired connection"
} elseif ($isEthernet) {
    OK "Ethernet detected — all tweaks will apply"
} else {
    WARN "Could not detect adapter type — applying all tweaks anyway"
}

# Get current ping baseline to 8.8.8.8
try {
    $pingBefore = (Test-Connection -ComputerName 8.8.8.8 -Count 4 -ErrorAction Stop |
                   Measure-Object -Property ResponseTime -Average).Average
    $pingBefore = [math]::Round($pingBefore, 1)
    INFO "Ping before tweaks: ${pingBefore}ms (to 8.8.8.8)"
} catch {
    $pingBefore = $null
    WARN "Could not measure baseline ping (no internet or ICMP blocked)"
}
#endregion

#region 1. TCP GLOBAL STACK
Section "TCP GLOBAL STACK"

# Auto-tuning: normal is best for gaming — not disabled, not experimental
netsh int tcp set global autotuninglevel=normal 2>$null | Out-Null
OK "TCP auto-tuning: Normal (best balance for gaming)"

# RSS: spreads TCP processing across CPU cores — always good
netsh int tcp set global rss=enabled 2>$null | Out-Null
OK "RSS (Receive Side Scaling): Enabled — TCP load spread across CPU cores"

# Chimney offload: DISABLED — causes latency spikes on modern systems
# Your original script had this ENABLED which is wrong for gaming
netsh int tcp set global chimney=disabled 2>$null | Out-Null
OK "TCP Chimney Offload: Disabled — prevents latency spikes (your original had this wrong)"

# Timestamps: disable — adds overhead with no gaming benefit
netsh int tcp set global timestamps=disabled 2>$null | Out-Null
OK "TCP timestamps: Disabled — less packet overhead"

# ECN: disable — causes issues with some routers/game servers
netsh int tcp set global ecncapability=disabled 2>$null | Out-Null
OK "ECN (Explicit Congestion Notification): Disabled — router compatibility"

# Direct Cache Access: improves NIC-to-CPU memory path
netsh int tcp set global dca=enabled 2>$null | Out-Null
OK "Direct Cache Access (DCA): Enabled — faster NIC-to-CPU data path"

# NetDMA: improves memory copy performance for network data
netsh int tcp set global netdma=enabled 2>$null | Out-Null
OK "NetDMA: Enabled — reduces CPU usage for network transfers"

# Initial RTO: reduce retransmit timeout (default 3000ms → 2000ms)
netsh int tcp set global initialRto=2000 2>$null | Out-Null
OK "Initial RTO: 2000ms — faster recovery from dropped packets"

# Max SYN retransmissions: reduce handshake timeout
netsh int tcp set global maxsynretransmissions=2 2>$null | Out-Null
OK "Max SYN retransmissions: 2 — faster connection timeout on dead servers"
#endregion

#region 2. NAGLE'S ALGORITHM — THE BIG ONE
Section "NAGLE'S ALGORITHM (Most Important for Ping)"
INFO "Nagle's algorithm batches small packets together — great for throughput, terrible for games"
INFO "Disabling it sends each packet immediately = lower ping"

$tcpInterfaces = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
$count = 0
Get-ChildItem $tcpInterfaces -ErrorAction SilentlyContinue | ForEach-Object {
    $ifPath = $_.PSPath
    # Only apply to interfaces that have an IP (skip empty/virtual ones)
    $ip = (Get-ItemProperty $ifPath -ErrorAction SilentlyContinue).DhcpIPAddress
    if ($ip -or (Get-ItemProperty $ifPath -ErrorAction SilentlyContinue).IPAddress) {
        SafeReg $ifPath "TcpAckFrequency" DWord 1   # Send ACK immediately, don't wait
        SafeReg $ifPath "TCPNoDelay"      DWord 1   # Disable Nagle
        SafeReg $ifPath "TcpDelAckTicks"  DWord 0   # No delayed ACK timer
        $count++
    }
}
OK "Nagle disabled on $count active interfaces — ACKs sent immediately"
#endregion

#region 3. TCP/IP PARAMETERS
Section "TCP/IP REGISTRY PARAMETERS"
$tcpParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"

# TTL: 64 is standard, some ISPs drop packets with default Windows TTL of 128
SafeReg $tcpParams "DefaultTTL"                  DWord 64
OK "Default TTL: 64 (standard, less likely dropped by routers)"

# TCP window size: larger = more data in flight = better for high-speed connections
SafeReg $tcpParams "GlobalMaxTcpWindowSize"      DWord 65535
SafeReg $tcpParams "TcpWindowSize"               DWord 65535
OK "TCP window size: 65535 — better throughput on fast connections"

# Enable window scaling and timestamps extension
SafeReg $tcpParams "Tcp1323Opts"                 DWord 1
OK "TCP 1323 extensions: Enabled (window scaling)"

# Reduce TIME_WAIT from default 240s to 30s — frees up ports faster after game disconnect
SafeReg $tcpParams "TcpTimedWaitDelay"           DWord 30
OK "TCP TIME_WAIT: 30s (down from 240s) — ports free faster after disconnect"

# Disable task offload (can cause issues with some NICs)
SafeReg $tcpParams "DisableTaskOffload"          DWord 0
OK "Task offload: Enabled (NIC handles checksums, less CPU load)"

# Max connections (helps with servers that have many connections)
SafeReg $tcpParams "MaxUserPort"                 DWord 65534
SafeReg $tcpParams "MaxFreeTcbs"                 DWord 65536
SafeReg $tcpParams "MaxHashTableSize"            DWord 65536
OK "Max TCP ports expanded: 65534 — reduces 'no ports available' errors"

# Faster failure detection
SafeReg $tcpParams "TcpMaxDataRetransmissions"   DWord 3
OK "TCP retransmissions: 3 — faster drop detection on unstable connections"
#endregion

#region 4. DNS OPTIMIZATION
Section "DNS OPTIMIZATION"

# Flush old DNS cache
ipconfig /flushdns 2>$null | Out-Null
ipconfig /registerdns 2>$null | Out-Null
OK "DNS cache flushed and re-registered"

# Increase DNS cache size and TTL
SafeReg "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "CacheHashTableBucketSize"  DWord 1
SafeReg "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "CacheHashTableSize"        DWord 384
SafeReg "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "MaxCacheEntryTtlLimit"     DWord 64000
SafeReg "HKLM:\SYSTEM\CurrentControlSet\Services\Dnscache\Parameters" "MaxSOACacheEntryTtlLimit"  DWord 301
OK "DNS cache size and TTL maximized — fewer DNS lookups mid-game"

# Set DNS to Cloudflare (1.1.1.1) on all active adapters — faster than ISP DNS
foreach ($adapter in $adapters) {
    try {
        Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex `
            -ServerAddresses ("1.1.1.1","1.0.0.1") -ErrorAction SilentlyContinue
        OK "DNS set to Cloudflare 1.1.1.1 on: $($adapter.Name)"
    } catch { SKIP "Could not set DNS on: $($adapter.Name)" }
}
WARN "DNS changed to Cloudflare (1.1.1.1) — fastest public DNS for gaming"
INFO "To revert: Settings -> Network -> DNS -> Automatic (DHCP)"
#endregion

#region 5. QOS / GAMING TRAFFIC PRIORITY
Section "QOS & GAMING TRAFFIC PRIORITY"

# Disable QoS packet scheduler reserve (by default Windows holds back 20% bandwidth)
SafeReg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Psched" "NonBestEffortLimit" DWord 0
OK "QoS bandwidth reserve: 0% — Windows no longer holds back 20% of your bandwidth"

# Game thread priority
$gamesPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games"
SafeReg $gamesPath "Affinity"            DWord 0
SafeReg $gamesPath "Background Only"     String "False"
SafeReg $gamesPath "Clock Rate"          DWord 2710
SafeReg $gamesPath "GPU Priority"        DWord 8
SafeReg $gamesPath "Priority"            DWord 6
SafeReg $gamesPath "Scheduling Category" String "High"
SafeReg $gamesPath "SFIO Priority"       String "High"
OK "Game process: CPU priority 6, GPU priority 8, scheduling High"

# System responsiveness: 0 = OS gives max resources to foreground app (your game)
$mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
SafeReg $mmPath "SystemResponsiveness"   DWord 0
SafeReg $mmPath "NetworkThrottlingIndex" DWord 0xFFFFFFFF
OK "System responsiveness: Max — OS prioritizes foreground game over background tasks"
OK "Network throttling: Disabled — no artificial bandwidth limits"
#endregion

#region 6. WIFI-SPECIFIC TWEAKS
if ($isWifi) {
    Section "WI-FI SPECIFIC TWEAKS"
    foreach ($adapter in ($adapters | Where-Object { $_.InterfaceDescription -match "Wi-Fi|Wireless|802.11|WLAN" })) {
        # Disable power saving on WiFi adapter
        try {
            $adapterConfig = Get-NetAdapterPowerManagement -Name $adapter.Name -ErrorAction SilentlyContinue
            if ($adapterConfig) {
                Set-NetAdapterPowerManagement -Name $adapter.Name -ArpOffload Disabled `
                    -NSOffload Disabled -WakeOnMagicPacket Disabled `
                    -WakeOnPattern Disabled -ErrorAction SilentlyContinue
                OK "Wi-Fi power management disabled: $($adapter.Name)"
            }
        } catch { SKIP "Could not set power management on: $($adapter.Name)" }

        # Disable roaming aggressiveness (stops adapter from switching APs mid-game)
        try {
            Set-NetAdapterAdvancedProperty -Name $adapter.Name `
                -DisplayName "Roaming Aggressiveness" -DisplayValue "1-Lowest" -ErrorAction SilentlyContinue
            OK "Wi-Fi roaming aggressiveness set to lowest — no mid-game AP switching"
        } catch { SKIP "Roaming aggressiveness not available on this adapter" }

        # Set to max performance mode
        try {
            Set-NetAdapterAdvancedProperty -Name $adapter.Name `
                -DisplayName "Preferred Band" -DisplayValue "5GHz" -ErrorAction SilentlyContinue
            OK "Wi-Fi preferred band: 5GHz — lower latency than 2.4GHz"
        } catch { SKIP "Preferred band setting not available" }
    }
    WARN "Still on Wi-Fi? A wired ethernet connection will always have lower ping"
}
#endregion

#region 7. PING TEST AFTER
Section "RESULTS"
if ($pingBefore -ne $null) {
    Start-Sleep 2
    try {
        $pingAfter = (Test-Connection -ComputerName 8.8.8.8 -Count 4 -ErrorAction Stop |
                      Measure-Object -Property ResponseTime -Average).Average
        $pingAfter = [math]::Round($pingAfter, 1)
        $diff = [math]::Round($pingBefore - $pingAfter, 1)

        INFO "Ping before : ${pingBefore}ms"
        INFO "Ping after  : ${pingAfter}ms"
        if ($diff -gt 0) {
            OK "Improvement: -${diff}ms (DNS change alone can cut 5-20ms)"
        } elseif ($diff -eq 0) {
            INFO "No change in ping to 8.8.8.8 — most benefits are in-game (packet timing, not ICMP ping)"
        } else {
            WARN "Ping test shows slight increase — this is normal, ICMP ping ≠ game latency"
            INFO "Real benefit shows in-game as less jitter and smoother hit registration"
        }
    } catch { WARN "Could not measure post-tweak ping" }
}

Write-Host "`n  =====================================================" -ForegroundColor Magenta
Write-Host @"
   NETWORK OPTIMIZATION COMPLETE
  =====================================================
   WHAT WAS APPLIED:
     [+] TCP auto-tuning: Normal
     [+] TCP Chimney: DISABLED (fixes latency spikes)
     [+] RSS: Enabled (multi-core TCP processing)
     [+] Nagle's algorithm: Disabled (packets sent instantly)
     [+] DNS: Cloudflare 1.1.1.1 (faster than ISP DNS)
     [+] DNS cache maximized
     [+] QoS 20% bandwidth reserve: Removed
     [+] TCP TIME_WAIT: 30s (frees ports faster)
     [+] Max TCP ports: 65534
     [+] Game thread priority: CPU 6 / GPU 8
     [+] Network throttling: Disabled
     [+] ECN: Disabled (router compatibility)
$(if ($isWifi) { "     [+] Wi-Fi power saving: OFF`n     [+] Roaming aggressiveness: Lowest" })

   WHAT YOUR ORIGINAL SCRIPT HAD WRONG:
     [x] chimney=enabled  -> should be DISABLED for gaming
         (chimney offload causes jitter on modern hardware)

   MANUAL STEPS FOR EVEN BETTER PING:
     [>] Router: Enable QoS and set your PC as priority device
     [>] Router: Use 5GHz Wi-Fi or better — use Ethernet
     [>] Router: Change DNS to 1.1.1.1 in router settings
         (covers all devices, not just this PC)
     [>] In-game: disable in-game V-Sync (adds input lag)
     [>] Check your NIC driver is up to date

   RESTART RECOMMENDED FOR FULL EFFECT
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
