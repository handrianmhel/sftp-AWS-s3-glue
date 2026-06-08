# Phase 2b — Local OpenSSH SFTP push

Local Windows ingest: optional FileZilla → laptop OpenSSH → drop folder → PowerShell bridge → `aws s3 cp` → existing S3 → EventBridge → RdSuccessLogger.

**S3 has no SFTP endpoint.** OpenSSH on the laptop is not S3; the bridge uses the S3 HTTPS API with your developer IAM profile.

## Paths

| Mode | Flow |
|------|------|
| **2b-full** | FileZilla → `127.0.0.1:22` → `C:\sftp-drop\raw\` → `scripts/local-sftp-upload-to-s3.ps1` → S3 `raw/` |
| **2b-minimal** | Skip OpenSSH; copy `aws s3 cp` or run bridge script on files already in drop folder |

## Prerequisites

- Windows 11 with [AWS CLI](https://aws.amazon.com/cli/) and `AWS_PROFILE=personal` (or your profile)
- Stack deployed; bucket name from `terraform output -raw bucket_name`
- Copy `env/local-upload.env.example` → `env/local-upload.env` (gitignored)

## 2b-minimal (fastest)

```powershell
cd infra/terraform
$bucket = terraform output -raw bucket_name
$env:AWS_PROFILE = "personal"
aws s3 cp .\test-2b.txt "s3://$bucket/raw/test-2b.txt"
```

Or use the bridge:

```powershell
# Place file in C:\sftp-drop\raw\
.\scripts\local-sftp-upload-to-s3.ps1
.\scripts\test-phase-2b.ps1
```

Within ~2 minutes, check CloudWatch `/aws/lambda/<lambda_function_name>` for the RdSuccessLogger success line.

## 2b-full — Windows OpenSSH Server

### 1. Install OpenSSH Server

```powershell
Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
Start-Service sshd
Set-Service -Name sshd -StartupType Automatic
```

Default R&D: **no inbound firewall rule** — FileZilla on same machine uses `127.0.0.1` (loopback).

### 2. Create drop folders and user

```powershell
New-Item -ItemType Directory -Force -Path C:\sftp-drop\raw, C:\sftp-drop\archive
net user sftp-ingest "ChangeMe-R&D-only!" /add
```

### 3. Configure sshd (home-dir pattern — recommended on Windows)

OpenSSH chroot on Windows is strict. Use **home directory** + ACL instead of chroot:

Edit `C:\ProgramData\ssh\sshd_config` (admin):

```
Subsystem sftp sftp-server
Match User sftp-ingest
    ForceCommand internal-sftp
    AllowTcpForwarding no
    ChrootDirectory none
```

Set `sftp-ingest` home to `C:\sftp-drop\raw` (Properties → Profile → Home folder).

### 4. SSH key auth

```powershell
# As sftp-ingest (or copy keys manually)
mkdir C:\Users\sftp-ingest\.ssh
# Paste FileZilla/public key into authorized_keys
```

In `sshd_config` (global): `PasswordAuthentication no` for R&D.

Restart: `Restart-Service sshd`

### 5. FileZilla

| Field | Value |
|--------|--------|
| Protocol | SFTP |
| Host | `127.0.0.1` |
| Port | 22 |
| User | `sftp-ingest` |
| Logon | Key file |

Upload to `/` (maps to `C:\sftp-drop\raw\`).

### 6. Bridge to S3

```powershell
.\scripts\local-sftp-upload-to-s3.ps1 -WaitForStableSize
```

Optional watcher:

```powershell
.\scripts\watch-sftp-drop.ps1
```

## Atomic uploads (optional)

Have FileZilla upload to `filename.part`, then rename to `filename` when complete. Bridge skips `*.part` and `*.tmp`.

## Cost note

Phase 2b adds **no AWS resources**. Optionally set `enable_sftp = false` in `env/personal-apse1.tfvars` and `terraform apply` to stop EC2 SFTPGo while testing locally.

## Security

- Do not port-forward TCP 22 from the internet on your laptop
- Do not commit `env/local-upload.env` or SSH private keys

## Troubleshooting

| Issue | Check |
|-------|--------|
| `aws s3 cp` access denied | IAM user needs `s3:PutObject` on `bucket/raw/*` |
| Lambda not triggered | S3 key must be `raw/filename`, not bucket root |
| Chroot fails on Windows | Use home-dir pattern above |
| Duplicate Lambda logs | Re-upload overwrites same key; at-least-once is OK for R&D |

See [phase-2b-verification.md](phase-2b-verification.md) for acceptance checklist.
