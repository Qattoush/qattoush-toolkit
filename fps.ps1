# QATTOUSH FPS OPTIMIZER

Write-Host "Applying FPS + Low Latency Tweaks..." -ForegroundColor Green

# Ultimate Performance Plan
powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 | Out-Null
powercfg /setactive e9a42b02-d5df-448d-aa00-03f14749eb61

# Disable fullscreen optimizations
reg add "HKCU\System\GameConfigStore" /v GameDVR_FSEBehaviorMode /t REG_DWORD /d 2 /f

# Reduce input delay
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" `
/v NetworkThrottlingIndex /t REG_DWORD /d 4294967295 /f

reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" `
/v SystemResponsiveness /t REG_DWORD /d 0 /f

# Enable hardware GPU scheduling
reg add "HKLM\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" `
/v HwSchMode /t REG_DWORD /d 2 /f

ipconfig /flushdns

Write-Host "FPS tweaks applied. Restart recommended." -ForegroundColor Yellow
