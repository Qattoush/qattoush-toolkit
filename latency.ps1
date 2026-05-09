Write-Host "Applying low latency network tweaks..." -ForegroundColor Green

netsh int tcp set global autotuninglevel=normal
netsh int tcp set global rss=enabled
netsh int tcp set global chimney=enabled

# Prioritize gaming traffic
reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" `
/v Priority /t REG_DWORD /d 6 /f

reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile\Tasks\Games" `
/v GPU Priority /t REG_DWORD /d 8 /f

ipconfig /flushdns

Write-Host "Latency optimized." -ForegroundColor Yellow
