resource "random_pet" "cluster" {}

resource "tls_private_key" "cluster" {
  algorithm = "RSA"
  rsa_bits  = "4096"
}

resource "local_file" "tls_private_key" {
  content         = tls_private_key.cluster.private_key_pem
  filename        = ".cluster_id_rsa"
  file_permission = "0600"
}

resource "aws_key_pair" "cluster" {
  key_name   = "${random_pet.cluster.id}-key"
  public_key = tls_private_key.cluster.public_key_openssh
}

module "vault" {
  source = "../../"

  cluster_name   = random_pet.cluster.id
  vault_domain   = var.vault_domain
  aws_region     = var.aws_region
  vpc_id         = var.vpc_id
  vpc_cidr_block = data.aws_vpc.main.cidr_block

  availability_zones = [
    "us-east-2a",
    "us-east-2b",
    "us-east-2c",
  ]

  private_subnet_ids = [
    "subnet-fe171a96",
    "subnet-37b6cd4d",
    "subnet-6511b229",
  ]

  vault_asg_capacity  = 3
  vault_instance_type = "t3a.medium"

  vault_node_ebs_root = {
    volume_type           = "gp2"
    volume_size           = 8
    delete_on_termination = true
    encrypted             = true
  }

  vault_node_ebs_data = {
    volume_type           = "gp2"
    volume_size           = 25
    delete_on_termination = true
    encrypted             = true
  }

  ssm_parameter_tls_certificate = "johnny-vault-tls-cert"
  ssm_parameter_tls_key         = "johnny-vault-tls-key"

  vault_node_key_pair    = aws_key_pair.cluster.key_name
  vault_node_ami_id      = var.immutable_vault_raft_ami_id
  remote_ssh_cidr_blocks = ["69.47.216.0/21"]
  route53_zone_id        = data.aws_route53_zone.main.zone_id

  iam_role_permissions_boundary_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}
