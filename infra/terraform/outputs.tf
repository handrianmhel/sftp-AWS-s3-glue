output "bucket_name" {
  description = "Landing bucket for console uploads"
  value       = local.bucket_name
}

output "aws_region" {
  description = "Deployed AWS region"
  value       = var.aws_region
}

output "lambda_function_name" {
  description = "Lambda function name for CloudWatch log navigation"
  value       = aws_lambda_function.success_logger.function_name
}

output "eventbridge_rule_name" {
  description = "EventBridge rule name for debugging"
  value       = aws_cloudwatch_event_rule.s3_object_created.name
}

output "object_prefix" {
  description = "Object key prefix filter (e.g. raw/)"
  value       = var.object_prefix
}

output "lambda_handler" {
  description = "Assembly-qualified Lambda handler"
  value       = var.lambda_handler
}
