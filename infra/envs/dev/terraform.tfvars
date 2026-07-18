aws_region   = "us-east-1"
project_name = "releaseops"
environment  = "dev"
owner        = "tan"
vpc_cidr     = "10.40.0.0/16"
az_count     = 2
public_subnet_cidrs = [
  "10.40.0.0/24",
  "10.40.1.0/24",
]

private_subnet_cidrs = [
  "10.40.2.0/24",
  "10.40.3.0/24",
]

database_subnet_cidrs = [
  "10.40.20.0/24",
  "10.40.21.0/24",
]

ecr_repository_names = [
  "api",
  "worker",
  "notifications",
  "frontend"
]
