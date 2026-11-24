resource "newrelic_nrql_alert_condition" "deadman" {
  account_id                     = var.account_id
  policy_id                      = var.policy_id
  type                           = "static"
  name                           = var.name
  description                    = var.description
  runbook_url                    = var.runbook_url
  enabled                        = var.enabled
  violation_time_limit_seconds   = var.violation_time_limit_seconds
  fill_option                    = "static"
  fill_value                     = 0
  aggregation_window             = var.aggregation_window_seconds
  aggregation_method             = var.aggregation_method
  aggregation_delay              = contains(["event_flow", "cadence"], var.aggregation_method) ? var.aggregation_delay_seconds : null
  aggregation_timer              = var.aggregation_method == "event_timer" ? var.aggregation_timer_seconds : null
  slide_by                       = var.slide_by_seconds
  expiration_duration            = var.expiration_duration_seconds
  open_violation_on_expiration   = true
  close_violations_on_expiration = true

  nrql {
    query = var.nrql_query
  }

  critical {
    operator              = "equals"
    threshold             = 0
    threshold_duration    = var.threshold_duration_seconds
    threshold_occurrences = "all"
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
  }
}
