@echo off
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0caresitter-dev.ps1" -Stop
if errorlevel 1 pause
