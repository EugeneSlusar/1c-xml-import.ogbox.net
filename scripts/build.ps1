[CmdletBinding()]
param(
    [string]$UserName,
    [switch]$DryRun,
    [switch]$Publish
)

. (Join-Path $PSScriptRoot 'common.ps1')

Invoke-UpdImportDesigner -Operation Build -UserName $UserName -DryRun:$DryRun

if ($Publish -and $DryRun) {
    throw 'Нельзя публиковать результат режима DryRun.'
}

if ($Publish) {
    $projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $projectConfig = Get-Content -LiteralPath (Join-Path $projectRoot 'config/project.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $artifactPath = [System.IO.Path]::GetFullPath((Join-Path $projectRoot $projectConfig.artifact))
    $version = [string]$projectConfig.version
    $tag = "v$version"

    if (-not (Test-Path -LiteralPath $artifactPath -PathType Leaf)) {
        throw "EPF для публикации не найден: $artifactPath"
    }

    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if ($null -eq $gh) {
        throw 'Для публикации требуется GitHub CLI (команда gh).'
    }

    $remote = (git remote get-url origin).Trim()
    if ($remote -notmatch 'github\.com[:/]([^/]+/[^/]+?)(?:\.git)?$') {
        throw "Не удалось определить GitHub-репозиторий из origin: $remote"
    }
    $repository = $Matches[1]

    if (@(git status --porcelain).Count -gt 0) {
        throw 'Перед публикацией сохраните все изменения в commit.'
    }

    Write-Host "Отправка main в $repository..."
    & git push origin HEAD:main
    if ($LASTEXITCODE -ne 0) {
        throw 'Не удалось отправить коммиты в origin/main.'
    }

    & gh release view $tag --repo $repository *> $null
    $releaseExists = ($LASTEXITCODE -eq 0)
    if ($releaseExists) {
        Write-Host "Обновление существующего релиза $tag..."
        & gh release upload $tag $artifactPath --repo $repository --clobber
    }
    else {
        Write-Host "Создание релиза $tag..."
        & gh release create $tag $artifactPath --repo $repository --title "Загрузка УПД $tag" --notes "Сборка внешней обработки Загрузка УПД версии $version." --target main
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Не удалось опубликовать релиз $tag."
    }

    Write-Host "Релиз $tag опубликован: https://github.com/$repository/releases/tag/$tag"
}

