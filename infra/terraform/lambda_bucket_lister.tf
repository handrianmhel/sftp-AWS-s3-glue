resource "aws_cloudwatch_log_group" "bucket_lister" {
  count = var.enable_bucket_lister ? 1 : 0

  name              = "/aws/lambda/${local.bucket_lister_function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role" "bucket_lister_exec" {
  count = var.enable_bucket_lister ? 1 : 0

  name = "${var.name_prefix}-bucket-lister-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "bucket_lister" {
  count = var.enable_bucket_lister ? 1 : 0

  name = "${var.name_prefix}-bucket-lister-policy"
  role = aws_iam_role.bucket_lister_exec[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.bucket_lister_function_name}*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket"
        ]
        Resource = "arn:aws:s3:::${local.bucket_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetBucketLocation"
        ]
        Resource = "arn:aws:s3:::${local.bucket_name}"
      }
    ]
  })
}

data "archive_file" "bucket_lister_zip" {
  count = var.enable_bucket_lister ? 1 : 0

  type        = "zip"
  source_dir  = "${path.module}/../../dist/bucket-lister-publish"
  output_path = "${path.module}/../../dist/bucket-lister.zip"
}

resource "aws_lambda_function" "bucket_lister" {
  count = var.enable_bucket_lister ? 1 : 0

  function_name = local.bucket_lister_function_name
  role          = aws_iam_role.bucket_lister_exec[0].arn
  handler       = "BucketLister::BucketLister.Function::FunctionHandler"
  runtime       = var.lambda_runtime
  architectures = var.lambda_architectures

  filename         = data.archive_file.bucket_lister_zip[0].output_path
  source_code_hash = data.archive_file.bucket_lister_zip[0].output_base64sha256

  memory_size = var.bucket_lister_memory
  timeout     = var.bucket_lister_timeout

  environment {
    variables = {
      BUCKET_NAME = local.bucket_name
    }
  }

  depends_on = [aws_cloudwatch_log_group.bucket_lister]
}
