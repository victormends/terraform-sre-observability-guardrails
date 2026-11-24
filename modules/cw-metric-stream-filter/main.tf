resource "aws_cloudwatch_metric_stream" "this" {
  name          = var.name
  role_arn      = var.role_arn
  firehose_arn  = var.firehose_arn
  output_format = var.output_format

  # Strict allowlist only (mutually exclusive with exclude_filter in AWS).
  dynamic "include_filter" {
    for_each = var.include_filters
    content {
      namespace    = include_filter.value.namespace
      metric_names = include_filter.value.metric_names
    }
  }

  tags = var.tags
}
