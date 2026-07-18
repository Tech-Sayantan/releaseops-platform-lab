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