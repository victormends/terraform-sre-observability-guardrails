output "alert_policy_id" {
  description = "ID of the synthetic New Relic alert policy."
  value       = newrelic_alert_policy.synthetic_platform.id
}

output "deadman_condition_id" {
  description = "Condition ID for the nightly-etl-worker deadman watchdog."
  value       = module.nightly_etl_deadman.id
}

output "distinct_session_condition_id" {
  description = "Condition ID for the checkout-api distinct session alert."
  value       = module.checkout_distinct_session_errors.id
}

output "cw_metric_stream_arn" {
  description = "ARN of the allowlist-filtered CloudWatch metric stream."
  value       = module.session_cache_cw_stream_filter.arn
}
