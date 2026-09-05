[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Set-Location -LiteralPath $projectRoot

if (-not (Test-Path -LiteralPath (Join-Path $projectRoot '.git') -PathType Container)) {
    throw "Git repository is not found: $projectRoot"
}

$dirty = @(git status --porcelain)
if ($dirty.Count -gt 0 -and -not $Force) {
    throw "Рабочая папка содержит локальные изменения. Сохраните их в commit или запустите с -Force для замены проекта."
}

Write-Host 'Получение последней версии из origin/main...'
git fetch origin main
git checkout main
git reset --hard origin/main
Write-Host 'Проект обновлён.'
Write-Host "Папка: $projectRoot"
