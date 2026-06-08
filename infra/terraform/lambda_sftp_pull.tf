resource "aws_cloudwatch_log_group" "sftp_pull" {
  count = var.enable_sftp_pull ? 1 : 0

  name              = "/aws/lambda/${local.sftp_pull_function_name}"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role" "sftp_pull_exec" {
  count = var.enable_sftp_pull ? 1 : 0

  name = "${var.name_prefix}-sftp-pull-exec"

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

resource "aws_iam_role_policy" "sftp_pull" {
  count = var.enable_sftp_pull ? 1 : 0

  name = "${var.name_prefix}-sftp-pull-policy"
  role = aws_iam_role.sftp_pull_exec[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Effect = "Allow"
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ]
          Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${local.sftp_pull_function_name}*"
        },
        {
          Effect = "Allow"
          Action = [
            "s3:PutObject",
            "s3:AbortMultipartUpload"
          ]
          Resource = "arn:aws:s3:::${local.bucket_name}/${trim(var.sftp_pull_s3_prefix, "/")}/*"
        },
        {
          Effect = "Allow"
          Action = [
            "s3:ListBucket"
          ]
          Resource = "arn:aws:s3:::${local.bucket_name}"
          Condition = {
            StringLike = {
              "s3:prefix" = ["${trim(var.sftp_pull_s3_prefix, "/")}/*"]
            }
          }
        },
        {
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:HeadObject"
          ]
          Resource = "arn:aws:s3:::${local.bucket_name}/${trim(var.sftp_pull_s3_prefix, "/")}/*"
        },
        {
          Effect = "Allow"
          Action = [
            "ssm:GetParameter"
          ]
          Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/${local.sftp_pull_ssm_prefix}/*"
        }
      ],
      var.sftp_pull_use_vpc ? [
        {
          Effect = "Allow"
          Action = [
            "ec2:CreateNetworkInterface",
            "ec2:DescribeNetworkInterfaces",
            "ec2:DeleteNetworkInterface",
            "ec2:AssignPrivateIpAddresses",
            "ec2:UnassignPrivateIpAddresses"
          ]
          Resource = "*"
        }
      ] : []
    )
  })
}

resource "aws_ssm_parameter" "sftp_pull_host" {
  count = var.enable_sftp_pull ? 1 : 0

  name  = "/${local.sftp_pull_ssm_prefix}/host"
  type  = "String"
  value = "REPLACE_ME"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "sftp_pull_port" {
  count = var.enable_sftp_pull ? 1 : 0

  name  = "/${local.sftp_pull_ssm_prefix}/port"
  type  = "String"
  value = "22"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "sftp_pull_username" {
  count = var.enable_sftp_pull ? 1 : 0

  name  = "/${local.sftp_pull_ssm_prefix}/username"
  type  = "String"
  value = "sftp-pull"

  lifecycle {
    ignore_changes = [value]
  }
}

resource "aws_ssm_parameter" "sftp_pull_private_key" {
  count = var.enable_sftp_pull ? 1 : 0

  name  = "/${local.sftp_pull_ssm_prefix}/private-key"
  type  = "SecureString"
  value = "REPLACE_ME"

  lifecycle {
    ignore_changes = [value]
  }
}

data "archive_file" "sftp_pull_zip" {
  count = var.enable_sftp_pull ? 1 : 0

  type        = "zip"
  source_dir  = "${path.module}/../../dist/sftp-pull-publish"
  output_path = "${path.module}/../../dist/sftp-pull.zip"
}

resource "aws_lambda_function" "sftp_pull" {
  count = var.enable_sftp_pull ? 1 : 0

  function_name                  = local.sftp_pull_function_name
  role                           = aws_iam_role.sftp_pull_exec[0].arn
  handler                        = "SftpPullIngest::SftpPullIngest.Function::FunctionHandler"
  runtime                        = var.lambda_runtime
  architectures                  = var.lambda_architectures
  reserved_concurrent_executions = 1

  filename         = data.archive_file.sftp_pull_zip[0].output_path
  source_code_hash = data.archive_file.sftp_pull_zip[0].output_base64sha256

  memory_size = var.sftp_pull_memory
  timeout     = var.sftp_pull_timeout

  environment {
    variables = {
      BUCKET_NAME     = local.bucket_name
      S3_PREFIX       = var.sftp_pull_s3_prefix
      REMOTE_PATH     = var.sftp_pull_remote_path
      MAX_FILE_BYTES  = tostring(var.sftp_pull_max_file_bytes)
      SSM_PREFIX      = "/${local.sftp_pull_ssm_prefix}"
    }
  }

  dynamic "vpc_config" {
    for_each = var.sftp_pull_use_vpc ? [1] : []
    content {
      subnet_ids         = var.sftp_pull_vpc_subnet_ids
      security_group_ids = var.sftp_pull_vpc_security_group_ids
    }
  }

  depends_on = [aws_cloudwatch_log_group.sftp_pull]
}

resource "aws_cloudwatch_event_rule" "sftp_pull_schedule" {
  count = var.enable_sftp_pull ? 1 : 0

  name                = "${var.name_prefix}-sftp-pull-schedule"
  description         = "Scheduled SFTP pull ingest"
  schedule_expression = var.sftp_pull_schedule
}

resource "aws_cloudwatch_event_target" "sftp_pull" {
  count = var.enable_sftp_pull ? 1 : 0

  rule      = aws_cloudwatch_event_rule.sftp_pull_schedule[0].name
  target_id = "sftp-pull-lambda"
  arn       = aws_lambda_function.sftp_pull[0].arn
}

resource "aws_lambda_permission" "sftp_pull_schedule" {
  count = var.enable_sftp_pull ? 1 : 0

  statement_id  = "AllowExecutionFromEventBridgeSchedule"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sftp_pull[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.sftp_pull_schedule[0].arn
}
