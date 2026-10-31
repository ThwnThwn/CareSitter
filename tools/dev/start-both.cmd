@echo off
pwsh.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0caresitter-dev.ps1" -App both
if errorlevel 1 pause
