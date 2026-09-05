Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-ProjectPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectRoot,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return [System.IO.Path]::GetFullPath($Path)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot $Path))
}

function Get-UpdImportContext {
    $projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
    $projectConfigPath = Join-Path $projectRoot 'config/project.json'
    $localConfigPath = Join-Path $projectRoot 'config/local.settings.json'

    if (-not (Test-Path -LiteralPath $projectConfigPath -PathType Leaf)) {
        throw "Project config is missing: $projectConfigPath"
    }

    $projectConfig = Get-Content -LiteralPath $projectConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    $localConfig = $null

    if (Test-Path -LiteralPath $localConfigPath -PathType Leaf) {
        $localConfig = Get-Content -LiteralPath $localConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
    }

    $oneCExecutable = $null
    $infobasePath = $null

    if ($null -ne $localConfig) {
        $oneCExecutable = $localConfig.oneCExecutable
        $infobasePath = $localConfig.infobasePath
    }

    return [PSCustomObject]@{
        ProjectRoot = $projectRoot
        OneCExecutable = $oneCExecutable
        InfobasePath = $infobasePath
        TargetConfiguration = $projectConfig.target.configuration
        TargetConfigurationVersion = $projectConfig.target.configurationVersion
        TargetPlatformVersion = $projectConfig.target.platformVersion
        DevelopmentConfiguration = $projectConfig.developmentStand.configuration
        DevelopmentConfigurationVersion = $projectConfig.developmentStand.configurationVersion
        DevelopmentPlatformVersion = $projectConfig.developmentStand.platformVersion
        SourceRoot = ConvertTo-ProjectPath -ProjectRoot $projectRoot -Path $projectConfig.sourceRoot
        Artifact = ConvertTo-ProjectPath -ProjectRoot $projectRoot -Path $projectConfig.artifact
        SampleXml = ConvertTo-ProjectPath -ProjectRoot $projectRoot -Path $projectConfig.sampleXml
        LogsDirectory = ConvertTo-ProjectPath -ProjectRoot $projectRoot -Path $projectConfig.logsDirectory
        LocalConfigPath = $localConfigPath
    }
}

function Assert-OneCEnvironment {
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject]$Context
    )

    if ([string]::IsNullOrWhiteSpace($Context.OneCExecutable)) {
        throw "Set oneCExecutable in $($Context.LocalConfigPath)"
    }

    if (-not (Test-Path -LiteralPath $Context.OneCExecutable -PathType Leaf)) {
        throw "1C executable is not found: $($Context.OneCExecutable)"
    }

    if ([string]::IsNullOrWhiteSpace($Context.InfobasePath)) {
        throw "Set infobasePath in $($Context.LocalConfigPath)"
    }

    if (-not (Test-Path -LiteralPath $Context.InfobasePath -PathType Container)) {
        throw "Infobase directory is not found: $($Context.InfobasePath)"
    }
}

function Format-CommandLine {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Executable,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $formattedArguments = foreach ($argument in $Arguments) {
        if ($argument -match '[\s"]') {
            '"' + $argument.Replace('"', '\"') + '"'
        }
        else {
            $argument
        }
    }

    return ('"' + $Executable + '" ' + ($formattedArguments -join ' '))
}

