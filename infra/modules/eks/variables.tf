variable "name_prefix" {
  description = "Name prefix used for EKS resources."
  type        = string
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS cluster."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the EKS cluster will run."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs where EKS worker nodes will run."
  type        = list(string)
}

variable "node_instance_types" {
  description = "EC2 instance types for the EKS managed node group."
  type        = list(string)
}

variable "desired_size" {
  description = "Desired number of EKS worker nodes."
  type        = number
}

variable "min_size" {
  description = "Minimum number of EKS worker nodes."
  type        = number
}

variable "max_size" {
  description = "Maximum number of EKS worker nodes."
  type        = number
}

variable "tags" {
  description = "Common tags to apply to EKS resources."
  type        = map(string)
  default     = {}
}
variable "cluster_endpoint_public_access_cidrs" {
  description = "CIDR blocks allowed to access the public EKS Kubernetes API endpoint."
  type        = list(string)
}