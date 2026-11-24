variable "environment" {
  description = "Synthetic environment identifier used for resource naming and tagging."
  type        = string
  default     = "synthetic-prod"

  validation {
    condition     = length(trimspace(var.environment)) > 0
    error_message = "environment must not be empty."
  }
}

variable "aws_region" {
  description = "AWS region for the CloudWatch metric stream."
  type        = string
  default     = "us-east-1"
}

variable "newrelic_account_id" {
  description = "Synthetic placeholder New Relic account ID (override via TF_VAR_newrelic_account_id or NEW_RELIC_ACCOUNT_ID)."
  type        = number
  default     = 1234567
}

variable "newrelic_region" {
  description = "New Relic datacenter region: US or EU."
  type        = string
  default     = "US"

  validation {
    condition     = contains(["US", "EU"], var.newrelic_region)
    error_message = "newrelic_region must be US or EU."
  }
}

variable "metric_stream_role_arn" {
  description = "Synthetic IAM role ARN for the CloudWatch metric stream."
  type        = string
  default     = "arn:aws:iam::000000000000:role/synthetic-cw-metric-stream-role"
}

variable "metric_stream_firehose_arn" {
  description = "Synthetic Firehose delivery stream ARN for OpenTelemetry metrics."
  type        = string
  default     = "arn:aws:firehose:us-east-1:000000000000:deliverystream/synthetic-otel-metrics"
}
