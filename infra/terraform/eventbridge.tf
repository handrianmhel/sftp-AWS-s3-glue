resource "aws_cloudwatch_event_rule" "s3_object_created" {
  name           = "${var.name_prefix}-s3-object-created"
  description    = "Route S3 Object Created events under ${var.object_prefix} to Lambda"
  event_bus_name = "default"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [local.bucket_name]
      }
      object = {
        key = [{ prefix = var.object_prefix }]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.s3_object_created.name
  target_id = "SuccessLoggerLambda"
  arn       = aws_lambda_function.success_logger.arn
}
