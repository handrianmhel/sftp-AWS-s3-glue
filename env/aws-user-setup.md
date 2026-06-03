# AWS user setup (user-operated only)

**AWS config folder:** `C:\Users\ASUS TUF\.aws`

| File | Purpose |
|------|---------|
| `credentials` | Access keys per named profile (or leave empty if using SSO/STS only) |
| `config` | Region, output, assume role (STS), SSO session settings |

---

## Step 1 — Verify AWS CLI

```powershell
aws --version
```

Install [AWS CLI v2](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) if missing.

---

## Step 2 — Authentication options

| Method | Best for | Keys in credentials? |
|--------|----------|----------------------|
| A. Access key profile | Quick lab / IAM user | Yes |
| B. STS assume role | User → deployment role | Base profile + `role_arn` in config |
| C. AWS SSO | Organization | No long-term keys; `aws sso login` |

Use option A or B for this project.

---

## Step 3 — Example profile: personal account

```powershell
aws configure --profile personal
```

Default region/output as you prefer.

---

## Step 4 — Example profile: RCC account (979437352248)

```powershell
aws configure --profile rcc-mhel
```

Suggested defaults: region `ap-southeast-1`, output `json`.

Verify:

```powershell
$env:AWS_PROFILE = "rcc-mhel"
aws sts get-caller-identity
```

Expect `"Account": "979437352248"` (or your target account).

---

## Step 5 — STS assume role (optional)

Use when your IAM user needs to assume a role with broader deploy rights. An administrator must create the role and trust policy first.

**`config` template (append locally):**

```ini
[profile personal]
region = us-east-1
output = json

[profile rcc-mhel]
region = ap-southeast-1
output = json

[profile rcc-mhel-deploy]
role_arn = arn:aws:iam::979437352248:role/REPLACE_ROLE_NAME
source_profile = rcc-mhel
region = ap-southeast-1
output = json
```

**`credentials` template (replace placeholders locally):**

```ini
[personal]
aws_access_key_id = REPLACE_ME
aws_secret_access_key = REPLACE_ME

[rcc-mhel]
aws_access_key_id = REPLACE_ME
aws_secret_access_key = REPLACE_ME
```

Test:

```powershell
$env:AWS_PROFILE = "rcc-mhel-deploy"
aws sts get-caller-identity
```

---

## Step 6 — Map profiles to Terraform var-files

| When testing… | `AWS_PROFILE` | Var-file (after copy example → `.tfvars`) |
|---------------|---------------|-------------------------------------------|
| New Terraform bucket + `raw/` | `personal` or `rcc-mhel` | `env\greenfield-apse1.tfvars` |
| Existing `rccglobe-demo-bucket` + demo prefixes | `rcc-mhel` (bucket owner account) | `env\rcc-demo-apse1.tfvars` |

```powershell
copy env\rcc-demo-apse1.tfvars.example env\rcc-demo-apse1.tfvars
# Edit env\rcc-demo-apse1.tfvars locally — never commit
```

---

## Step 7 — Terraform workspace (optional)

```powershell
$env:AWS_PROFILE = "rcc-mhel"
cd c:\_codedev\test\integration\sftp-AWS-s3-glue\infra\terraform
terraform init
terraform workspace new rcc-demo-apse1
terraform workspace select rcc-demo-apse1
```

---

## IAM actions (existing-bucket mode)

Deploying user/profile typically needs permission to:

- `s3:PutBucketNotification` (or equivalent) on the target bucket — enable EventBridge
- Create/manage EventBridge rules and targets
- Create/update Lambda functions and `lambda:InvokeFunction` (for EventBridge principal)
- `iam:PassRole` for the Lambda execution role
- CloudWatch Logs for the Lambda log group

Exact policies depend on your organization; scope to the bucket ARN and `name_prefix` resources where possible.

---

## Cross-account bucket

- **Same account**, different IAM user: use a profile with rights on `rccglobe-demo-bucket` + `use_existing_bucket = true`.
- **Different AWS account** (bucket owned elsewhere): cross-account EventBridge is **not** supported without additional resource policies. Deploy Terraform in the **bucket owner account** or request platform integration.

---

## Troubleshooting

| Problem | Check |
|---------|--------|
| Wrong account | `aws sts get-caller-identity` with same `AWS_PROFILE` as Terraform |
| Wrong region | Console region = `aws_region` in tfvars |
| `public-folder` in JSON is not the bucket name | Bucket is `rccglobe-demo-bucket`; `public-folder/` is a **prefix** |
| Access denied on bucket notification | IAM on bucket; same account as bucket owner |
