variable "name_prefix" {
  description = "Name prefix used for SQS resources."
  type        = string
}

variable "queue_name" {
  description = "Logical name of the main SQS queue."
  type        = string
}

variable "visibility_timeout_seconds" {
  description = "How long a message stays invisible after a worker receives it."
  type        = number
  default     = 60

  validation {
    condition     = var.visibility_timeout_seconds >= 30 && var.visibility_timeout_seconds <= 43200
    error_message = "visibility_timeout_seconds must be between 30 seconds and 12 hours."
  }
}

variable "message_retention_seconds" {
  description = "How long SQS keeps messages if they are not deleted."
  type        = number
  default     = 345600

  validation {
    condition     = var.message_retention_seconds >= 60 && var.message_retention_seconds <= 1209600
    error_message = "message_retention_seconds must be between 1 minute and 14 days."
  }
}

variable "max_receive_count" {
  description = "How many times a message can fail before moving to the DLQ."
  type        = number
  default     = 5

  validation {
    condition     = var.max_receive_count >= 1 && var.max_receive_count <= 1000
    error_message = "max_receive_count must be between 1 and 1000."
  }
}

variable "tags" {
  description = "Common tags to apply to SQS resources."
  type        = map(string)
  default     = {}
}