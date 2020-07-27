variable "ssm_parameter_tls_certificate" {
  type        = string
  description = "describe your variable"
}

variable "ssm_parameter_tls_key" {
  type        = string
  description = "describe your variable"
}

variable "cluster_name" {
  type        = string
  description = "DNS-safe name of the Vault cluster"
}

variable "aws_region" {
  type        = string
  description = "Name of AWS region to place resources"
}

variable "availability_zones" {
  type        = list
  description = "List of availability zones to place resources. List should have 3 zones."
}

variable "vpc_id" {
  type        = string
  description = "The VPC ID to place resources"
}

variable "vpc_cidr_block" {
  type        = string
  description = "CIDR block of entire VPC"
}

variable "private_subnet_ids" {
  type        = list
  description = "List of private subnet IDs to place resources"
}

variable "remote_ssh_cidr_blocks" {
  type        = list
  description = "List of CIDR blocks to allow SSH access to instances"
}

variable "vault_asg_capacity" {
  type = number
}

variable "vault_instance_type" {
  type        = string
  description = "EC2 instance type for Vault"
}

variable "vault_domain" {
  type = string
}

variable "vault_kms_key_rotate" {
  type        = bool
  description = "Specifies whether key rotation is enabled."
  default     = true
}

variable "vault_kms_deletion_days" {
  type        = number
  description = "Duration in days after which the key is deleted after destruction of the resource."
  default     = 30
}

variable "vault_node_ami_id" {
  type        = string
  description = "AMI image-id for Vault instances"
}

variable "vault_node_key_pair" {
  type        = string
  description = "Name of the AWS key pair for Vault instances"
  default     = null
}

variable "vault_node_ebs_root" {
  description = "Root EBS Config for vault nodes"
  type = object(
    {
      volume_type           = string
      volume_size           = number
      delete_on_termination = bool
      encrypted             = bool
    }
  )
}

variable "vault_node_ebs_data" {
  description = "Root EBS Config for vault nodes"
  type = object(
    {
      volume_type           = string
      volume_size           = number
      delete_on_termination = bool
      encrypted             = bool
    }
  )
}

variable "route53_zone_id" {
  type        = string
  description = "Route 53 hosted zone ID"
}

variable "iam_role_permissions_boundary_arn" {
  type        = string
  description = "The ARN of the policy that is used to set the permissions boundary for the role."
}

variable "iam_role_path" {
  type        = string
  description = "Path for IAM entities"
  default     = "/"
}
