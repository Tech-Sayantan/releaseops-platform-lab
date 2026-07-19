output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider."
  value       = aws_iam_openid_connect_provider.github.arn
}

output "github_actions_role_name" {
  description = "Name of the IAM role assumed by GitHub Actions."
  value       = aws_iam_role.github_actions.name
}

output "github_actions_role_arn" {
  description = "ARN of the IAM role assumed by GitHub Actions."
  value       = aws_iam_role.github_actions.arn
}

output "github_actions_policy_arn" {
  description = "ARN of the IAM policy attached to the GitHub Actions role."
  value       = aws_iam_policy.terraform_permissions.arn
}

output "github_subject" {
  description = "GitHub OIDC subject allowed to assume the role."
  value       = local.github_subject
}
