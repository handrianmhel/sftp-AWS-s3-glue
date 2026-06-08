data "aws_vpc" "sftp_pull_stub" {
  count = var.enable_sftp_pull_stub ? 1 : 0

  default = true
}

data "aws_subnets" "sftp_pull_stub" {
  count = var.enable_sftp_pull_stub ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.sftp_pull_stub[0].id]
  }
}

data "aws_subnet" "sftp_pull_stub" {
  count = var.enable_sftp_pull_stub ? 1 : 0

  id = data.aws_subnets.sftp_pull_stub[0].ids[0]
}

data "aws_ami" "sftp_pull_stub_al2023" {
  count = var.enable_sftp_pull_stub ? 1 : 0

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

resource "aws_security_group" "sftp_pull_stub" {
  count = var.enable_sftp_pull_stub ? 1 : 0

  name        = "${var.name_prefix}-sftp-pull-stub"
  description = "OpenSSH SFTP stub for Phase 3 pull Lambda testing"
  vpc_id      = data.aws_vpc.sftp_pull_stub[0].id

  ingress {
    description = "SSH/SFTP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.sftp_pull_allowed_cidr_blocks
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_iam_role" "sftp_pull_stub_ec2" {
  count = var.enable_sftp_pull_stub ? 1 : 0

  name = "${var.name_prefix}-sftp-pull-stub-ec2"

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

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "sftp_pull_stub_ssm" {
  count = var.enable_sftp_pull_stub ? 1 : 0

  role       = aws_iam_role.sftp_pull_stub_ec2[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "sftp_pull_stub" {
  count = var.enable_sftp_pull_stub ? 1 : 0

  name = "${var.name_prefix}-sftp-pull-stub-profile"
  role = aws_iam_role.sftp_pull_stub_ec2[0].name
}

locals {
  sftp_pull_stub_user_data = var.enable_sftp_pull_stub ? templatefile("${path.module}/templates/sftp-pull-stub-user-data.sh.tpl", {
    sftp_username  = var.sftp_pull_stub_username
    incoming_path  = var.sftp_pull_remote_path
  }) : null
}

resource "aws_instance" "sftp_pull_stub" {
  count = var.enable_sftp_pull_stub ? 1 : 0

  ami                    = data.aws_ami.sftp_pull_stub_al2023[0].id
  instance_type          = var.sftp_pull_stub_instance_type
  subnet_id              = data.aws_subnet.sftp_pull_stub[0].id
  vpc_security_group_ids = [aws_security_group.sftp_pull_stub[0].id]
  iam_instance_profile   = aws_iam_instance_profile.sftp_pull_stub[0].name
  user_data              = local.sftp_pull_stub_user_data

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-sftp-pull-stub"
  })
}

resource "aws_eip" "sftp_pull_stub" {
  count = var.enable_sftp_pull_stub ? 1 : 0

  domain = "vpc"
  tags   = var.tags
}

resource "aws_eip_association" "sftp_pull_stub" {
  count = var.enable_sftp_pull_stub ? 1 : 0

  instance_id   = aws_instance.sftp_pull_stub[0].id
  allocation_id = aws_eip.sftp_pull_stub[0].id
}
