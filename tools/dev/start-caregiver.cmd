@echo off
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0caresitter-dev.ps1" -App caregiver
if errorlevel 1 pause
