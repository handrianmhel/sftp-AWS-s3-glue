data "aws_caller_identity" "current" {}

locals {
  bucket_name = coalesce(
    var.bucket_name,
    "${var.name_prefix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  )

  lambda_function_name = "${var.name_prefix}-success-logger"
}
