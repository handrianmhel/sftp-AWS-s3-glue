data "aws_caller_identity" "current" {}

locals {
  bucket_name = var.use_existing_bucket ? var.bucket_name : coalesce(
    var.bucket_name,
    "${var.name_prefix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  )

  lambda_function_name = "${var.name_prefix}-success-logger"

  # Deterministic EventBridge rule name suffix per prefix (slashes -> dashes)
  eventbridge_rule_suffixes = {
    for prefix in var.object_prefixes :
    prefix => trim(replace(prefix, "/", "-"), "-")
  }
}
