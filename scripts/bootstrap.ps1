[CmdletBinding()]
param()

. (Join-Path $PSScriptRoot 'common.ps1')

$context = Get-UpdImportContext

Write-Host '1C UPD import project preflight'
Write-Host ('Project:       ' + $context.ProjectRoot)
Write-Host ('Local 1C:      ' + $context.OneCExecutable)
Write-Host ('Local stand:   ' + $context.DevelopmentConfiguration + ' ' + $context.DevelopmentConfigurationVersion)
Write-Host ('Local base:    ' + $context.InfobasePath)
Write-Host ('Target:        ' + $context.TargetConfiguration + ' ' + $context.TargetConfigurationVersion)
Write-Host ('Target 1C:     ' + $context.TargetPlatformVersion)
Write-Host ('Source root:   ' + $context.SourceRoot)
Write-Host ('EPF artifact:  ' + $context.Artifact)
Write-Host ('Sample XML:    ' + $context.SampleXml)
Write-Host ''

$failed = $false

try {
    Assert-OneCEnvironment -Context $context
    Write-Host '[OK] 1C executable and infobase are available.'
}
catch {
    Write-Host ('[ERROR] ' + $_.Exception.Message)
    $failed = $true
}

if (Get-Command git -ErrorAction SilentlyContinue) {
    Write-Host '[OK] Git is available.'
}
else {
    Write-Host '[ERROR] Git is not available.'
    $failed = $true
}

if (Test-Path -LiteralPath $context.SourceRoot -PathType Leaf) {
    Write-Host '[OK] EPF text sources are present.'
}
else {
    Write-Host '[WAIT] EPF text sources have not been bootstrapped yet.'
}

if (Test-Path -LiteralPath $context.SampleXml -PathType Leaf) {
    Write-Host '[OK] Acceptance sample XML is present.'
}
else {
    Write-Host '[WAIT] Acceptance sample XML has not been added yet.'
}

if ($failed) {
    exit 1
}

if (-not (Test-Path -LiteralPath $context.SourceRoot -PathType Leaf)) {
    Write-Host ''
    Write-Host 'One-time EPF bootstrap:'
    Write-Host '1. Open the configured infobase in 1C Designer.'
    Write-Host '2. Select File -> New -> External data processor.'
    Write-Host '3. Set the processor name to the name required by the project specification.'
    Write-Host '4. Add a managed form named Form and make it the main form.'
    Write-Host ('5. Save the processor as: ' + $context.Artifact)
    Write-Host '6. Run: .\scripts\dump.ps1'
}
