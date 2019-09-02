# AWS region in which to deploy
variable aws_region {}

# All resources will be tagged with this
variable environment_name {}

variable consul_dc {}

variable vault_server_count {
  default = 1
}

# URL for Vault OSS binary
variable vault_zip_file {
  default = "https://releases.hashicorp.com/vault/1.2.2/vault_1.2.2_linux_amd64.zip"
}

# URL for Consul OSS binary
variable consul_zip_file {
  default = "https://releases.hashicorp.com/consul/1.6.0/consul_1.6.0_linux_amd64.zip"
}

# Instance size
variable instance_type {}

# SSH key name to access EC2 instances (should already exist)
variable key_name {}

# Instance tags for HashiBot AWS resource reaper
variable hashibot_reaper_owner {}

variable hashibot_reaper_ttl {
  default = 48
}
