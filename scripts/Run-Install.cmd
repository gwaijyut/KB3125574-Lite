@echo off
REM KB3125574-Lite installer launcher.
REM Runs Install-KB3125574Lite.ps1 with -ExecutionPolicy Bypass so unsigned
REM scripts run regardless of the machine execution policy.
REM
REM Usage (from an elevated command prompt):
REM   Run-Install.cmd -Mount D:\Mount -Source X:\KB3125574-v4-x64 -List manifests\v3\base-original-observed-90.txt -ScratchDir D:\Scratch
REM
net session >nul 2>&1
if %errorlevel% neq 0 goto :notadmin
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-KB3125574Lite.ps1" %*
set rc=%errorlevel%
pause
exit /b %rc%

:notadmin
echo Please run this from an elevated Administrator command prompt.
pause
exit /b 1
