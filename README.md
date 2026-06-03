# sftp-AWS-s3-glue (R&D purposes)

Currently, this proves:
  
    → [ manual S3 Console upload (or via SFTP) under `raw/` path ]

      ├→ [ S3 EventBridge notification ]

        ├→ [ EventBridge rule ]

          ├→ [ .NET 8 Lambda ]

            ├→ [ CloudWatch Logs ] w/1 exact success line.

**Event path:** S3 → EventBridge → rule → Lambda.

Another is:

    ├→ [ S3 ]

        ├→ [ .NET 8 Lambda Manual Trigger Run (Currently bucket listing only) ]

## Prerequisites

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Terraform](https://www.terraform.io/downloads) ≥ 1.5
- AWS credentials configured (`AWS_PROFILE` or `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`) 
  - __**currently used my personal__
- Default region: **ap-southeast-1**

## Build and deploy

From the repository root:

```powershell
# 1. Build Lambda deployment packages
cd src/lambda/RdSuccessLogger
dotnet publish -c Release -r linux-x64 --self-contained false -o ../../../dist/lambda-publish
cd ../BucketLister
dotnet publish -c Release -r linux-x64 --self-contained false -o ../../../dist/bucket-lister-publish
cd ../../../infra/terraform

# 2. Configure variables (optional)
copy terraform.tfvars.example terraform.tfvars

# 3. Deploy (personal greenfield example)
terraform init
terraform workspace select default
terraform plan "-var-file=../../env/personal-apse1.tfvars"
terraform apply "-var-file=../../env/personal-apse1.tfvars"
```

Note the Terraform outputs: `bucket_name`, `lambda_function_name`, `bucket_lister_function_name`, `aws_region`.

For RCC demo bucket (existing bucket, same account): use `env/rcc-demo-apse1.tfvars` and profile `rcc-mhel`. See [env/README.md](env/README.md).

### Windows zip (manual alternative)

If you need to create the zip yourself instead of Terraform `archive_file`:

```powershell
cd dist/lambda-publish
Compress-Archive -Path * -DestinationPath ../lambda.zip -Force
```

Zip **contents** of the publish folder (DLLs at zip root), not the parent folder.

## Manual acceptance test

1. Open **AWS S3 Console** in **ap-southeast-1** (or your deployed region).
2. Open the bucket from `terraform output bucket_name`.
3. Navigate to the **`raw/`** folder/prefix and upload any file.
4. Wait up to **2 minutes**.
5. Open **CloudWatch Logs** → log group `/aws/lambda/<lambda_function_name>` → latest log stream.
6. Confirm this **exact** message (no extra punctuation):

   ```
   @@@ The raw/filename_uploaded_here file has been successfully uploaded last [MMM d, yyyy HH:MM:SS tt *format]. It is filesize_here MB. R&D S3-EventBridge-Lambda integration test successfully done. See event's detail below (next log).
   ```

## Negative test

1. Upload a file to the **bucket root** (not under `raw/`).
2. Wait 2 minutes.
3. Confirm Lambda **does not** run for that upload (no new invoke / no new success log line for that event).

The EventBridge rule filters on prefix `raw/` only.

## BucketLister (manual invoke)

Second Lambda that **lists S3 objects** in the stack bucket (`local.bucket_name`). It has **NO** EventBridge rule and **NO** S3 trigger. Invoke only from Console, CLI, or optional local test tool.

Set `enable_bucket_lister = false` in tfvars to skip deploying it.

### Build before apply

```powershell
cd src/lambda/BucketLister
dotnet publish -c Release -r linux-x64 --self-contained false -o ../../../dist/bucket-lister-publish
```

Rebuild `RdSuccessLogger` too if you changed that project (see Build and deploy above).

### Test A - AWS Console

1. Lambda → function from `terraform output -raw bucket_lister_function_name` (e.g. `sftp-s3-glue-rd-bucket-lister`).
2. **Test** tab → event: `{}` or `{"prefix":"raw/"}`.
3. **Test** → check execution result (JSON with `count`, `keys`).
4. **Monitor** → View CloudWatch logs for lines starting with `BucketLister:`.

### Test B - AWS CLI (invoke + logs in terminal)

```powershell
$env:AWS_PROFILE = "personal"   # or your default profile
$fn = terraform output -raw bucket_lister_function_name
$region = "ap-southeast-1"
cd infra/terraform

aws lambda invoke `
  --function-name $fn `
  --region $region `
  --payload '{"prefix":"raw/"}' `
  --cli-binary-format raw-in-base64-out `
  list-response.json

Get-Content list-response.json
aws logs tail "/aws/lambda/$fn" --region $region --since 5m
```

Invoke response = Lambda return payload; human-readable key lines = CloudWatch (`aws logs tail` or Console).

### Test C - Optional local (not required)

```powershell
dotnet tool install -g Amazon.Lambda.TestTool-8.0
$env:AWS_PROFILE = "personal"
$env:BUCKET_NAME = "<bucket from terraform output bucket_name>"
cd src/lambda/BucketLister
dotnet lambda-test-tool-8.0
```

Logs appear in the terminal locally; CloudWatch logs only when invoked in AWS.

### BucketLister troubleshooting

| Scenario | Note |
|----------|------|
| Greenfield `personal-apse1.tfvars` | Bucket created by stack; lister uses same name via `BUCKET_NAME` |
| Existing `rcc-demo-apse1.tfvars` | `use_existing_bucket = true` (lister still lists `local.bucket_name`) |
| Access denied on list | IAM role needs `s3:ListBucket` on that bucket; deploy profile must be bucket owner account |
| Cross-account bucket | Out of scope. Deploy in bucket owner account |
| Stale lister code | Re-run `dotnet publish` to `dist/bucket-lister-publish` before `terraform apply` |

Sanity: BucketLister should have **no** resource-based policy for `events.amazonaws.com`:

```powershell
aws lambda get-policy --function-name (terraform output -raw bucket_lister_function_name)
# Often empty / no policy — expected for manual-only functions
```

## Destroy

```powershell
cd infra/terraform
terraform destroy
```

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Lambda never runs | S3 EventBridge enabled (`eventbridge = true`)? Rule enabled? Bucket name & `raw/` prefix in rule pattern? Same region for bucket, rule & Lambda? |
| Lambda runs but no log | IAM logs permissions? Log group `/aws/lambda/<function-name>`? |
| Permission error on invoke | `aws_lambda_permission` w/ `events.amazonaws.com` & rule ARN |
| Lambda error on cold start | Handler string; runtime `dotnet8`; zip layout |
| .NET: wrong architecture | Publish w/ `-r linux-x64` & Lambda `architectures = ["x86_64"]`. Both must match |
| .NET: handler typo | Must be `RdSuccessLogger::RdSuccessLogger.Function::FunctionHandler` (assembly::namespace.class::method) |
| .NET: bad zip | Zip must contain DLLs at **root**, not wrapped in an extra folder |
| Stale code | Run `dotnet publish` again before `terraform apply` after C# changes |
| Upload to wrong path | Key must be `raw/test-rd.txt`, not bucket root |

### Optional CLI checks

```powershell
aws s3api get-bucket-notification-configuration --bucket BUCKET_NAME --region ap-southeast-1
aws events describe-rule --name RULE_NAME --region ap-southeast-1
aws logs tail /aws/lambda/FUNCTION_NAME --follow --region ap-southeast-1
```

## Project layout

```
├── README.md
├── infra/terraform/
├── src/lambda/RdSuccessLogger/
├── src/lambda/BucketLister/
└── dist/                    # gitignored — lambda-publish, bucket-lister-publish
```

**In scope:** S3 bucket, EventBridge, .NET 8 Lambda (logger + manual lister), CloudWatch Logs.

**Out of scope:** SFTP, Transfer Family, Glue, Step Functions, VPC, CI/CD, DLQ.

## Recent Personal Test

| Field | Value |
|-------|-------|
| Date | 2026-06-02 |
| AWS region | ap-southeast-1 |
| bucket_name | sftp-s3-glue-rd-573051981276-ap-southeast-1 |
| Object key (positive) | raw/test-rd.txt |
| lambda_function_name | sftp-s3-glue-rd-success-logger |
| Log group | /aws/lambda/sftp-s3-glue-rd-success-logger |
| Log stream | 2026/06/02/[$LATEST]9544f5722904411bb12068236d90d3f4 |
| Log timestamp (UTC) | 2026-06-02T04:52:45.623Z |

## Positive test (exact success message)

**Expected:** `   @@@ The raw/filename_uploaded_here file has been successfully uploaded last [MMM d, yyyy HH:MM:SS tt *format]. It is filesize_here MB. R&D S3-EventBridge-Lambda integration test successfully done. See event's detail below (next log).`

**Result:** **PASS**. message present in CloudWatch log event body.

## Negative test (bucket root upload)

**Action:** i uploaded `test-rd-root.txt` to bucket root (key `test-rd-root.txt`).

**Result:** **PASS**. no new Lambda success log after root upload; `lastEventTimestamp` unchanged.

## Event path confirmation

- S3 bucket notification: `eventbridge = true` only
- Lambda resource policy principal: `events.amazonaws.com` (rule ARN scoped)
- No `s3.amazonaws.com` on Lambda permission

## Deploy

Terraform apply completed successfully (account 573051981276, my personal).