# Phase 2b acceptance helper: drop file -> bridge -> verify S3 key exists.
param(
    [string]$EnvFile,
    [string]$TestFileName = "test-2b.txt",
    [switch]$SkipUpload
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "Get-S3UploadTarget.ps1")
$cfg = Get-S3UploadTarget -EnvFile $EnvFile

$env:AWS_PROFILE = $cfg.AwsProfile
$env:AWS_DEFAULT_REGION = $cfg.AwsRegion

if (-not (Test-Path $EnvFile) -and -not $EnvFile) {
    $defaultEnv = Join-Path (Resolve-Path (Join-Path $PSScriptRoot "..")) "env\local-upload.env"
    if (-not (Test-Path $defaultEnv)) {
        throw "Missing env/local-upload.env. Copy env/local-upload.env.example and set S3_BUCKET."
    }
}

if (-not (Test-Path $cfg.DropPath)) {
    New-Item -ItemType Directory -Path $cfg.DropPath -Force | Out-Null
}

$localPath = Join-Path $cfg.DropPath $TestFileName
if (-not $SkipUpload) {
    [System.IO.File]::WriteAllText($localPath, "Phase 2b test $(Get-Date -Format o)")
    & (Join-Path $PSScriptRoot "local-sftp-upload-to-s3.ps1") -EnvFile $EnvFile -WaitForStableSize
}

$s3Key = "$($cfg.S3Prefix)$TestFileName"
Write-Host "Checking s3://$($cfg.S3Bucket)/$s3Key"
aws s3 ls "s3://$($cfg.S3Bucket)/$s3Key" --region $cfg.AwsRegion
if ($LASTEXITCODE -ne 0) {
    throw "Object not found in S3."
}

Write-Host ""
Write-Host "PASS: object exists in S3."
Write-Host "Within ~2 minutes, check CloudWatch log group /aws/lambda/<lambda_function_name> for RdSuccessLogger success line."
