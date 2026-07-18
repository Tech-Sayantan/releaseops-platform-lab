variable "name_prefix" {
  description = "Name prefix used for ECR repositories."
  type        = string
}

variable "repository_names" {
  description = "Logical service names that need ECR repositories."
  type        = list(string)

  validation {
    condition     = length(var.repository_names) > 0
    error_message = "repository_names must contain at least one repository name."
  }
}

variable "image_tag_mutability" {
  description = "Whether image tags can be overwritten."
  type        = string
  default     = "IMMUTABLE"

  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.image_tag_mutability)
    error_message = "image_tag_mutability must be MUTABLE or IMMUTABLE."
  }
}

variable "max_tagged_images" {
  description = "Maximum number of tagged images to keep per repository."
  type        = number
  default     = 20
}

variable "untagged_image_expire_days" {
  description = "Number of days before untagged images are expired."
  type        = number
  default     = 7
}

variable "force_delete" {
  description = "Whether Terraform can delete repositories even if images exist."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Common tags to apply to ECR resources."
  type        = map(string)
  default     = {}
}