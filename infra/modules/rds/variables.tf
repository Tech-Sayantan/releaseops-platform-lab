variable "name_prefix" {
  description = "Name prefix used for RDS-related resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where RDS networking resources will be created."
  type        = string
}

variable "database_subnet_ids" {
  description = "Subnet IDs for the RDS DB subnet group."
  type        = list(string)

  validation {
    condition     = length(var.database_subnet_ids) >= 2
    error_message = "database_subnet_ids must contain at least two subnets for multi-AZ-ready RDS placement."
  }
}

variable "tags" {
  description = "Common tags to apply to RDS-related resources."
  type        = map(string)
  default     = {}
}