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
variable "deployment_queue_name" {
  description = "Logical name for the deployment event SQS queue."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.deployment_queue_name))
    error_message = "deployment_queue_name must contain only lowercase letters, numbers, and hyphens."
  }
}
variable "github_repository" {
  description = "GitHub repository allowed to assume the Terraform IAM role."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be in owner/repo format."
  }
}

variable "github_branch" {
  description = "GitHub branch allowed to assume the Terraform IAM role."
  type        = string
  default     = "main"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.github_branch))
    error_message = "github_branch contains unsupported characters."
  }
}

variable "eks_cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.34"
}

variable "eks_node_instance_types" {
  description = "EC2 instance types for the EKS managed node group."
  type        = list(string)
  default     = ["t3.small"]
}

variable "eks_desired_size" {
  description = "Desired number of EKS worker nodes."
  type        = number
  default     = 1
}

variable "eks_min_size" {
  description = "Minimum number of EKS worker nodes."
  type        = number
  default     = 1
}

variable "eks_max_size" {
  description = "Maximum number of EKS worker nodes."
  type        = number
  default     = 2
}

variable "eks_cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to access the public EKS Kubernetes API endpoint."
  type        = list(string)
}