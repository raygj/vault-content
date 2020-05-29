module "vault_demo_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "1.60.0"

  name = "${var.environment_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a"]
  private_subnets = ["10.0.1.0/24"]
  public_subnets  = ["10.0.101.0/24"]

  tags = {
    Name = "${var.environment_name}-vpc"
  }
}
