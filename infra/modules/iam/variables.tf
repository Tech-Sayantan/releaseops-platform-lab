variable "name_prefix" {
  description = "Name prefix used for GitHub OIDC IAM resources."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository allowed to assume the IAM role, in owner/repo format."
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$", var.github_repository))
    error_message = "github_repository must be in owner/repo format, for example Tech-Sayantan/releaseops-platform-lab."
  }
}

variable "github_branch" {
  description = "GitHub branch allowed to assume the IAM role."
  type        = string
  default     = "main"

  validation {
    condition     = can(regex("^[A-Za-z0-9._/-]+$", var.github_branch))
    error_message = "github_branch contains unsupported characters."
  }
}

variable "role_name_suffix" {
  description = "Suffix for the GitHub Actions IAM role name."
  type        = string
  default     = "github-actions-terraform"
}

variable "tags" {
  description = "Common tags to apply to GitHub OIDC IAM resources."
  type        = map(string)
  default     = {}
}
