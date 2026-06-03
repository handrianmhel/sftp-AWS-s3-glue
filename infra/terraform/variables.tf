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
  description = "S3 bucket name. Required when use_existing_bucket is true. Optional override when creating a new bucket."
  type        = string
  default     = null

  validation {
    condition     = !var.use_existing_bucket || (var.bucket_name != null && var.bucket_name != "")
    error_message = "bucket_name must be set when use_existing_bucket is true."
  }
}

variable "object_prefixes" {
  description = "S3 object key prefixes for EventBridge rules (trailing slash required, e.g. raw/)"
  type        = list(string)
  default     = ["raw/"]

  validation {
    condition     = length(var.object_prefixes) > 0
    error_message = "object_prefixes must contain at least one prefix."
  }
}

variable "use_existing_bucket" {
  description = "When true, use an existing S3 bucket (var.bucket_name) instead of creating a new bucket"
  type        = bool
  default     = false
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

variable "enable_bucket_lister" {
  description = "Deploy the manual-invoke S3 bucket lister Lambda"
  type        = bool
  default     = true
}

variable "bucket_lister_timeout" {
  description = "BucketLister Lambda timeout in seconds"
  type        = number
  default     = 30
}

variable "bucket_lister_memory" {
  description = "BucketLister Lambda memory in MB"
  type        = number
  default     = 256
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
