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

module "rds" {
  source = "../../modules/rds"

  name_prefix         = "${var.project_name}-${var.environment}"
  vpc_id              = module.networking.vpc_id
  database_subnet_ids = module.networking.database_subnet_ids

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}

module "ecr" {
  source = "../../modules/ecr"

  name_prefix      = "${var.project_name}-${var.environment}"
  repository_names = var.ecr_repository_names

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}
module "sqs" {
  source = "../../modules/sqs"

  name_prefix = "${var.project_name}-${var.environment}"
  queue_name  = var.deployment_queue_name

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}

module "github_oidc" {
  source = "../../modules/iam"

  name_prefix       = "${var.project_name}-${var.environment}"
  github_repository = var.github_repository
  github_branch     = var.github_branch

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}
