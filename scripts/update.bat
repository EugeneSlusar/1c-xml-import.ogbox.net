@echo off
setlocal

rem Temporary process-only bypass; Windows execution policy is not changed.
set "SCRIPT_DIR=%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT_DIR%update.ps1" %*
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo Update failed with exit code %EXIT_CODE%.
)

exit /b %EXIT_CODE%
