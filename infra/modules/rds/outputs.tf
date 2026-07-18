output "db_subnet_group_name" {
  description = "Name of the RDS DB subnet group."
  value       = aws_db_subnet_group.this.name
}

output "database_security_group_id" {
  description = "ID of the RDS database security group."
  value       = aws_security_group.database.id
}
output "application_security_group_id" {
  description = "ID of the application security group allowed to reach PostgreSQL."
  value       = aws_security_group.application.id
}

output "database_kms_key_arn" {
  description = "ARN of the KMS key used for database-related encryption."
  value       = aws_kms_key.database.arn
}

output "database_secret_arn" {
  description = "ARN of the Secrets Manager secret for database credentials."
  value       = aws_secretsmanager_secret.database.arn
}
output "database_endpoint" {
  description = "Endpoint address of the PostgreSQL RDS instance."
  value       = aws_db_instance.postgres.address
}

output "database_port" {
  description = "Port of the PostgreSQL RDS instance."
  value       = aws_db_instance.postgres.port
}

output "database_name" {
  description = "Initial database name created in PostgreSQL."
  value       = aws_db_instance.postgres.db_name
}