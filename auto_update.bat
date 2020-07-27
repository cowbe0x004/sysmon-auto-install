@echo off

set SYSMON_DIR=C:\ProgramData\sysmon
set SYSMON_CONF=sysmonconfig_new.xml
:: Direct url to these files in your own repo
set SYSMON_CONF_URL=https://<CHANGE_ME>/-/raw/master/sysmon_bin/sysmonconfig.xml
set SYSMON_URL=https://<CHANGE_ME>/-/raw/master/sysmon_bin/sysmon64.exe
set SYSMON_VER_URL=https://<CHANGE_ME>/-/raw/master/sysmon_bin/sysmon_update_ver.txt

set WLB_DIR=C:\ProgramData\winlogbeat
set WLB_URL=https://<CHANGE_ME>/-/raw/master/wlb_bin/winlogbeat.zip
set WLB_CONF_URL=https://<CHANGEME_ME>/-/raw/master/wlb_bin/winlogbeat.yml
set WLB_VER_URL=https://<CHANGEME_ME>/-/raw/master/wlb_bin/.build_hash.txt

echo ####################SYSMON####################

:: Checking sysmon version...
%SYSMON_DIR%\sigcheck64.exe -n -nobanner /accepteula %SYSMON_DIR%\sysmon64.exe > %SYSMON_DIR%\sysmon_local_ver.txt
set /p sysmon_local_ver= < %SYSMON_DIR%\sysmon_local_ver.txt
:: Downloading the version update file
@powershell (New-Object System.Net.WebClient).DownloadFile('%SYSMON_VER_URL%', '%SYSMON_DIR%\sysmon_update_ver.txt')
set /p sysmon_update_ver= < %SYSMON_DIR%\sysmon_update_ver.txt

:: If both .txt files are not identical, update is available, else just update the config.
if "%sysmon_local_ver%" NEQ "%sysmon_update_ver%" (
	goto update_sysmon
	) else (
	goto apply_conf
	)

:update_sysmon
:: New sysmon version available, updating...
:: Uninstalling sysmon...
%SYSMON_DIR%\sysmon64.exe -nobanner -u force
@powershell (New-Object System.Net.WebClient).DownloadFile('%SYSMON_URL%','%SYSMON_DIR%\sysmon64.exe')
:: Installing sysmon
%SYSMON_DIR%\sysmon64.exe -nobanner -accepteula -i
:: attempting to restart sysmon if it fails to start...
sc failure Sysmon64 actions= restart/10000/restart/10000// reset= 120
goto apply_conf

:apply_conf
echo Apply sysmon config...
:: Downloading sysmon config...
@powershell (New-Object System.Net.WebClient).DownloadFile('%SYSMON_CONF_URL%', '%SYSMON_DIR%\%SYSMON_CONF%')
:: Apply config and restart if hashes different.
for /f "delims=" %%a in ('CertUtil -hashfile "%SYSMON_DIR%\sysmonconfig.xml" MD5 ^| findstr /v "MD5 CertUtil"') do set "ORIGINAL=%%a"
set "ORIGINAL=%ORIGINAL: =%"

for /f "delims=" %%a in ('CertUtil -hashfile "%SYSMON_DIR%\sysmonconfig_new.xml" MD5 ^| findstr /v "MD5 CertUtil"') do set "NEW=%%a"
set "NEW=%NEW: =%"

if "%ORIGINAL%" == "%NEW%" (
	:: Same hash, no need to apply config
	goto winlogbeat
	) else (
	:: Applying config...
	xcopy /q/y %SYSMON_DIR%\sysmonconfig_new.xml %SYSMON_DIR%\sysmonconfig.xml
	%SYSMON_DIR%\sysmon64.exe -nobanner -c %SYSMON_DIR%\%SYSMON_CONF%
	)
	
:winlogbeat
echo ####################WINLOGBEAT####################
:: Since elasticsearch is picky about the version of winlogbeat, and sigcheck doesn't work,
:: I'm using ./wlb_bin/.build_hash.txt (from inside uncompressed winlogbeat directory) 
:: to indicate the version to install. Replace this file to install 
:: another version.

:: Winlogbeat local version
set /p wlb_local_ver= < %WLB_DIR%\.build_hash.txt
:: Downloading build_hash.txt
@powershell (New-Object System.Net.WebClient).DownloadFile('%WLB_VER_URL%', '%WLB_DIR%\wlb_update_ver.txt')
set /p wlb_update_ver= < %WLB_DIR%\wlb_update_ver.txt

:: If both .txt files are not identical, update is available, else just update the config.
if "%wlb_local_ver%" NEQ "%wlb_update_ver%" (
	goto update_wlb
	) else (
	goto apply_wlb_conf
	)

:update_wlb
:: Remove remant winlogbeat in c:\windows\temp
:: /P path to search
:: /M search mark, winlogbeat*
:: /C command to execute
forfiles /P C:\Windows\Temp /M winlogbeat* /C "cmd /c if @isdir==TRUE rmdir /s /q @file"

:: Downloading winlogbeat
@powershell (New-Object System.Net.WebClient).DownloadFile('%WLB_URL%', 'C:\Windows\Temp\winlogbeat.zip')
@powershell Expand-Archive -force -LiteralPath 'C:\Windows\Temp\winlogbeat.zip' -DestinationPath 'C:\Windows\Temp\'
pushd C:\Windows\Temp\winlogbeat*
:: Did extraction to temp successful?
if "%errorlevel%" EQU "0" (
	:: If yes, copy over to program dir
	powershell Stop-Service winlogbeat
	xcopy /q/y/s . %WLB_DIR%
	) else (
	:: No, output error
	echo [-] Can't cd into C:\Windows\Temp\winlogbeat*
	)
@powershell -ExecutionPolicy Unrestricted -File "%WLB_DIR%\install-service-winlogbeat.ps1"

:apply_wlb_conf
:: Downloading config
@powershell (New-Object System.Net.WebClient).DownloadFile('%WLB_CONF_URL%', '%WLB_DIR%\winlogbeat_new.yml')
:: Apply config and restart if hashes different.
for /f "delims=" %%a in ('CertUtil -hashfile "%WLB_DIR%\winlogbeat.yml" MD5 ^| findstr /v "MD5 CertUtil"') do set "ORIGINAL=%%a"
set "ORIGINAL=%ORIGINAL: =%"

for /f "delims=" %%a in ('CertUtil -hashfile "%WLB_DIR%\winlogbeat_new.yml" MD5 ^| findstr /v "MD5 CertUtil"') do set "NEW=%%a"
set "NEW=%NEW: =%"

if "%ORIGINAL%" == "%NEW%" (
	:: Same hash, no need to restart winlogbeat
	goto end
	) else (
	:: Restarting winlogbeat with updated config...
	xcopy /q/y %WLB_DIR%\winlogbeat_new.yml %WLB_DIR%\winlogbeat.yml
	@powershell Restart-Service winlogbeat
	)

:end
