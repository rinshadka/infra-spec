output "queue_arn" {
  description = "Source queue ARN."
  value       = aws_sqs_queue.this.arn
}

output "queue_url" {
  description = "Source queue URL."
  value       = aws_sqs_queue.this.id
}

output "queue_name" {
  description = "Source queue name."
  value       = aws_sqs_queue.this.name
}

output "dlq_arn" {
  description = "Dead-letter queue ARN."
  value       = aws_sqs_queue.dlq.arn
}

output "dlq_url" {
  description = "Dead-letter queue URL (redrive source)."
  value       = aws_sqs_queue.dlq.id
}
