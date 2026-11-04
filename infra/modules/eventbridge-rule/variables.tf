variable "name" {
  description = "Rule purpose name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,50}$", var.name))
    error_message = "name must be a lowercase slug."
  }
}

variable "description" {
  description = "Rule description."
  type        = string
}

variable "event_bus_name" {
  description = "Existing event bus name; ignored when create_event_bus is true."
  type        = string
  default     = "default"
}

variable "create_event_bus" {
  description = "Create a dedicated custom bus named after the rule."
  type        = bool
  default     = false
}

variable "event_pattern" {
  description = "Event pattern as a JSON string (jsonencode in the caller)."
  type        = string

  validation {
    condition     = can(jsondecode(var.event_pattern))
    error_message = "event_pattern must be valid JSON."
  }
}

variable "targets" {
  description = "Targets keyed by ID. Lambda permissions are created here; SQS targets grant events.amazonaws.com in the sqs-queue module."
  type = map(object({
    arn                    = string
    type                   = string
    dead_letter_queue_arn  = optional(string)
    maximum_retry_attempts = optional(number, 185)
    maximum_event_age_sec  = optional(number, 86400)
  }))

  validation {
    condition     = length(var.targets) > 0 && alltrue([for t in values(var.targets) : contains(["lambda", "sqs", "sns"], t.type)])
    error_message = "Declare at least one target of type lambda, sqs, or sns."
  }
}
