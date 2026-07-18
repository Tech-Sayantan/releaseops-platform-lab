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
variable "db_master_username" {
  description = "Master username for the ReleaseOps PostgreSQL database."
  type        = string
  default     = "releaseops_admin"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{2,31}$", var.db_master_username))
    error_message = "db_master_username must start with a letter and contain only letters, numbers, and underscores."
  }
}

variable "db_name" {
  description = "Initial database name for ReleaseOps."
  type        = string
  default     = "releaseops"

  validation {
    condition     = can(regex("^[a-zA-Z][a-zA-Z0-9_]{2,63}$", var.db_name))
    error_message = "db_name must start with a letter and contain only letters, numbers, and underscores."
  }
}
variable "db_instance_class" {
  description = "RDS instance class for the PostgreSQL database."
  type        = string
  default     = "db.t4g.micro"
}

variable "db_allocated_storage_gb" {
  description = "Allocated storage size in GB for PostgreSQL."
  type        = number
  default     = 20

  validation {
    condition     = var.db_allocated_storage_gb >= 20 && var.db_allocated_storage_gb <= 100
    error_message = "db_allocated_storage_gb must be between 20 and 100 for this lab."
  }
}

variable "db_engine_version" {
  description = "PostgreSQL engine version for RDS."
  type        = string
  default     = "16"
}

variable "db_backup_retention_days" {
  description = "Number of days to retain RDS automated backups."
  type        = number
  default     = 1

  validation {
    condition     = var.db_backup_retention_days >= 0 && var.db_backup_retention_days <= 7
    error_message = "db_backup_retention_days must be between 0 and 7 for this lab."
  }
}
variable "db_secret_recovery_window_days" {
  description = "Number of days Secrets Manager waits before permanently deleting the DB secret."
  type        = number
  default     = 7

  validation {
    condition     = var.db_secret_recovery_window_days >= 0 && var.db_secret_recovery_window_days <= 30
    error_message = "db_secret_recovery_window_days must be between 0 and 30."
  }
}