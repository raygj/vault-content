terraform {
  required_version = ">= 0.12.24"
}

provider "aws" {
  region = var.aws_region
}

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_hostnames = true

  tags = {
    Name = "${var.namespace}-vpc"
  }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.namespace}-internet-gateway"
  }
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.namespace}-route-table"
  }
}

locals {
  segmented_cidr = split("/", var.cidr_block)
  address        = split(".", local.segmented_cidr[0])
  bits           = local.segmented_cidr[1]
}

resource "aws_subnet" "main" {
  count = var.subnet_count
  cidr_block = format(
    "%s.%s.%d.%s/%d",
    local.address[0],
    local.address[1],
    count.index + 1,
    local.address[3],
    local.bits + 16 - local.bits / 2,
  )
  vpc_id            = aws_vpc.main.id
  availability_zone = element(data.aws_availability_zones.available.names, count.index % 2)

  tags = {
    Name = "${var.namespace}-subnet-${element(data.aws_availability_zones.available.names, count.index)}"
  }

  map_public_ip_on_launch = true
}

resource "aws_route_table_association" "main" {
  count          = var.subnet_count
  route_table_id = aws_route_table.main.id
  subnet_id      = element(aws_subnet.main.*.id, count.index)
}

resource "aws_security_group" "main" {
  name        = "${var.namespace}-sg"
  description = "${var.namespace} security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    protocol  = -1
    from_port = 0
    to_port   = 0
    self      = true
  }

  ingress {
    protocol    = "tcp"
    from_port   = 22
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 80
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 443
    to_port     = 443
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = 8800
    to_port     = 8800
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = -1
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
