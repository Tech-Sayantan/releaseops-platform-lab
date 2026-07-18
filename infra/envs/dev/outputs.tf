output "vpc_id" {
  description = "VPC ID created by the networking module."
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs created by the networking module."
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs created by the networking module."
  value       = module.networking.private_subnet_ids
}

output "availability_zones" {
  description = "Availability Zones used by the networking module."
  value       = module.networking.availability_zones
}
output "database_subnet_ids" {
  description = "IDs of the isolated database subnets."
  value       = module.networking.database_subnet_ids
}
output "nat_gateway_id" {
  description = "ID of the NAT Gateway used by private application subnets."
  value       = module.networking.nat_gateway_id
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 Gateway VPC Endpoint."
  value       = module.networking.s3_vpc_endpoint_id
}
output "db_subnet_group_name" {
  description = "Name of the RDS DB subnet group."
  value       = module.rds.db_subnet_group_name
}

output "database_security_group_id" {
  description = "ID of the RDS database security group."
  value       = module.rds.database_security_group_id
}
output "application_security_group_id" {
  description = "ID of the application security group allowed to reach PostgreSQL."
  value       = module.rds.application_security_group_id
}
output "database_kms_key_arn" {
  description = "ARN of the KMS key used for database-related encryption."
  value       = module.rds.database_kms_key_arn
}

output "database_secret_arn" {
  description = "ARN of the Secrets Manager secret for database credentials."
  value       = module.rds.database_secret_arn
}
output "database_endpoint" {
  description = "Endpoint address of the PostgreSQL RDS instance."
  value       = module.rds.database_endpoint
}

output "database_port" {
  description = "Port of the PostgreSQL RDS instance."
  value       = module.rds.database_port
}

output "database_name" {
  description = "Initial database name created in PostgreSQL."
  value       = module.rds.database_name
}

output "ecr_repository_names" {
  description = "Names of the ECR repositories."
  value       = module.ecr.repository_names
}

output "ecr_repository_urls" {
  description = "URLs of the ECR repositories used for docker push."
  value       = module.ecr.repository_urls
}

output "ecr_repository_arns" {
  description = "ARNs of the ECR repositories."
  value       = module.ecr.repository_arns
}
