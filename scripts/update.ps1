[CmdletBinding()]
param(
    [string]$Repository = 'EugeneSlusar/1c-xml-import.ogbox.net',
    [string]$AssetName = 'ЗагрузкаУПД.epf'
)

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$destinationPath = Join-Path $PSScriptRoot $AssetName
$temporaryPath = Join-Path $PSScriptRoot ($AssetName + '.download')
$backupPath = Join-Path $PSScriptRoot ($AssetName + '.bak')
$releaseApiUrl = "https://api.github.com/repos/$Repository/releases/latest"
$headers = @{
    Accept = 'application/vnd.github+json'
    'User-Agent' = '1c-upd-import-updater'
}

Write-Host "Проверка последней версии: $Repository"

try {
    $release = Invoke-RestMethod -Uri $releaseApiUrl -Headers $headers -Method Get
    $asset = $release.assets | Where-Object { $_.name -eq $AssetName } | Select-Object -First 1

    if ($null -eq $asset) {
        throw "В релизе $($release.tag_name) не найден файл $AssetName."
    }

    Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    Invoke-WebRequest -Uri $asset.browser_download_url -Headers $headers -OutFile $temporaryPath -UseBasicParsing

    $downloadedFile = Get-Item -LiteralPath $temporaryPath
    if ($downloadedFile.Length -eq 0) {
        throw "GitHub вернул пустой файл $AssetName."
    }

    if (Test-Path -LiteralPath $destinationPath -PathType Leaf) {
        Copy-Item -LiteralPath $destinationPath -Destination $backupPath -Force
    }

    Move-Item -LiteralPath $temporaryPath -Destination $destinationPath -Force

    Write-Host "Обработка обновлена до версии $($release.tag_name)."
    Write-Host "Файл: $destinationPath"
    if (Test-Path -LiteralPath $backupPath -PathType Leaf) {
        Write-Host "Предыдущая версия сохранена: $backupPath"
    }
}
catch {
    Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
    throw "Не удалось обновить обработку: $($_.Exception.Message)"
}
