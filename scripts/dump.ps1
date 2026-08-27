[CmdletBinding()]
param(
    [string]$EpfPath,
    [string]$UserName,
    [switch]$DryRun
)

. (Join-Path $PSScriptRoot 'common.ps1')

Invoke-UpdImportDesigner -Operation Dump -EpfPath $EpfPath -UserName $UserName -DryRun:$DryRun

