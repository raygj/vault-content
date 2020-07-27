data "aws_caller_identity" "current" {}

data "aws_vpc" "main" {
  id = var.vpc_id
}

data "aws_route53_zone" "main" {
  name = var.vault_domain
}
