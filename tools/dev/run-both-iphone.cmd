@echo off
setlocal
where pwsh.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: PowerShell 7 ^(pwsh.exe^) was not found.
    echo Install PowerShell 7, then run this launcher again.
    pause
    exit /b 1
)

pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0caresitter-dev.ps1" -App both %*
set "launcherExitCode=%ERRORLEVEL%"
echo.
if not "%launcherExitCode%"=="0" echo CareSitter stopped with an error. Read the message above.
pause
exit /b %launcherExitCode%
