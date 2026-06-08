# Loads Phase 2b local upload settings from env/local-upload.env with terraform fallbacks.
function Get-S3UploadTarget {
    param(
        [string]$EnvFile
    )

    $ErrorActionPreference = "Stop"

    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
    if (-not $EnvFile) {
        $EnvFile = Join-Path $repoRoot "env\local-upload.env"
    }

    function Get-DotEnvValue {
        param([string]$Path, [string]$Key)
        if (-not (Test-Path $Path)) { return $null }
        foreach ($line in Get-Content $Path) {
            $trimmed = $line.Trim()
            if ($trimmed -eq "" -or $trimmed.StartsWith("#")) { continue }
            if ($trimmed -match '^\s*([^=]+)=(.*)$') {
                if ($matches[1].Trim() -eq $Key) {
                    return $matches[2].Trim().Trim('"').Trim("'")
                }
            }
        }
        return $null
    }

    $config = [ordered]@{
        AwsProfile  = Get-DotEnvValue -Path $EnvFile -Key "AWS_PROFILE"
        AwsRegion   = Get-DotEnvValue -Path $EnvFile -Key "AWS_REGION"
        S3Bucket    = Get-DotEnvValue -Path $EnvFile -Key "S3_BUCKET"
        S3Prefix    = Get-DotEnvValue -Path $EnvFile -Key "S3_PREFIX"
        DropPath    = Get-DotEnvValue -Path $EnvFile -Key "DROP_PATH"
        ArchivePath = Get-DotEnvValue -Path $EnvFile -Key "ARCHIVE_PATH"
    }

    # AwsProfile left empty when unset — caller uses default AWS credential chain.
    if (-not $config.AwsRegion) { $config.AwsRegion = "ap-southeast-1" }
    if (-not $config.S3Prefix) { $config.S3Prefix = "raw/" }
    if (-not $config.DropPath) { $config.DropPath = "C:\sftp-drop\raw" }
    if (-not $config.ArchivePath) { $config.ArchivePath = "C:\sftp-drop\archive" }

    if (-not $config.S3Prefix.EndsWith("/")) {
        $config.S3Prefix = "$($config.S3Prefix)/"
    }

    $terraformDir = Join-Path $repoRoot "infra\terraform"
    if (-not $config.S3Bucket -and (Test-Path (Join-Path $terraformDir ".terraform"))) {
        Push-Location $terraformDir
        try {
            $config.S3Bucket = (terraform output -raw bucket_name 2>$null).Trim()
        } finally {
            Pop-Location
        }
    }

    if (-not $config.S3Bucket) {
        throw "S3_BUCKET is not set. Copy env/local-upload.env.example to env/local-upload.env or deploy/terraform output bucket_name."
    }

    [pscustomobject]$config
}
