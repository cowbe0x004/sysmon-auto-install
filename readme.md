The purpose of this script is to install sysmon for monitoring system activities, and using winlogbeat to ship the logs to our SIEM. Various registry will be added to enable more comprehensive logging. Scheduled task will be created to auto update sysmon, winlogbeat, and configs every day. Local configs for sysmon and winlogbeat will be overwritten.


**Update local sysmonconfig.xml from sysmon-modular**  
Start powershell as admin.
```sh
cd sysmon-modular
git pull
# note the first dot and space after.
. .\Merge-SysmonXml.ps1
Merge-AllSysmonXml -Path ( Get-ChildItem '[0-9]*\*.xml') -AsString | Out-File sysmonconfig.xml
xcopy /q/y .\sysmonconfig.xml ..\sysmon_bin\sysmonconfig.xml
```

**Push sysmon update to repo**  
auto_update.bat script will update sysmon to the version you push to the repo.
```sh
cd sysmon_bin\
# Download sysmon from sysinternals. Direct URL https://live.sysinternals.com/Sysmon64.exe.
..\Sigcheck64.exe -n -nobanner /accepteula .\sysmon64.exe > .\sysmon_update_ver.txt
# commit and push the update
```

# Required actions
You need to place sysmon and winlogbeat that you want to install in sysmon_bin and wlb_bin directories. This script will not pull them from their official sites. These files should also exist.
 * ./sysmon_bin/sysmon_update_ver.txt - contains the version of sysmon
 * ./sysmonconfig.xml - sysmon config generated from sysmon-modular
 * ./wlb_bin/.build_hash.txt - pulled from inside winlogbeat archive, used by auto_update.bat script to indicate if another version needs to be installed
 * ./wlb_bin/winlogbeat.yml - your customized config file to apply
 ----
 * change variables at the top of install.bat and auto_update.bat according to your environment

# File description
 * auto_update.bat - schedule task to update sysmon rules
 * install.bat - main install script
 * ps_logging.reg - registry file to enable powershell logging
 * Sigcheck64.exe - used by auto_update.bat to check sysmon version
 * uninstall.bat - uninstall script, don't use if you did not install sysmon/winlogbeat using the install script
 * sysmon_bin/sysmon64.exe - sysmon executable
 * sysmon_bin/sysmon_update_ver.txt - contains the version of sysmon
 * sysmon_bin/sysmonconfig.xml - sysmon config generated from sysmon-modular
 * sysmon-modular - submodule olafhartong/sysmon-modular
 * wlb_bin/.build_hash.txt - to indicate the version of winlogbeat to install
 * wlb_bin/winlogbeat.yml - winlogbeat config
 * wlb_bin/winlogbeat.zip - winlogbeat binary

# Credits
 * [Sysmon-modular](https://github.com/olafhartong/sysmon-modular)
 * [Michael Gough's logging script](https://www.malwarearchaeology.com/logging)
