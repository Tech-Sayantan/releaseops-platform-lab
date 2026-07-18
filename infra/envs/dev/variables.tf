variable "aws_region" {
  description = "AWS region where the dev platform will be deployed."
  type        = string
}

variable "project_name" {
  description = "Short project name used for naming and tagging AWS resources."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "project_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "environment" {
  description = "Deployment environment name."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "owner" {
  description = "Owner tag for cost tracking and accountability."
  type        = string
}

variable "vpc_cidr" {
  description = "IP range for the VPC."
  type        = string
}

variable "az_count" {
  description = "How many Availability Zones to use."
  type        = number
}
variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets."
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private application subnets."
  type        = list(string)
}

variable "database_subnet_cidrs" {
  description = "CIDR blocks for isolated database subnets."
  type        = list(string)
}

variable "ecr_repository_names" {
  description = "Service names that need ECR repositories."
  type        = list(string)

  validation {
    condition     = length(var.ecr_repository_names) > 0
    error_message = "ecr_repository_names must contain at least one service name."
  }
}
