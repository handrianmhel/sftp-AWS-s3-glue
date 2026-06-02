resource "aws_cloudwatch_event_rule" "s3_object_created" {
  for_each = toset(var.object_prefixes)

  name           = "${var.name_prefix}-s3-created-${local.eventbridge_rule_suffixes[each.value]}"
  description    = "Route S3 Object Created events under ${each.value} to Lambda"
  event_bus_name = "default"

  event_pattern = jsonencode({
    source      = ["aws.s3"]
    detail-type = ["Object Created"]
    detail = {
      bucket = {
        name = [local.bucket_name]
      }
      object = {
        key = [{ prefix = each.value }]
      }
    }
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  for_each = toset(var.object_prefixes)

  rule      = aws_cloudwatch_event_rule.s3_object_created[each.value].name
  target_id = "SuccessLoggerLambda"
  arn       = aws_lambda_function.success_logger.arn
}
