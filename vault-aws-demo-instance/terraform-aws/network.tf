module "vault_demo_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.47.0"

  name = "${var.environment_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a"]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  tags = {
    Name      = "${var.environment_name}-vpc"
    owner     = var.hashibot_reaper_owner
    region    = var.hc_region
    purpose   = var.purpose
    TTL       = var.hashibot_reaper_ttl
    terraform = var.tf_used
    workspace = var.workspace_id
  }
}
