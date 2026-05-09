Write-Host "Applying NVIDIA optimizations..." -ForegroundColor Green

# Prefer max performance mode (if NVIDIA driver installed)
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" `
/v HwSchMode /t REG_DWORD /d 2 /f

# Reduce latency
reg add "HKCU\Software\NVIDIA Corporation\Global\NVTweak" `
/v PowerMizerEnable /t REG_DWORD /d 1 /f

Write-Host "NVIDIA tweaks applied (driver required)." -ForegroundColor Yellow
