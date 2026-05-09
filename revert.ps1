Write-Host "Restoring default Windows settings..." -ForegroundColor Yellow

# Reset power plan
powercfg /setactive SCHEME_BALANCED

# Enable telemetry default
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" `
/v AllowTelemetry /t REG_DWORD /d 1 /f

Write-Host "Revert complete. Restart PC." -ForegroundColor Green
