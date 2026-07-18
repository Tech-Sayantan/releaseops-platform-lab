output "repository_names" {
  description = "Names of the ECR repositories."
  value = {
    for service, repo in aws_ecr_repository.this :
    service => repo.name
  }
}

output "repository_urls" {
  description = "URLs of the ECR repositories used for docker push."
  value = {
    for service, repo in aws_ecr_repository.this :
    service => repo.repository_url
  }
}

output "repository_arns" {
  description = "ARNs of the ECR repositories."
  value = {
    for service, repo in aws_ecr_repository.this :
    service => repo.arn
  }
}