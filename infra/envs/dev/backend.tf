terraform {
  backend "s3" {
    bucket       = "releaseops-tan25-dev-tfstate"
    key          = "infra/envs/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}