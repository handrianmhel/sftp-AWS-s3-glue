data "aws_vpc" "default" {
  count = var.enable_sftp ? 1 : 0

  default = true
}

data "aws_subnets" "default" {
  count = var.enable_sftp ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}

data "aws_subnet" "sftpgo" {
  count = var.enable_sftp ? 1 : 0

  id = data.aws_subnets.default[0].ids[0]
}

data "aws_ami" "amazon_linux_2023" {
  count = var.enable_sftp ? 1 : 0

  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_security_group" "sftpgo" {
  count = var.enable_sftp ? 1 : 0

  name        = "${var.name_prefix}-sftpgo"
  description = "SFTPGo SFTP and optional admin UI"
  vpc_id      = data.aws_vpc.default[0].id

  ingress {
    description = "SFTP"
    from_port   = var.sftp_port
    to_port     = var.sftp_port
    protocol    = "tcp"
    cidr_blocks = var.sftp_allowed_cidr_blocks
  }

  dynamic "ingress" {
    for_each = var.sftp_enable_admin_ui_ingress ? [1] : []
    content {
      description = "SFTPGo web admin (initial setup)"
      from_port   = 8080
      to_port     = 8080
      protocol    = "tcp"
      cidr_blocks = var.sftp_allowed_cidr_blocks
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "sftpgo_ec2" {
  count = var.enable_sftp ? 1 : 0

  name = local.sftpgo_ec2_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "sftpgo_s3" {
  count = var.enable_sftp ? 1 : 0

  name = "${var.name_prefix}-sftpgo-s3"
  role = aws_iam_role.sftpgo_ec2[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketLocation"
        ]
        Resource = "arn:aws:s3:::${local.bucket_name}"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:AbortMultipartUpload",
          "s3:ListBucketMultipartUploads"
        ]
        Resource = "arn:aws:s3:::${local.bucket_name}/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "sftpgo" {
  count = var.enable_sftp ? 1 : 0

  name = "${var.name_prefix}-sftpgo-profile"
  role = aws_iam_role.sftpgo_ec2[0].name
}

resource "aws_cloudwatch_log_group" "sftpgo" {
  count = var.enable_sftp ? 1 : 0

  name              = "/aws/ec2/${var.name_prefix}-sftpgo"
  retention_in_days = var.log_retention_days
}

locals {
  sftp_prefixes_json = jsonencode([
    for name, prefix in local.sftp_virtual_folders : {
      name   = name
      prefix = prefix
    }
  ])

  sftpgo_user_data = var.enable_sftp ? templatefile("${path.module}/templates/sftpgo-user-data.sh.tpl", {
    bucket_name         = local.bucket_name
    aws_region          = var.aws_region
    sftpgo_version      = var.sftpgo_version
    sftp_admin_username = var.sftp_admin_username
    prefixes_json       = local.sftp_prefixes_json
    sftpgo_config = templatefile("${path.module}/templates/sftpgo.json.tpl", {
      sftp_port = var.sftp_port
    })
  }) : ""
}

resource "aws_instance" "sftpgo" {
  count = var.enable_sftp ? 1 : 0

  ami                    = data.aws_ami.amazon_linux_2023[0].id
  instance_type          = var.sftp_instance_type
  subnet_id              = data.aws_subnet.sftpgo[0].id
  vpc_security_group_ids = [aws_security_group.sftpgo[0].id]
  iam_instance_profile   = aws_iam_instance_profile.sftpgo[0].name

  associate_public_ip_address = true
  user_data_replace_on_change = true
  user_data                   = base64encode(local.sftpgo_user_data)

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  depends_on = [aws_cloudwatch_log_group.sftpgo]

  tags = {
    Name = "${var.name_prefix}-sftpgo"
  }
}

resource "aws_eip" "sftpgo" {
  count = var.enable_sftp && var.sftp_use_elastic_ip ? 1 : 0

  domain = "vpc"

  tags = {
    Name = "${var.name_prefix}-sftpgo-eip"
  }
}

resource "aws_eip_association" "sftpgo" {
  count = var.enable_sftp && var.sftp_use_elastic_ip ? 1 : 0

  instance_id   = aws_instance.sftpgo[0].id
  allocation_id = aws_eip.sftpgo[0].id
}
