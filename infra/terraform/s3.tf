resource "aws_s3_bucket" "landing" {
  bucket = local.bucket_name
}

resource "aws_s3_bucket_public_access_block" "landing" {
  bucket = aws_s3_bucket.landing.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_notification" "landing_eventbridge" {
  bucket      = aws_s3_bucket.landing.id
  eventbridge = true
}
