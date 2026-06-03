# Environment configuration

Switch deploy targets using three knobs (no code edits):

1. **`AWS_PROFILE`** → ww/c AWS account/credentials Terraform uses
2. **`env/*.tfvars`** → region, bucket mode, prefix list (copy from `*.example`)
3. **`terraform workspace`** (optional) → separate state per target

## Quick start

```powershell
# 1. Copy example → real (gitignored)
cd c:\_codedev\test\integration\sftp-AWS-s3-glue
copy env\rcc-demo-apse1.tfvars.example env\rcc-demo-apse1.tfvars

# 2. Set profile and verify account
$env:AWS_PROFILE = "rcc-mhel"
aws sts get-caller-identity

# 3. Build Lambda + deploy
cd src\lambda\RdSuccessLogger
dotnet publish -c Release -r linux-x64 --self-contained false -o ../../../dist/lambda-publish
cd ..\..\..\infra\terraform
terraform init
terraform workspace select rcc-demo-apse1   # optional; create with: terraform workspace new rcc-demo-apse1
terraform plan  -var-file=..\..\env\rcc-demo-apse1.tfvars
terraform apply -var-file=..\..\env\rcc-demo-apse1.tfvars
```

## Example targets

| File | Mode | Bucket | Prefixes |
|------|------|--------|----------|
| `personal-apse1.tfvars.example` | Create new bucket | generated name | `raw/` |
| `rcc-demo-apse1.tfvars.example` | Existing bucket | `rccglobe-demo-bucket` | `public-folder/`, `restricted-folder/` |

## Credentials

See [aws-user-setup.md](aws-user-setup.md) for `~/.aws/credentials`, `~/.aws/config`, STS assume-role, and required IAM actions.

**Never commit** `env/*.tfvars` or access keys to this repository.

After deploy, test the manual S3 lister: `terraform output bucket_lister_function_name`. See the **BucketLister (manual invoke)** section in [README.md](../README.md).
