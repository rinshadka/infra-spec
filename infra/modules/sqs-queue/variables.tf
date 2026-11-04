variable "name" {
  description = "Queue purpose name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,50}$", var.name))
    error_message = "name must be a lowercase slug."
  }
}

variable "fifo" {
  description = "Create FIFO queues (ordering and exactly-once processing within a message group)."
  type        = bool
  default     = false
}

variable "visibility_timeout_seconds" {
  description = "Visibility timeout; set to at least six times the consumer Lambda timeout."
  type        = number
  default     = 180
}

variable "message_retention_seconds" {
  description = "Source queue retention (default 4 days)."
  type        = number
  default     = 345600
}

variable "max_receive_count" {
  description = "Receives before a message moves to the dead-letter queue."
  type        = number
  default     = 5

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "max_receive_count must be 1-1000."
  }
}

variable "kms_key_arn" {
  description = "KMS key for SSE-KMS; publishers and consumers need kms:GenerateDataKey/Decrypt on it."
  type        = string
}

variable "publisher_service_principals" {
  description = "AWS services allowed to send messages, keyed by service principal, with exact source ARNs."
  type        = map(set(string))
  default     = {}
}

variable "oldest_message_age_alarm_seconds" {
  description = "Alarm when the oldest message age exceeds this many seconds."
  type        = number
  default     = 900
}

variable "alarm_topic_arn" {
  description = "Operations SNS topic for DLQ and backlog alarms."
  type        = string
}
