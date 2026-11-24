variable "name" {
  description = "CloudWatch metric stream name."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,255}$", var.name))
    error_message = "name must match ^[a-zA-Z0-9_-]{1,255}$."
  }
}

variable "role_arn" {
  description = "IAM role ARN allowing CloudWatch Metric Streams to write to Firehose."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:iam::[0-9]{12}:role/.+$", var.role_arn))
    error_message = "role_arn must be a valid IAM role ARN."
  }
}

variable "firehose_arn" {
  description = "Amazon Data Firehose delivery stream ARN."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("^arn:aws[a-z-]*:firehose:[a-z0-9-]+:[0-9]{12}:deliverystream/.+$", var.firehose_arn))
    error_message = "firehose_arn must be a valid Firehose delivery stream ARN."
  }
}

variable "output_format" {
  description = "Metric stream serialization format."
  type        = string
  nullable    = false
  default     = "opentelemetry0.7"

  validation {
    condition     = contains(["opentelemetry0.7", "opentelemetry1.0", "json"], var.output_format)
    error_message = "output_format must be one of: opentelemetry0.7, opentelemetry1.0, json."
  }
}

variable "include_filters" {
  description = "Strict allowlist of CloudWatch namespaces and metric names to stream. Empty list or empty metric_names are rejected to block unbounded telemetry ingestion."
  type = list(object({
    namespace    = string
    metric_names = list(string)
  }))
  nullable = false

  validation {
    condition = (
      length(var.include_filters) > 0 &&
      alltrue([
        for f in var.include_filters : (
          length(trimspace(f.namespace)) > 0 &&
          length(f.metric_names) > 0 &&
          alltrue([for m in f.metric_names : length(trimspace(m)) > 0])
        )
      ])
    )
    error_message = "include_filters must contain at least one filter with a non-empty namespace and non-empty metric_names."
  }
}

variable "tags" {
  description = "Resource tags applied to the CloudWatch metric stream."
  type        = map(string)
  nullable    = false
  default     = {}
}
