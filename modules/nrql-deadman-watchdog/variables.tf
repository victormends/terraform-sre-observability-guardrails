variable "account_id" {
  description = "Optional New Relic account ID. Defaults to provider-level account_id when null."
  type        = number
  default     = null
}

variable "policy_id" {
  description = "New Relic alert policy ID that owns the deadman condition."
  type        = number
  nullable    = false

  validation {
    condition     = var.policy_id > 0
    error_message = "policy_id must be a positive integer."
  }
}

variable "name" {
  description = "Condition name displayed in New Relic Alerts."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name must not be empty."
  }
}

variable "description" {
  description = "Operational context and failure mode notes for responders."
  type        = string
  nullable    = false
  default     = "Deadman watchdog: alerts when expected heartbeat events drop to zero or expire."
}

variable "runbook_url" {
  description = "Optional runbook URL linked to alert notifications."
  type        = string
  default     = null
}

variable "enabled" {
  description = "Whether the alert condition is active."
  type        = bool
  nullable    = false
  default     = true
}

variable "nrql_query" {
  description = "NRQL query returning a numeric heartbeat count (must use SELECT ... FROM ...)."
  type        = string
  nullable    = false

  validation {
    condition     = can(regex("(?i)^\\s*SELECT\\s+.+\\s+FROM\\s+.+", var.nrql_query))
    error_message = "nrql_query must be a valid SELECT ... FROM ... NRQL query."
  }
}

variable "aggregation_window_seconds" {
  description = "Aggregation window length in seconds."
  type        = number
  nullable    = false
  default     = 300

  validation {
    condition     = var.aggregation_window_seconds >= 30 && var.aggregation_window_seconds <= 7200
    error_message = "aggregation_window_seconds must be between 30 and 7200 seconds."
  }
}

variable "aggregation_method" {
  description = "Streaming aggregation strategy: event_flow, event_timer, or cadence."
  type        = string
  nullable    = false
  default     = "event_flow"

  validation {
    condition     = contains(["event_flow", "event_timer", "cadence"], var.aggregation_method)
    error_message = "aggregation_method must be one of: event_flow, event_timer, cadence."
  }
}

variable "aggregation_delay_seconds" {
  description = "Delay in seconds used with event_flow (max 1200) or cadence (max 3600) aggregation."
  type        = number
  nullable    = false
  default     = 120

  validation {
    condition     = var.aggregation_delay_seconds >= 0 && var.aggregation_delay_seconds <= 3600
    error_message = "aggregation_delay_seconds must be between 0 and 3600 seconds."
  }
}

variable "aggregation_timer_seconds" {
  description = "Timer in seconds used with event_timer aggregation."
  type        = number
  nullable    = false
  default     = 60

  validation {
    condition     = var.aggregation_timer_seconds >= 5 && var.aggregation_timer_seconds <= 1200
    error_message = "aggregation_timer_seconds must be between 5 and 1200 seconds."
  }
}

variable "slide_by_seconds" {
  description = "Optional sliding window interval in seconds (must be smaller than and divide evenly into aggregation_window_seconds)."
  type        = number
  default     = null

  validation {
    condition     = var.slide_by_seconds == null ? true : var.slide_by_seconds >= 30
    error_message = "slide_by_seconds must be null or at least 30 seconds."
  }
}

variable "expiration_duration_seconds" {
  description = "Seconds without data before the loss-of-signal rule opens an incident."
  type        = number
  nullable    = false
  default     = 900

  validation {
    condition     = var.expiration_duration_seconds >= 30 && var.expiration_duration_seconds <= 172800
    error_message = "expiration_duration_seconds must be between 30 and 172800 seconds."
  }
}

variable "threshold_duration_seconds" {
  description = "Consecutive seconds at zero before triggering a critical violation."
  type        = number
  nullable    = false
  default     = 300

  validation {
    condition     = var.threshold_duration_seconds >= 60 && var.threshold_duration_seconds <= 7200 && var.threshold_duration_seconds % 60 == 0
    error_message = "threshold_duration_seconds must be a multiple of 60 between 60 and 7200."
  }
}

variable "violation_time_limit_seconds" {
  description = "Maximum open violation lifetime in seconds before automatic closure."
  type        = number
  nullable    = false
  default     = 86400

  validation {
    condition     = var.violation_time_limit_seconds >= 300 && var.violation_time_limit_seconds <= 2592000
    error_message = "violation_time_limit_seconds must be between 300 and 2592000 seconds."
  }
}
