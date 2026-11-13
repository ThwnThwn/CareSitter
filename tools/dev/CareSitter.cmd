@echo off
setlocal
where pwsh.exe >nul 2>&1
if errorlevel 1 (
    echo ERROR: PowerShell 7 ^(pwsh.exe^) was not found.
    pause
    exit /b 1
)

:menu
cls
echo =====================================
echo          CARESITTER DEV TOOL
echo =====================================
echo 1. Run Customer on iPhone
echo 2. Run Caregiver on iPhone
echo 3. Run both apps in sequence
echo 4. Stop dev tool services
echo 0. Exit
echo.
choice /c 12340 /n /m "Choose an option: "
if errorlevel 5 exit /b 0
if errorlevel 4 goto stop
if errorlevel 3 goto both
if errorlevel 2 goto caregiver
if errorlevel 1 goto customer

:customer
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0caresitter-dev.ps1" -App customer %*
goto result

:caregiver
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0caresitter-dev.ps1" -App caregiver %*
goto result

:both
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0caresitter-dev.ps1" -App both %*
goto result

:stop
pwsh.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0caresitter-dev.ps1" -Stop %*

:result
if errorlevel 1 echo CareSitter stopped with an error. Read the message above.
echo.
pause
goto menu
