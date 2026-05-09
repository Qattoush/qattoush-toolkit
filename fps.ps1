@echo off
title QATTOUSH TOOLKIT
color 0A

:: ======================================================
:: QATTOUSH TOOLKIT LAUNCHER
:: ======================================================

:: ADMIN CHECK
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator Privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/c %~s0' -Verb runAs"
    exit
)

:menu
cls

echo ============================================
echo              QATTOUSH TOOLKIT
echo ============================================
echo.
echo [1] Extreme FPS Optimizer
echo [2] NVIDIA Optimizer
echo [3] AMD Optimizer
echo [4] Windows Debloater
echo [5] Low Latency Tweaks
echo [6] Restore Defaults
echo [7] Exit
echo.
set /p choice=Select an option:

:: ======================================================
:: MENU OPTIONS
:: ======================================================

if "%choice%"=="1" (
    cls
    echo Running Extreme FPS Optimizer...
    powershell -ep bypass -c "irm https://qattoush.dev/fps | iex"
    pause
    goto menu
)

if "%choice%"=="2" (
    cls
    echo Running NVIDIA Optimizer...
    powershell -ep bypass -c "irm https://qattoush.dev/nvidia | iex"
    pause
    goto menu
)

if "%choice%"=="3" (
    cls
    echo Running AMD Optimizer...
    powershell -ep bypass -c "irm https://qattoush.dev/amd | iex"
    pause
    goto menu
)

if "%choice%"=="4" (
    cls
    echo Running Windows Debloater...
    powershell -ep bypass -c "irm https://qattoush.dev/debloat | iex"
    pause
    goto menu
)

if "%choice%"=="5" (
    cls
    echo Running Low Latency Tweaks...
    powershell -ep bypass -c "irm https://qattoush.dev/latency | iex"
    pause
    goto menu
)

if "%choice%"=="6" (
    cls
    echo Restoring Windows Defaults...
    powershell -ep bypass -c "irm https://qattoush.dev/revert | iex"
    pause
    goto menu
)

if "%choice%"=="7" exit

echo Invalid Option
timeout /t 2 >nul
goto menu
