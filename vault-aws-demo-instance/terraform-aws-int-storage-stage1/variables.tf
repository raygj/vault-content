variable "aws_region" {
  description = "AWS region"
  default     = ""
}

variable "namespace" {
  description = "Unique name to use for DNS and resource naming"
}

variable "cidr_block" {
  description = "base CIDR for VPC"
  default     = ""
}
