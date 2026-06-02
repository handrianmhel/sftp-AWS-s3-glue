resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.lambda_function_name}"
  retention_in_days = var.log_retention_days
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../../dist/lambda-publish"
  output_path = "${path.module}/../../dist/lambda.zip"
}

resource "aws_lambda_function" "success_logger" {
  function_name = local.lambda_function_name
  role          = aws_iam_role.lambda_exec.arn
  handler       = var.lambda_handler
  runtime       = var.lambda_runtime
  architectures = var.lambda_architectures

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  memory_size = var.lambda_memory
  timeout     = var.lambda_timeout

  depends_on = [aws_cloudwatch_log_group.lambda]
}

resource "aws_lambda_permission" "allow_eventbridge" {
  for_each = toset(var.object_prefixes)

  statement_id  = "AllowExecutionFromEventBridge-${local.eventbridge_rule_suffixes[each.value]}"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.success_logger.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_object_created[each.value].arn
}
