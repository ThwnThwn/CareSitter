@echo off
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0caresitter-dev.ps1" -App customer
if errorlevel 1 pause
