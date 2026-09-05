@echo off
setlocal

rem Standalone updater. It does not require update.ps1 or Git.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference='Stop'; $tmp=$null; try { [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; $repo='EugeneSlusar/1c-xml-import.ogbox.net'; $api='https://api.github.com/repos/'+$repo+'/releases/latest'; $h=@{Accept='application/vnd.github+json';'User-Agent'='1c-upd-import-updater'}; $r=Invoke-RestMethod -Uri $api -Headers $h -Method Get; $a=$null; foreach($x in $r.assets){if($x.name -like '*.epf'){$a=$x;break}}; if($null -eq $a){throw 'EPF asset not found in the latest GitHub release.'}; $originalName=-join ([char[]](0x417,0x430,0x433,0x440,0x443,0x437,0x43A,0x430,0x423,0x41F,0x414,0x2E,0x65,0x70,0x66)); $d=Join-Path '%~dp0' $originalName; $tmp=$d+'.download'; Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue; Invoke-WebRequest -Uri $a.browser_download_url -Headers $h -OutFile $tmp -UseBasicParsing; if((Get-Item -LiteralPath $tmp).Length -eq 0){throw 'Downloaded EPF is empty.'}; Move-Item -LiteralPath $tmp -Destination $d -Force; Write-Host ('UPDATE SUCCESSFUL. Version: '+$r.tag_name+'. File: '+$d) } catch { if($null -ne $tmp){Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue}; Write-Error ('UPDATE FAILED: '+$_.Exception.Message); exit 1 }"
set "EXIT_CODE=%ERRORLEVEL%"

if not "%EXIT_CODE%"=="0" (
    echo Update failed with exit code %EXIT_CODE%.
)

exit /b %EXIT_CODE%
