@echo off
echo ************************************************
echo *****   Sysmon/Winlogbeat Install Script   *****
echo ************************************************
::
:: Author: @cowbe0x004
::
echo.
echo ####################PRECHECK####################
timeout /t 5

:: directory of the install script, has a trailing \
set SCRIPT_DIR=%~dp0

set SYSMON_DIR=C:\ProgramData\sysmon
set SYSMON_CONF=sysmonconfig.xml
set SYSMON_BIN=%SCRIPT_DIR%sysmon_bin

set WLB_DIR=C:\ProgramData\winlogbeat
set WLB_BIN=%SCRIPT_DIR%wlb_bin

echo.
echo [+] Checking powershell version...
@powershell if ($PSVersionTable.PSVersion.Major -ge 5) { Write-Host " [+] You are running Powershell version $PSVersionTable.PSVersion.Major"} else { Write-Host " [-] Powershell version $PSVersionTable.PSVersion.Major detected, please update to version 5 or above."; exit(1) }
if %errorlevel% NEQ 0 (
	goto end
	)

:: make sure script is ran with admin privileges.
echo.
echo [+] Checking for administrative privileges...

net session >nul 2>&1
if %errorLevel% NEQ 0 (
	echo [-] Please run script with administrative privileges. Script will exit.
	goto end
)

echo.
echo ####################SYSMON####################

sc query sysmon64 >nul
if "%errorlevel%" EQU "0" (
	echo.
	echo [+] Sysmon installed, removing...
	sysmon64.exe -nobanner -u force
	)

echo.
echo [+] Copying sysmon and config...
if not exist %SYSMON_DIR% (
	mkdir %SYSMON_DIR%
	)
pushd %SYSMON_DIR%
xcopy /q/y %SYSMON_BIN%\sysmon64.exe %SYSMON_DIR%
xcopy /q/y %SYSMON_BIN%\%SYSMON_CONF% %SYSMON_DIR%
echo [+] Installing sysmon and applying config...
sysmon64.exe -nobanner -accepteula -i %SYSMON_CONF%
sc failure Sysmon64 actions= restart/10000/restart/10000// reset= 120
echo.
echo [+] Creating daily update task
:: add scheduler task to update sysmon config with start time based on when the task is added
setlocal
set hour=%time:~0,2%
set minute=%time:~3,2%
set /A minute+=2
if %minute% GTR 59 (
	set /A minute-=60
	set /A hour+=1
	)
if %hour%==24 set hour=00
if "%hour:~0,1%"==" " set hour=0%hour:~1,1%
if "%hour:~1,1%"=="" set hour=0%hour%
if "%minute:~1,1%"=="" set minute=0%minute%
set tasktime=%hour%:%minute%
::
xcopy /q/y %SCRIPT_DIR%auto_update.bat %SYSMON_DIR%
xcopy /q/y %SCRIPT_DIR%Sigcheck64.exe %SYSMON_DIR%
SchTasks /create /tn "Update sysmon and winlogbeat config" /ru SYSTEM /rl HIGHEST /sc daily /tr "cmd.exe /c \"%SYSMON_DIR%\\auto_update.bat\"" /f /st %tasktime%
powershell Get-Service sysmon64 || goto :service_error

echo ####################WINLOGBEAT####################

echo.
echo [+] Extract winlogbeat...
@powershell Expand-Archive -force -LiteralPath '%WLB_BIN%\winlogbeat.zip' -DestinationPath 'C:\Windows\Temp\'
if not exist %WLB_DIR% (
	mkdir %WLB_DIR%
	)
pushd "C:\Windows\Temp\winlogbeat*"
:: Make sure winlogbeat was extracted before copying everything.
if "%errorlevel%" EQU "0" (
	:: Copy every winlogbeat file to program dir
	echo [+] Copying winlogbeat and config...
	xcopy /q/y/s . %WLB_DIR%
	xcopy /q/y %WLB_BIN%\winlogbeat.yml %WLB_DIR%
	) else (
	:: Can't cd into winlogbeat*
	echo [-] Can't cd into C:\Windows\Temp\winlogbeat*. Script will exit.
    goto end
	)

echo [+] Installing winlogbeat and applying config...
@powershell -ExecutionPolicy Unrestricted -File "%WLB_DIR%\install-service-winlogbeat.ps1" >nul
echo [+] Starting winlogbeat...
@powershell Start-Service winlogbeat || goto :service_error
@powershell Get-Service winlogbeat

echo ####################PS LOGGING####################

echo.
echo [+] Importing PS logging registries and applying config...
:: https://www.malwarearchaeology.com/logging. 
:: These settings will only change the local security policy.  It is best to set these in Group Policy default profile so all systems get the same settings.  
:: GPO will overwrite these settings!
::
::#######################################################################
::
:: SET THE LOG SIZE - What local size they will be
:: ---------------------
::
:: 540100100 will give you 7 days of local Event Logs with everything logging (Security and Sysmon)
:: 1023934464 will give you 14 days of local Event Logs with everything logging (Security and Sysmon)
:: Other logs do not create as much quantity, so lower numbers are fine
::
:: 20480000 ~= 20mb
:: 50480000 ~= 50mb
:: 256000100 ~= 250mb
::
wevtutil sl Security /ms:100480000
::
wevtutil sl Application /ms:20480000
::
wevtutil sl Setup /ms:20480000
::
wevtutil sl System /ms:20480000
::
wevtutil sl "Windows Powershell" /ms:256000100
::
wevtutil sl "Microsoft-Windows-PowerShell/Operational" /ms:256000100
::
wevtutil sl "Microsoft-Windows-Sysmon/Operational" /ms:256000100
::
::#######################################################################
::
:: ---------------------------------------------------------------------
:: ENABLE The TaskScheduler log
:: ---------------------------------------------------------------------
::
wevtutil sl "Microsoft-Windows-TaskScheduler/Operational" /e:true
::
::#######################################################################
::
:: Creates profile.ps1 in the correct location - SET Command variables for PowerShell - Enables default profile to collect PowerShell Command Line parameters and allows .PS1 to execute
:: --------------------------------------------------------------------------------------------------------------------------
::
:: Allows local powershell scripts to run
::
powershell Set-ExecutionPolicy RemoteSigned
::
:: For powershell version 2-4. Not adding to profile.ps1 because it will output the registry every time powershell is opened. -ahuang
::echo Get-Item "hklm:\software\microsoft\windows\currentversion\policies\system\audit" > c:\windows\system32\WindowsPowerShell\v1.0\profile.ps1
findstr /i "LogCommandHealthEvent" c:\windows\system32\WindowsPowerShell\v1.0\profile.ps1 >nul
if "%errorlevel%" NEQ "0" (
	echo $LogCommandHealthEvent = $true >> c:\windows\system32\WindowsPowerShell\v1.0\profile.ps1
	)
findstr /i "LogCommandLifecycleEvent" c:\windows\system32\WindowsPowerShell\v1.0\profile.ps1 >nul
if "%errorlevel%" NEQ "0" (
	echo $LogCommandLifecycleEvent = $true >> c:\windows\system32\WindowsPowerShell\v1.0\profile.ps1
	)
::
:: importing ps_logging.reg to enable powershell logging.
reg import "%SCRIPT_DIR%ps_logging.reg" >nul

:: Disable audit category
:: May need to disable these if logs get too noisy
:: 
::auditpol /set /subcategory:"Filtering Platform Connection" /success:disable /failure:disable

echo.
echo [+] Script finished.

goto end

:service_error
echo [-] Service failed to start. Script will exit.

:end
pause >nul
