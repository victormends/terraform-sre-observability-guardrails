output "id" {
  description = "New Relic NRQL alert condition ID."
  value       = newrelic_nrql_alert_condition.distinct_session.id
}

output "entity_guid" {
  description = "New Relic entity GUID for the distinct-session alert condition."
  value       = newrelic_nrql_alert_condition.distinct_session.entity_guid
}

output "name" {
  description = "Configured condition name."
  value       = newrelic_nrql_alert_condition.distinct_session.name
}

output "policy_id" {
  description = "Parent New Relic alert policy ID."
  value       = newrelic_nrql_alert_condition.distinct_session.policy_id
}
