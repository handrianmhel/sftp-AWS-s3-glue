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

output "bucket_lister_function_name" {
  description = "Manual-invoke S3 bucket lister Lambda function name"
  value       = var.enable_bucket_lister ? aws_lambda_function.bucket_lister[0].function_name : null
}

output "bucket_lister_arn" {
  description = "Manual-invoke S3 bucket lister Lambda ARN"
  value       = var.enable_bucket_lister ? aws_lambda_function.bucket_lister[0].arn : null
}

output "bucket_lister_log_group" {
  description = "CloudWatch log group for BucketLister"
  value       = var.enable_bucket_lister ? aws_cloudwatch_log_group.bucket_lister[0].name : null
}

output "sftp_host" {
  description = "Public host for SFTP (Elastic IP or instance public IP)"
  value = var.enable_sftp ? (
    var.sftp_use_elastic_ip ? aws_eip.sftpgo[0].public_ip : aws_instance.sftpgo[0].public_ip
  ) : null
}

output "sftp_port" {
  description = "SFTP port on the SFTPGo instance"
  value       = var.enable_sftp ? var.sftp_port : null
}

output "sftp_instance_id" {
  description = "EC2 instance ID running SFTPGo"
  value       = var.enable_sftp ? aws_instance.sftpgo[0].id : null
}

output "sftpgo_ec2_role_arn" {
  description = "IAM role ARN for SFTPGo EC2 (use in cross-account bucket policy template)"
  value       = var.enable_sftp ? aws_iam_role.sftpgo_ec2[0].arn : null
}

output "sftp_pull_function_name" {
  description = "Scheduled SFTP pull ingest Lambda function name"
  value       = var.enable_sftp_pull ? aws_lambda_function.sftp_pull[0].function_name : null
}

output "sftp_pull_schedule_rule_name" {
  description = "EventBridge schedule rule name for SFTP pull"
  value       = var.enable_sftp_pull ? aws_cloudwatch_event_rule.sftp_pull_schedule[0].name : null
}

output "sftp_pull_log_group" {
  description = "CloudWatch log group for SftpPullIngest"
  value       = var.enable_sftp_pull ? aws_cloudwatch_log_group.sftp_pull[0].name : null
}

output "sftp_pull_ssm_parameter_names" {
  description = "SSM parameter names for SFTP pull connection (populate after apply)"
  value = var.enable_sftp_pull ? {
    host        = aws_ssm_parameter.sftp_pull_host[0].name
    port        = aws_ssm_parameter.sftp_pull_port[0].name
    username    = aws_ssm_parameter.sftp_pull_username[0].name
    private_key = aws_ssm_parameter.sftp_pull_private_key[0].name
  } : null
}

output "sftp_pull_stub_host" {
  description = "Public IP (EIP) of the optional SFTP pull stub EC2 instance"
  value       = var.enable_sftp_pull_stub ? aws_eip.sftp_pull_stub[0].public_ip : null
}

output "sftp_pull_stub_instance_id" {
  description = "EC2 instance ID of the optional SFTP pull stub"
  value       = var.enable_sftp_pull_stub ? aws_instance.sftp_pull_stub[0].id : null
}

output "sftp_setup_notes" {
  description = "Post-deploy SFTP setup hints"
  value = var.enable_sftp ? join(" ", [
    "FileZilla: SFTP to sftp_host:sftp_port as user upload (see /root/sftpgo-setup-credentials.txt on instance via SSM).",
    "Add SSH public keys in SFTPGo admin UI.",
    "Upload to virtual paths matching object_prefixes (e.g. /raw/).",
    "EventBridge/Lambda unchanged."
  ]) : null
}
