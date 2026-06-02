data "aws_s3_bucket" "landing" {
  count  = var.use_existing_bucket ? 1 : 0
  bucket = var.bucket_name
}

resource "aws_s3_bucket" "landing" {
  count  = var.use_existing_bucket ? 0 : 1
  bucket = local.bucket_name
}

resource "aws_s3_bucket_public_access_block" "landing" {
  count  = var.use_existing_bucket ? 0 : 1
  bucket = aws_s3_bucket.landing[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_notification" "landing_eventbridge" {
  bucket      = var.use_existing_bucket ? data.aws_s3_bucket.landing[0].id : aws_s3_bucket.landing[0].id
  eventbridge = true
}
