# Invoke BucketLister without UTF-8 BOM (PowerShell 5.1 Out-File -Encoding utf8 adds BOM and breaks Lambda JSON).
param(
    [string]$Prefix = "raw/",
    [string]$FunctionName = "sftp-s3-glue-rd-bucket-lister",
    [string]$Region = "ap-southeast-1"
)

$ErrorActionPreference = "Stop"
Set-Location $PSScriptRoot

$payloadPath = Join-Path $PSScriptRoot "lister-payload.json"
$responsePath = Join-Path $PSScriptRoot "list-response.json"

$json = if ([string]::IsNullOrEmpty($Prefix)) { "{}" } else { "{`"prefix`":`"$Prefix`"}" }
[System.IO.File]::WriteAllText($payloadPath, $json)

aws lambda invoke `
    --function-name $FunctionName `
    --region $Region `
    --payload "fileb://$payloadPath" `
    $responsePath

Get-Content $responsePath
