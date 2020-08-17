provider "aws" {
  region = var.aws_region
}

module "vault-starter" {
  source                = "app.terraform.io/jray-hashi/vault-starter/aws"
  version               = "0.1.2"
  allowed_inbound_cidrs = ["var.allowed_inbound_cidrs"]
  vpc_id                = "vpc-9cd6c8e6"
  vault_version         = "var.vault_version"
  owner                 = "var.owner"
  name_prefix           = "var.namespace"
  key_name              = "var.ssh_key_name"
  instance_type         = "var.aws_instance_type"
  vault_nodes           = "var.vault_nodes"
}
