variable "account_id" {
  description = "Optional New Relic account ID. Defaults to provider-level account_id when null."
  type        = number
  default     = null
}

variable "policy_id" {
  description = "New Relic alert policy ID that owns this condition."
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
  description = "Operational summary explaining distinct-entity or ratio isolation intent."
  type        = string
  nullable    = false
  default     = "Distinct session alert isolating affected users/sessions from high-volume synthetic or health-check traffic."
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

variable "condition_type" {
  description = "NRQL condition evaluation type: static or baseline."
  type        = string
  nullable    = false
  default     = "static"

  validation {
    condition     = contains(["static", "baseline"], var.condition_type)
    error_message = "condition_type must be either static or baseline."
  }
}

variable "baseline_direction" {
  description = "Anomaly direction when condition_type is baseline."
  type        = string
  nullable    = false
  default     = "upper_only"

  validation {
    condition     = contains(["lower_only", "upper_and_lower", "upper_only"], var.baseline_direction)
    error_message = "baseline_direction must be one of: lower_only, upper_and_lower, upper_only."
  }
}

variable "nrql_query" {
  description = "NRQL query using uniqueCount(...) or filter(...) so high-volume health checks do not dilute error ratios."
  type        = string
  nullable    = false

  validation {
    condition = (
      can(regex("(?i)^\\s*SELECT\\s+.+\\s+FROM\\s+.+", var.nrql_query)) &&
      can(regex("(?i)(uniqueCount|filter)\\s*\\(", var.nrql_query))
    )
    error_message = "nrql_query must be a valid SELECT ... FROM ... query using uniqueCount(...) or filter(...)."
  }
}

variable "aggregation_window_seconds" {
  description = "Aggregation window length in seconds."
  type        = number
  nullable    = false
  default     = 60

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
  default     = 30

  validation {
    condition     = var.slide_by_seconds == null ? true : var.slide_by_seconds >= 30
    error_message = "slide_by_seconds must be null or at least 30 seconds."
  }
}

variable "fill_option" {
  description = "Gap-filling strategy for missing data windows: none, last_value, or static."
  type        = string
  nullable    = false
  default     = "none"

  validation {
    condition     = contains(["none", "last_value", "static"], var.fill_option)
    error_message = "fill_option must be one of: none, last_value, static."
  }
}

variable "fill_value" {
  description = "Numeric value injected when fill_option is static."
  type        = number
  default     = null
}

variable "violation_time_limit_seconds" {
  description = "Maximum open violation lifetime in seconds before automatic closure."
  type        = number
  nullable    = false
  default     = 259200

  validation {
    condition     = var.violation_time_limit_seconds >= 300 && var.violation_time_limit_seconds <= 2592000
    error_message = "violation_time_limit_seconds must be between 300 and 2592000 seconds."
  }
}

variable "critical_operator" {
  description = "Comparison operator for the critical threshold."
  type        = string
  nullable    = false
  default     = "above"

  validation {
    condition     = contains(["above", "above_or_equals", "below", "below_or_equals", "equals", "not_equals"], var.critical_operator)
    error_message = "critical_operator must be a valid New Relic threshold operator."
  }
}

variable "critical_threshold" {
  description = "Numeric threshold for critical incidents (distinct count, ratio, or baseline standard deviations)."
  type        = number
  nullable    = false

  validation {
    condition     = var.critical_threshold >= 0
    error_message = "critical_threshold must be non-negative."
  }
}

variable "critical_threshold_duration_seconds" {
  description = "Duration in seconds the critical threshold must be breached."
  type        = number
  nullable    = false
  default     = 300

  validation {
    condition     = var.critical_threshold_duration_seconds >= 60 && var.critical_threshold_duration_seconds <= 7200 && var.critical_threshold_duration_seconds % 60 == 0
    error_message = "critical_threshold_duration_seconds must be a multiple of 60 between 60 and 7200."
  }
}

variable "critical_threshold_occurrences" {
  description = "Evaluation occurrences required to breach critical: all or at_least_once."
  type        = string
  nullable    = false
  default     = "all"

  validation {
    condition     = contains(["all", "at_least_once"], var.critical_threshold_occurrences)
    error_message = "critical_threshold_occurrences must be either all or at_least_once."
  }
}

variable "warning_operator" {
  description = "Optional comparison operator for the warning threshold. Defaults to critical_operator when null."
  type        = string
  default     = null

  validation {
    condition = (
      var.warning_operator == null
      ? true
      : contains(["above", "above_or_equals", "below", "below_or_equals", "equals", "not_equals"], var.warning_operator)
    )
    error_message = "warning_operator must be null or a valid New Relic threshold operator."
  }
}

variable "warning_threshold" {
  description = "Optional numeric threshold for warning notifications. Omit (null) to disable warning tier."
  type        = number
  default     = null

  validation {
    condition     = var.warning_threshold == null ? true : var.warning_threshold >= 0
    error_message = "warning_threshold must be null or non-negative."
  }
}

variable "warning_threshold_duration_seconds" {
  description = "Duration in seconds the warning threshold must be breached."
  type        = number
  nullable    = false
  default     = 300

  validation {
    condition     = var.warning_threshold_duration_seconds >= 60 && var.warning_threshold_duration_seconds <= 7200 && var.warning_threshold_duration_seconds % 60 == 0
    error_message = "warning_threshold_duration_seconds must be a multiple of 60 between 60 and 7200."
  }
}

variable "warning_threshold_occurrences" {
  description = "Evaluation occurrences required to breach warning: all or at_least_once."
  type        = string
  nullable    = false
  default     = "all"

  validation {
    condition     = contains(["all", "at_least_once"], var.warning_threshold_occurrences)
    error_message = "warning_threshold_occurrences must be either all or at_least_once."
  }
}
