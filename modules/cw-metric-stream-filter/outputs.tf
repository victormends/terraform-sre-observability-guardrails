output "arn" {
  description = "ARN of the CloudWatch metric stream."
  value       = aws_cloudwatch_metric_stream.this.arn
}

output "id" {
  description = "Identifier of the CloudWatch metric stream."
  value       = aws_cloudwatch_metric_stream.this.id
}

output "name" {
  description = "Name of the CloudWatch metric stream."
  value       = aws_cloudwatch_metric_stream.this.name
}

output "creation_date" {
  description = "Creation timestamp of the metric stream."
  value       = aws_cloudwatch_metric_stream.this.creation_date
}

output "state" {
  description = "Current state of the metric stream."
  value       = aws_cloudwatch_metric_stream.this.state
}
