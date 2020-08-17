provider "aws" {
  region = var.aws_region
}

module "vault-oss" {
  source                = "hashicorp/vault-oss/aws"
  version               = "0.2.0"
  allowed_inbound_cidrs = ["100.14.98.25/32"]
  vpc_id                = "vpc-9cd6c8e6"
  vault_version         = "1.5.0"
  owner                 = "jray-at-hashicorp"
  name_prefix           = "jray"
  key_name              = "jray"
  instance_type         = "t2.micro"
  vault_nodes           = "3"
}
