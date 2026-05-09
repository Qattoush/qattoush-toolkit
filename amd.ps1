Write-Host "AMD optimizations (basic registry tweaks)" -ForegroundColor Green

# Disable power saving throttles
powercfg /setactive SCHEME_MIN

Write-Host "AMD optimized (driver-side tuning recommended in Adrenalin)." -ForegroundColor Yellow