function Invoke-UpdImportDesigner {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Build', 'Dump')]
        [string]$Operation,

        [string]$EpfPath,

        [string]$UserName,

        [switch]$DryRun
    )

    $context = Get-UpdImportContext
    Assert-OneCEnvironment -Context $context

    if ([string]::IsNullOrWhiteSpace($EpfPath)) {
        $resolvedEpfPath = $context.Artifact
    }
    else {
        $resolvedEpfPath = ConvertTo-ProjectPath -ProjectRoot $context.ProjectRoot -Path $EpfPath
    }

    New-Item -ItemType Directory -Force -Path $context.LogsDirectory | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $context.Artifact) | Out-Null
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $context.SourceRoot) | Out-Null

    $operationName = $Operation.ToLowerInvariant()
    $logPath = Join-Path $context.LogsDirectory ($operationName + '.log')
    $resultPath = Join-Path $context.LogsDirectory ($operationName + '.result.txt')

    $arguments = @('DESIGNER', '/F', $context.InfobasePath)

    if (-not [string]::IsNullOrWhiteSpace($UserName)) {
        $arguments += @('/N', $UserName)
    }

    if ($Operation -eq 'Build') {
        $arguments += @(
            '/LoadExternalDataProcessorOrReportFromFiles',
            $context.SourceRoot,
            $context.Artifact
        )
    }
    else {
        $arguments += @(
            '/DumpExternalDataProcessorOrReportToFiles',
            $context.SourceRoot,
            $resolvedEpfPath,
            '-Format',
            'Hierarchical'
        )
    }

    $arguments += @('/DisableStartupMessages', '/Out', $logPath, '/DumpResult', $resultPath)

    Write-Host (Format-CommandLine -Executable $context.OneCExecutable -Arguments $arguments)

    if ($DryRun) {
        return
    }

    if ($Operation -eq 'Build' -and -not (Test-Path -LiteralPath $context.SourceRoot -PathType Leaf)) {
        throw "Source root is missing. Bootstrap or dump the EPF first: $($context.SourceRoot)"
    }

    if ($Operation -eq 'Dump' -and -not (Test-Path -LiteralPath $resolvedEpfPath -PathType Leaf)) {
        throw "EPF is not found: $resolvedEpfPath"
    }

    # Do not accept a stale result from a previous Designer run.
    Remove-Item -LiteralPath $logPath, $resultPath -Force -ErrorAction SilentlyContinue
    & $context.OneCExecutable @arguments
    # GUI/batch launches of 1cv8.exe do not always initialise LASTEXITCODE
    # in Windows PowerShell. The /DumpResult file is the authoritative result.
    $designerExitCode = 0
    if (Test-Path -LiteralPath 'variable:LASTEXITCODE') {
        $designerExitCode = $LASTEXITCODE
    }

    # 1C may create / finish writing DumpResult slightly after the process exits.
    $resultDeadline = (Get-Date).AddSeconds(10)
    while (-not (Test-Path -LiteralPath $resultPath -PathType Leaf) -and (Get-Date) -lt $resultDeadline) {
        Start-Sleep -Milliseconds 250
    }

    if (-not (Test-Path -LiteralPath $resultPath -PathType Leaf)) {
        if ($designerExitCode -eq -1073741510) {
            Write-Warning "BUILD CANCELLED: the 1C Designer process was closed. EPF was not published."
            return $false
        }
        if ((Test-Path -LiteralPath $logPath -PathType Leaf) -and (Get-Item -LiteralPath $logPath).Length -eq 0) {
            throw "1C Designer could not access the development infobase. Close all 1C sessions connected to the local UNF infobase and run build again."
        }
        throw "1C Designer failed with exit code $designerExitCode and did not produce a result file. See $logPath"
    }

    $designerResult = ''
    $resultDeadline = (Get-Date).AddSeconds(10)
    while ((Get-Date) -lt $resultDeadline) {
        $designerResult = (Get-Content -LiteralPath $resultPath -Raw -ErrorAction SilentlyContinue).Trim()
        if ($designerResult -eq '0') {
            break
        }
        Start-Sleep -Milliseconds 250
    }
    if ([string]::IsNullOrWhiteSpace($designerResult)) {
        throw "1C Designer produced an empty result file. See $logPath"
    }
    if (-not [string]::IsNullOrWhiteSpace($designerResult) -and $designerResult -ne '0') {
        throw "1C Designer returned result $designerResult. See $logPath"
    }

    if ($designerExitCode -ne 0) {
        Write-Warning "1C Designer returned exit code $designerExitCode, but DumpResult=0; build completed successfully."
    }

    Write-Host "$Operation completed successfully."
    return $true
}
