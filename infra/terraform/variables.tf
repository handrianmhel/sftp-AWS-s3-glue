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

variable "enable_sftp" {
  description = "Deploy EC2-hosted SFTPGo with S3 backend on local.bucket_name"
  type        = bool
  default     = true
}

variable "sftp_instance_type" {
  description = "EC2 instance type for SFTPGo"
  type        = string
  default     = "t3.small"
}

variable "sftp_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach SFTP (and optional admin UI) on the instance"
  type        = list(string)
  default     = []
}

variable "sftp_port" {
  description = "SFTP listen port on the instance"
  type        = number
  default     = 22
}

variable "sftp_admin_username" {
  description = "SFTPGo web admin username (created on first init; change password after deploy)"
  type        = string
  default     = "sftpadmin"
}

variable "sftp_use_elastic_ip" {
  description = "Associate an Elastic IP with the SFTPGo EC2 instance"
  type        = bool
  default     = true
}

variable "sftpgo_version" {
  description = "SFTPGo release version to install on EC2 (GitHub release tag without v prefix)"
  type        = string
  default     = "2.6.6"
}

variable "sftp_enable_admin_ui_ingress" {
  description = "Allow sftp_allowed_cidr_blocks to reach SFTPGo web admin on port 8080 for initial setup"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to supported resources"
  type        = map(string)
  default = {
    Project = "sftp-AWS-s3-glue"
    Phase   = "1-RD"
  }
}

variable "enable_sftp_pull" {
  description = "Deploy scheduled SftpPullIngest Lambda (SFTP client -> S3 raw/)"
  type        = bool
  default     = false
}

variable "sftp_pull_schedule" {
  description = "EventBridge schedule expression for SFTP pull Lambda"
  type        = string
  default     = "rate(5 minutes)"
}

variable "sftp_pull_remote_path" {
  description = "Remote SFTP directory to list and pull files from"
  type        = string
  default     = "/incoming"
}

variable "sftp_pull_s3_prefix" {
  description = "S3 key prefix for pulled files (must match EventBridge object_prefixes)"
  type        = string
  default     = "raw/"
}

variable "sftp_pull_max_file_bytes" {
  description = "Reject remote files larger than this many bytes"
  type        = number
  default     = 104857600
}

variable "sftp_pull_timeout" {
  description = "SftpPullIngest Lambda timeout in seconds"
  type        = number
  default     = 300
}

variable "sftp_pull_memory" {
  description = "SftpPullIngest Lambda memory in MB"
  type        = number
  default     = 512
}

variable "sftp_pull_use_vpc" {
  description = "Run SftpPullIngest Lambda inside a VPC (requires subnet and security group IDs)"
  type        = bool
  default     = false
}

variable "sftp_pull_vpc_subnet_ids" {
  description = "Subnet IDs when sftp_pull_use_vpc is true"
  type        = list(string)
  default     = []
}

variable "sftp_pull_vpc_security_group_ids" {
  description = "Security group IDs when sftp_pull_use_vpc is true"
  type        = list(string)
  default     = []
}

variable "sftp_pull_ssm_prefix" {
  description = "SSM parameter path prefix for SFTP pull secrets (leading slash optional)"
  type        = string
  default     = ""
}

variable "enable_sftp_pull_stub" {
  description = "Deploy optional EC2 OpenSSH SFTP stub for Phase 3 testing"
  type        = bool
  default     = false
}

variable "sftp_pull_stub_instance_type" {
  description = "EC2 instance type for SFTP pull stub"
  type        = string
  default     = "t3.micro"
}

variable "sftp_pull_stub_username" {
  description = "SFTP username created on the pull stub EC2 instance"
  type        = string
  default     = "sftp-pull"
}

variable "sftp_pull_allowed_cidr_blocks" {
  description = "CIDR blocks allowed to reach the SFTP pull stub on port 22"
  type        = list(string)
  default     = []
}

check "sftp_requires_cidr_when_enabled" {
  assert {
    condition     = !var.enable_sftp || length(var.sftp_allowed_cidr_blocks) > 0
    error_message = "sftp_allowed_cidr_blocks must be set when enable_sftp is true (e.g. YOUR.PUBLIC.IP/32 in env/*.tfvars)."
  }
}

check "sftp_pull_stub_requires_cidr_when_enabled" {
  assert {
    condition     = !var.enable_sftp_pull_stub || length(var.sftp_pull_allowed_cidr_blocks) > 0
    error_message = "sftp_pull_allowed_cidr_blocks must be set when enable_sftp_pull_stub is true."
  }
}

check "sftp_pull_vpc_requires_network" {
  assert {
    condition     = !var.sftp_pull_use_vpc || (length(var.sftp_pull_vpc_subnet_ids) > 0 && length(var.sftp_pull_vpc_security_group_ids) > 0)
    error_message = "sftp_pull_vpc_subnet_ids and sftp_pull_vpc_security_group_ids are required when sftp_pull_use_vpc is true."
  }
}
