variable "name" {
  description = "Service name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name must be a lowercase slug."
  }
}

variable "cluster_arn" {
  description = "ECS cluster ARN from the ecs-cluster module."
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name from the ecs-cluster module."
  type        = string
}

variable "subnet_ids" {
  description = "Private application subnet IDs; tasks never receive public IPs."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Task security groups (normally the network application_security_group_id)."
  type        = list(string)
}

variable "image" {
  description = "Container image reference. Production requires an immutable @sha256 digest."
  type        = string
}

variable "cpu" {
  description = "Fargate task CPU units."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate task memory (MiB)."
  type        = number
  default     = 512
}

variable "cpu_architecture" {
  description = "X86_64 or ARM64."
  type        = string
  default     = "X86_64"

  validation {
    condition     = contains(["X86_64", "ARM64"], var.cpu_architecture)
    error_message = "cpu_architecture must be X86_64 or ARM64."
  }
}

variable "container_port" {
  description = "Container port exposed to the load balancer; null for workers."
  type        = number
  default     = null
}

variable "health_check_command" {
  description = "Container health check command (CMD-SHELL form); null relies on load-balancer checks."
  type        = list(string)
  default     = null
}

variable "environment_variables" {
  description = "Non-secret container environment variables."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Container secret environment variables mapped to Secrets Manager or SSM parameter ARNs."
  type        = map(string)
  default     = {}
}

variable "secret_kms_key_arns" {
  description = "KMS keys that encrypt the referenced secrets (decrypt granted to the execution role)."
  type        = set(string)
  default     = []
}

variable "task_role_policy_json" {
  description = "Least-privilege application IAM policy for the task role; null grants no AWS API access."
  type        = string
  default     = null
}

variable "readonly_root_filesystem" {
  description = "Mount the container root filesystem read-only."
  type        = bool
  default     = true
}

variable "desired_count" {
  description = "Initial desired task count (autoscaling adjusts afterwards)."
  type        = number
  default     = 2
}

variable "autoscaling" {
  description = "Target-tracking autoscaling on average CPU."
  type = object({
    min_capacity       = number
    max_capacity       = number
    target_cpu_percent = optional(number, 60)
  })
  default = { min_capacity = 2, max_capacity = 4 }

  validation {
    condition     = var.autoscaling.min_capacity >= 1 && var.autoscaling.max_capacity >= var.autoscaling.min_capacity
    error_message = "autoscaling requires 1 <= min_capacity <= max_capacity."
  }
}

variable "target_group_arn" {
  description = "Load-balancer target group ARN (target_type ip) or null."
  type        = string
  default     = null
}

variable "enable_execute_command" {
  description = "Allow ECS Exec; audited through the cluster exec log group. Keep false in production unless approved."
  type        = bool
  default     = false
}

variable "log_kms_key_arn" {
  description = "KMS key for the application log group."
  type        = string
}

variable "log_retention_days" {
  description = "Application log retention."
  type        = number
  default     = 30
}

variable "alarm_topic_arn" {
  description = "Operations SNS topic for service alarms."
  type        = string
}
