resource "newrelic_nrql_alert_condition" "distinct_session" {
  account_id                   = var.account_id
  policy_id                    = var.policy_id
  type                         = var.condition_type
  baseline_direction           = var.condition_type == "baseline" ? var.baseline_direction : null
  name                         = var.name
  description                  = var.description
  runbook_url                  = var.runbook_url
  enabled                      = var.enabled
  violation_time_limit_seconds = var.violation_time_limit_seconds
  fill_option                  = var.fill_option
  fill_value                   = var.fill_option == "static" ? var.fill_value : null
  aggregation_window           = var.aggregation_window_seconds
  aggregation_method           = var.aggregation_method
  aggregation_delay            = contains(["event_flow", "cadence"], var.aggregation_method) ? var.aggregation_delay_seconds : null
  aggregation_timer            = var.aggregation_method == "event_timer" ? var.aggregation_timer_seconds : null
  slide_by                     = var.slide_by_seconds

  nrql {
    query = var.nrql_query
  }

  critical {
    operator              = var.critical_operator
    threshold             = var.critical_threshold
    threshold_duration    = var.critical_threshold_duration_seconds
    threshold_occurrences = var.critical_threshold_occurrences
  }

  dynamic "warning" {
    for_each = var.warning_threshold != null ? [var.warning_threshold] : []
    content {
      operator              = coalesce(var.warning_operator, var.critical_operator)
      threshold             = warning.value
      threshold_duration    = var.warning_threshold_duration_seconds
      threshold_occurrences = var.warning_threshold_occurrences
    }
  }

  lifecycle {
    precondition {
      condition     = var.aggregation_method != "event_flow" || var.aggregation_delay_seconds <= 1200
      error_message = "event_flow aggregation supports aggregation_delay_seconds up to 1200 seconds; use cadence for delays up to 3600 seconds."
    }

    precondition {
      condition = (
        var.slide_by_seconds == null
        ? true
        : (var.slide_by_seconds < var.aggregation_window_seconds && var.aggregation_window_seconds % var.slide_by_seconds == 0)
      )
      error_message = "slide_by_seconds must be strictly smaller than aggregation_window_seconds and divide evenly into it."
    }

    precondition {
      condition     = var.fill_option != "static" || var.fill_value != null
      error_message = "fill_value must be set when fill_option is static."
    }
  }
}
