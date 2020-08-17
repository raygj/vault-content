variable "aws_region" {
  # select region
  description = "target AWS region"
}

#variable "allowed_inbound_cidrs" {
#  type        = string
#  description = "List of CIDR blocks to permit inbound Vault access from"
#  default     = "100.14.98.25/32"
#}

variable "vpc_id" {
  description = "ID of VPC"
}

variable "vault_version" {
  # version of Vault OSS to install
  description = "Vault OSS version x.y.z"
}
variable "owner" {
  # Used within HashiCorp accounts for resource reaping
  description = "EC2 instance owner"
}

variable "namespace" {
  # Can have alphanumeric characters and hyphens.
  # Other characters might be ok but have not been tested
  description = "Unique name to use for DNS and resource naming"
}

variable "ssh_key_name" {
  # Whatever AWS allows which seems to be any characters
  description = "AWS key pair name to install on the EC2 instance"
}

variable "aws_instance_type" {
  # micro for sandbox, large for POCs
  description = "EC2 instance type"
}

variable "vault_nodes" {
  # Number of cluster nodes
  description = "number of Vault nodes (1,3,5)"
}
