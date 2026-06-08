data "aws_caller_identity" "current" {}

locals {
  bucket_name = var.use_existing_bucket ? var.bucket_name : coalesce(
    var.bucket_name,
    "${var.name_prefix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  )

  lambda_function_name          = "${var.name_prefix}-success-logger"
  bucket_lister_function_name   = "${var.name_prefix}-bucket-lister"
  sftp_pull_function_name       = "${var.name_prefix}-sftp-pull"
  sftpgo_ec2_role_name          = "${var.name_prefix}-sftpgo-ec2"
  sftp_pull_ssm_prefix = var.sftp_pull_ssm_prefix != "" ? trim(var.sftp_pull_ssm_prefix, "/") : "${var.name_prefix}/sftp-pull"

  # SFTP virtual path /raw -> S3 prefix raw/
  sftp_virtual_folders = { for p in var.object_prefixes : trim(p, "/") => p }

  # Deterministic EventBridge rule name suffix per prefix (slashes -> dashes)
  eventbridge_rule_suffixes = {
    for prefix in var.object_prefixes :
    prefix => trim(replace(prefix, "/", "-"), "-")
  }
}
