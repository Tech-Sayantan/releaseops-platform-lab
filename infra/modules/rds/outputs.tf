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