module "networking" {
  source = "../../modules/networking"

  name_prefix           = "${var.project_name}-${var.environment}"
  vpc_cidr              = var.vpc_cidr
  az_count              = var.az_count
  public_subnet_cidrs   = var.public_subnet_cidrs
  private_subnet_cidrs  = var.private_subnet_cidrs
  database_subnet_cidrs = var.database_subnet_cidrs

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}