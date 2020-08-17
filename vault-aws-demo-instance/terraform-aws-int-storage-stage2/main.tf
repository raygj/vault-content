provider "aws" {
  region = var.aws_region
}

module "vault-oss" {
  #  source                = "hashicorp/vault-oss/aws"
  #  version               = "0.2.0"
  #  allowed_inbound_cidrs = ["192.168.0.0/32"]
  source                = "app.terraform.io/jray-hashi/vault-starter/aws"
  version               = "0.2.4"
  allowed_inbound_cidrs = ["100.14.98.25/32"]
  vpc_id                = "vpc-9cd6c8e6"
  vault_version         = "var.vault_version"
  owner                 = "var.owner"
  name_prefix           = "var.namespace"
  key_name              = "var.ssh_key_name"
  instance_type         = "var.aws_instance_type"
  vault_nodes           = "3"
}
