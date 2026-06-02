# sftp-AWS-s3-glue (R&D purposes)

This proves:
→ [ **manual S3 Console upload (or via SFTP)** under `raw/` ]
→ [ **S3 EventBridge notification** ]
→ [ **EventBridge rule** ]
→ [ **.NET 8 Lambda** ]
→ [ **CloudWatch Logs** ] with one exact success line.

**Event path:** S3 → EventBridge → rule → Lambda.

## Prerequisites

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- [Terraform](https://www.terraform.io/downloads) ≥ 1.5
- AWS credentials configured (`AWS_PROFILE` or `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`) __**currently used my personal__
- Default region: **ap-southeast-1**

## Build and deploy

From the repository root:

```powershell
# 1. Build Lambda deployment package
cd src/lambda/RdSuccessLogger
dotnet publish -c Release -r linux-x64 --self-contained false -o ../../../dist/lambda-publish
cd ../../../infra/terraform

# 2. Configure variables (optional)
copy terraform.tfvars.example terraform.tfvars

# 3. Deploy
terraform init
terraform plan
terraform apply
```

Note the Terraform outputs: `bucket_name`, `lambda_function_name`, `aws_region`.

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
   R&D S3-EventBridge-Lambda integration test successfully done
   ```

## Negative test

1. Upload a file to the **bucket root** (not under `raw/`).
2. Wait 2 minutes.
3. Confirm Lambda **does not** run for that upload (no new invoke / no new success log line for that event).

The EventBridge rule filters on prefix `raw/` only.

## Destroy

```powershell
cd infra/terraform
terraform destroy
```

## Troubleshooting

| Symptom | Check |
|---------|--------|
| Lambda never runs | S3 EventBridge enabled (`eventbridge = true`)? Rule enabled? Bucket name and `raw/` prefix in rule pattern? Same region for bucket, rule, and Lambda? |
| Lambda runs but no log | IAM logs permissions? Log group `/aws/lambda/<function-name>`? |
| Permission error on invoke | `aws_lambda_permission` with `events.amazonaws.com` and rule ARN |
| Lambda error on cold start | Handler string; runtime `dotnet8`; zip layout |
| .NET: wrong architecture | Publish with `-r linux-x64` and Lambda `architectures = ["x86_64"]` — both must match |
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
└── dist/                    # gitignored — publish output
```

**In scope:** S3 bucket, EventBridge, .NET 8 Lambda, CloudWatch Logs.

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

**Expected:** `R&D S3-EventBridge-Lambda integration test successfully done`

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