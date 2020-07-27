@echo off
echo ************************************************
echo *****  Sysmon/Winlogbeat Uninstall Script  *****
echo ************************************************

:: make sure script is ran with admin privileges.
echo [+] Checking for administrative privileges...
echo.
net session >nul 2>&1
if %errorLevel% == 0 (
	goto prompt
	) else (
	echo [-] Please run script with administrative privileges. Script will exit.
	pause >nul
	goto end
	)

setlocal
:prompt
set /p yes=This script will remove sysmon/winlogbeat and their directories, are you sure (Y/N)? 
if /i "%yes%" NEQ "Y" goto end
echo.
echo [+] Stopping sysmon and winlogbeat...
sc stop sysmon >nul
sc stop sysmon64 >nul
sc stop winlogbeat >nul
taskkill /F /IM sysmon.exe 2>nul
taskkill /F /IM sysmon64.exe 2>nul
taskkill /F /IM winlogbeat.exe 2>nul

echo [+] Removing sysmon...
C:\ProgramData\sysmon\sysmon64.exe -u force >nul
@rd /s /q C:\ProgramData\sysmon
echo [+] Removing winlogbeat...
@powershell -ExecutionPolicy Unrestricted -File "C:\ProgramData\winlogbeat\uninstall-service-winlogbeat.ps1" >nul
@rd /s /q C:\ProgramData\winlogbeat

echo [+] Removing daily update schedule task...
schtasks /delete /tn "Update sysmon and winlogbeat config" /f

echo.
echo [+] Done

pause >nul

:end
endlocal
