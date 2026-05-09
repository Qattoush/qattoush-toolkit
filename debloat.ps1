Write-Host "Removing bloatware + temp files..." -ForegroundColor Green

# Remove temp files
Remove-Item "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "C:\Windows\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

# Remove common bloat apps
$bloat = @(
"*Xbox*","*Skype*","*Zune*","*Solitaire*",
"*Bing*","*GetHelp*","*OfficeHub*"
)

foreach ($app in $bloat) {
    Get-AppxPackage $app | Remove-AppxPackage -ErrorAction SilentlyContinue
}

# Disable telemetry
reg add "HKLM\SOFTWARE\Policies\Microsoft\Windows\DataCollection" `
/v AllowTelemetry /t REG_DWORD /d 0 /f

Write-Host "Debloat complete." -ForegroundColor Yellow
