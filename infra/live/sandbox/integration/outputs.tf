output "queue_url" {
  description = "Source queue URL."
  value       = module.queue.queue_url
}

output "dlq_url" {
  description = "Dead-letter queue URL (redrive source after fixes)."
  value       = module.queue.dlq_url
}

output "consumer_function_name" {
  description = "Consumer function name."
  value       = module.consumer.function_name
}

output "rule_arn" {
  description = "Routing rule ARN."
  value       = module.route.rule_arn
}
