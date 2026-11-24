output "id" {
  description = "New Relic NRQL alert condition ID."
  value       = newrelic_nrql_alert_condition.deadman.id
}

output "entity_guid" {
  description = "New Relic entity GUID for the deadman condition."
  value       = newrelic_nrql_alert_condition.deadman.entity_guid
}

output "name" {
  description = "Configured condition name."
  value       = newrelic_nrql_alert_condition.deadman.name
}

output "policy_id" {
  description = "Parent New Relic alert policy ID."
  value       = newrelic_nrql_alert_condition.deadman.policy_id
}
