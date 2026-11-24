provider "aws" {
  region                      = var.aws_region
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true
}

provider "newrelic" {
  account_id = var.newrelic_account_id
  region     = var.newrelic_region
}

resource "newrelic_alert_policy" "synthetic_platform" {
  name                = "${var.environment}-observability-guardrails"
  incident_preference = "PER_CONDITION_AND_TARGET"
}

module "nightly_etl_deadman" {
  source = "../../modules/nrql-deadman-watchdog"

  account_id                  = var.newrelic_account_id
  policy_id                   = tonumber(newrelic_alert_policy.synthetic_platform.id)
  name                        = "${var.environment}-nightly-etl-worker-deadman"
  description                 = "Detects silent cron/Airflow/systemd stagnation for nightly-etl-worker."
  nrql_query                  = "SELECT count(*) FROM Log WHERE service_name = 'nightly-etl-worker' AND environment = 'synthetic-prod' AND event_type = 'heartbeat'"
  aggregation_window_seconds  = 300
  aggregation_method          = "event_flow"
  aggregation_delay_seconds   = 120
  expiration_duration_seconds = 900
  threshold_duration_seconds  = 300
}

module "checkout_distinct_session_errors" {
  source = "../../modules/nrql-distinct-session-alert"

  account_id                          = var.newrelic_account_id
  policy_id                           = tonumber(newrelic_alert_policy.synthetic_platform.id)
  name                                = "${var.environment}-checkout-api-affected-sessions"
  description                         = "Counts unique failing checkout sessions while excluding high-frequency /health probes."
  condition_type                      = "static"
  nrql_query                          = "SELECT uniqueCount(session_id) FROM TransactionError WHERE appName = 'checkout-api' AND environment = 'synthetic-prod' AND request.uri NOT LIKE '/health%' AND httpResponseCode >= 500"
  aggregation_window_seconds          = 60
  slide_by_seconds                    = 30
  critical_operator                   = "above"
  critical_threshold                  = 25
  critical_threshold_duration_seconds = 300
  warning_threshold                   = 10
  warning_threshold_duration_seconds  = 300
}

module "session_cache_cw_stream_filter" {
  source = "../../modules/cw-metric-stream-filter"

  name          = "${var.environment}-session-cache-stream"
  role_arn      = var.metric_stream_role_arn
  firehose_arn  = var.metric_stream_firehose_arn
  output_format = "opentelemetry0.7"

  include_filters = [
    {
      namespace    = "AWS/ElastiCache"
      metric_names = ["DatabaseMemoryUsagePercentage", "EngineCPUUtilization"]
    },
    {
      namespace    = "AWS/RDS"
      metric_names = ["CPUUtilization", "DatabaseConnections"]
    }
  ]

  tags = {
    Environment = var.environment
    Workload    = "session-cache"
    ManagedBy   = "terraform"
  }
}
