variable "aws_region" {
  description = "AWS region for all Phase 1 resources"
  type        = string
  default     = "ap-southeast-1"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "sftp-s3-glue-rd"
}

variable "bucket_name" {
  description = "Optional override for S3 bucket name (must be globally unique)"
  type        = string
  default     = null
}

variable "object_prefix" {
  description = "S3 object key prefix filter for EventBridge rule"
  type        = string
  default     = "raw/"
}

variable "lambda_runtime" {
  description = "Lambda runtime identifier"
  type        = string
  default     = "dotnet8"
}

variable "lambda_handler" {
  description = "Assembly-qualified Lambda handler"
  type        = string
  default     = "RdSuccessLogger::RdSuccessLogger.Function::FunctionHandler"
}

variable "lambda_architectures" {
  description = "Lambda CPU architecture"
  type        = list(string)
  default     = ["x86_64"]
}

variable "lambda_timeout" {
  description = "Lambda timeout in seconds"
  type        = number
  default     = 10
}

variable "lambda_memory" {
  description = "Lambda memory in MB"
  type        = number
  default     = 128
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags applied to supported resources"
  type        = map(string)
  default = {
    Project = "sftp-AWS-s3-glue"
    Phase   = "1-RD"
  }
}
