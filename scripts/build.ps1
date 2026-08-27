[CmdletBinding()]
param(
    [string]$UserName,
    [switch]$DryRun
)

. (Join-Path $PSScriptRoot 'common.ps1')

Invoke-UpdImportDesigner -Operation Build -UserName $UserName -DryRun:$DryRun

