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

output "eventbridge_rule_names" {
  description = "EventBridge rule names per object prefix"
  value       = { for prefix, rule in aws_cloudwatch_event_rule.s3_object_created : prefix => rule.name }
}

output "object_prefixes" {
  description = "Configured S3 object key prefix filters"
  value       = var.object_prefixes
}

output "use_existing_bucket" {
  description = "Whether Terraform uses an existing S3 bucket"
  value       = var.use_existing_bucket
}

output "lambda_handler" {
  description = "Assembly-qualified Lambda handler"
  value       = var.lambda_handler
}
