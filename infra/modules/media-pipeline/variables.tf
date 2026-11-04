variable "name" {
  description = "Pipeline purpose name."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.name))
    error_message = "name must be a lowercase slug."
  }
}

variable "input_bucket_name" {
  description = "Globally unique input (source media) bucket name."
  type        = string
}

variable "output_bucket_name" {
  description = "Globally unique output (renditions) bucket name."
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key for media buckets and status queues."
  type        = string
}

variable "input_expiration_days" {
  description = "Days before source objects expire from the input bucket; null keeps them."
  type        = number
  default     = 30
}

variable "output_transition_days" {
  description = "Days before outputs transition to STANDARD_IA."
  type        = number
  default     = 30
}

variable "queue_pricing_plan" {
  description = "ON_DEMAND (default) or RESERVED (requires a separately approved commitment)."
  type        = string
  default     = "ON_DEMAND"

  validation {
    condition     = contains(["ON_DEMAND"], var.queue_pricing_plan)
    error_message = "Only ON_DEMAND is supported; reserved queues need a separate cost approval and spec."
  }
}

variable "submitter_lambda_arn" {
  description = "Workload-owned Lambda that submits MediaConvert jobs when source objects arrive; null disables the trigger."
  type        = string
  default     = null
}

variable "input_suffixes" {
  description = "Object key suffixes that trigger job submission."
  type        = list(string)
  default     = [".mp4", ".mov", ".mxf"]
}

variable "alarm_topic_arn" {
  description = "Operations SNS topic for status-queue alarms."
  type        = string
}
