output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "IDs of the private subnets."
  value       = aws_subnet.private[*].id
}

output "availability_zones" {
  description = "Availability Zones used by this module."
  value       = local.azs
}
output "database_subnet_ids" {
  description = "IDs of the isolated database subnets."
  value       = aws_subnet.database[*].id
}
output "nat_gateway_id" {
  description = "ID of the NAT Gateway used by private application subnets."
  value       = aws_nat_gateway.this.id
}

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 Gateway VPC Endpoint."
  value       = aws_vpc_endpoint.s3.id
}