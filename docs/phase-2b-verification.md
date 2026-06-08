# Phase 2b verification checklist

| # | Step | Pass? | Notes |
|---|------|-------|-------|
| 1 | `env/local-upload.env` exists with `AWS_PROFILE`, `S3_BUCKET`, `S3_PREFIX=raw/` | | |
| 2 | `aws sts get-caller-identity` succeeds with profile | | |
| 3a | **2b-minimal:** `aws s3 cp` or `scripts/test-phase-2b.ps1` → object in `s3://bucket/raw/` | | |
| 3b | **2b-full (optional):** FileZilla SFTP to `127.0.0.1` → file in `C:\sftp-drop\raw\` | | |
| 4 | Bridge archives uploaded file to `C:\sftp-drop\archive\` | | |
| 5 | Within ~2 min, RdSuccessLogger CloudWatch log shows success suffix | | Log group: `/aws/lambda/<lambda_function_name>` |
| 6 | **Negative:** file left local-only (no bridge) → no new success log | | |
| 7 | **Negative (optional):** upload to wrong S3 prefix (not `raw/`) → no Lambda match | | |

## Commands

```powershell
.\scripts\test-phase-2b.ps1
aws s3 ls s3://BUCKET/raw/test-2b.txt --profile personal
aws logs tail /aws/lambda/FUNCTION_NAME --since 5m --profile personal
```

## Sign-off

| Field | Value |
|-------|-------|
| Date | |
| Tester | |
| Mode | 2b-minimal / 2b-full |
| bucket_name | |
| Result | PASS / FAIL |
