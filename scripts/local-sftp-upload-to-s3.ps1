# Uploads completed files from the local drop folder to S3 under object_prefixes (default raw/).
param(
    [string]$EnvFile,
    [switch]$WaitForStableSize,
    [switch]$WhatIfOnly
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "Get-S3UploadTarget.ps1")
$cfg = Get-S3UploadTarget -EnvFile $EnvFile

if ($cfg.AwsProfile) { $env:AWS_PROFILE = $cfg.AwsProfile } else { Remove-Item Env:AWS_PROFILE -ErrorAction SilentlyContinue }
$env:AWS_DEFAULT_REGION = $cfg.AwsRegion

$logDir = Join-Path $PSScriptRoot "logs"
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
$logFile = Join-Path $logDir "upload-bridge.log"

function Write-BridgeLog {
    param([string]$Message)
    $line = "{0} {1}" -f (Get-Date -Format "yyyy-MM-dd HH:mm:ss"), $Message
    Add-Content -Path $logFile -Value $line
    Write-Host $line
}

Write-BridgeLog "Bridge start profile=$($cfg.AwsProfile) bucket=$($cfg.S3Bucket) prefix=$($cfg.S3Prefix)"

$identity = aws sts get-caller-identity --output json | ConvertFrom-Json
Write-BridgeLog "Caller account=$($identity.Account) arn=$($identity.Arn)"

if (-not (Test-Path $cfg.DropPath)) {
    New-Item -ItemType Directory -Path $cfg.DropPath -Force | Out-Null
    Write-BridgeLog "Created drop path $($cfg.DropPath)"
}
if (-not (Test-Path $cfg.ArchivePath)) {
    New-Item -ItemType Directory -Path $cfg.ArchivePath -Force | Out-Null
    Write-BridgeLog "Created archive path $($cfg.ArchivePath)"
}

function Test-FileSizeStable {
    param([string]$Path)
    if (-not $WaitForStableSize) { return $true }
    $size1 = (Get-Item $Path).Length
    Start-Sleep -Seconds 2
    $size2 = (Get-Item $Path).Length
    return $size1 -eq $size2
}

$files = Get-ChildItem -Path $cfg.DropPath -File -ErrorAction SilentlyContinue
if (-not $files) {
    Write-BridgeLog "No files in $($cfg.DropPath)"
    return
}

$uploaded = 0
$skipped = 0

foreach ($file in $files) {
    $name = $file.Name
    if ($name -match '\.(part|tmp)$') {
        Write-BridgeLog "Skip partial/temp: $name"
        $skipped++
        continue
    }
    if ($file.Length -eq 0) {
        Write-BridgeLog "Skip zero-byte: $name"
        $skipped++
        continue
    }
    if (-not (Test-FileSizeStable -Path $file.FullName)) {
        Write-BridgeLog "Skip unstable size: $name"
        $skipped++
        continue
    }

    $s3Uri = "s3://$($cfg.S3Bucket)/$($cfg.S3Prefix)$name"
    Write-BridgeLog "Upload $name -> $s3Uri"

    if ($WhatIfOnly) {
        $skipped++
        continue
    }

    aws s3 cp $file.FullName $s3Uri --only-show-errors
    if ($LASTEXITCODE -ne 0) {
        throw "aws s3 cp failed for $name (exit $LASTEXITCODE)"
    }

    $archiveDest = Join-Path $cfg.ArchivePath $name
    if (Test-Path $archiveDest) {
        $archiveDest = Join-Path $cfg.ArchivePath ("{0}-{1}" -f [IO.Path]::GetFileNameWithoutExtension($name), (Get-Date -Format "yyyyMMddHHmmss")) + $file.Extension
    }
    Move-Item -Path $file.FullName -Destination $archiveDest -Force
    Write-BridgeLog "Archived to $archiveDest"
    $uploaded++
}

Write-BridgeLog "Bridge done uploaded=$uploaded skipped=$skipped"
