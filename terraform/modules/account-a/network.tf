data "aws_availability_zones" "available" { state = "available" }

data "aws_ec2_instance_type_offerings" "required" {
  for_each      = toset([for instance in values(var.instances) : instance.instance_type])
  location_type = "availability-zone"
  filter {
    name   = "instance-type"
    values = [each.key]
  }
}

locals {
  eligible_zones = sort(tolist(setintersection(toset(data.aws_availability_zones.available.names), [for offering in values(data.aws_ec2_instance_type_offerings.required) : toset(offering.locations)]...)))
}

resource "aws_vpc" "assignment" {
  cidr_block           = "10.42.0.0/24"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(local.tags, { Name = var.name_prefix })
}

resource "aws_subnet" "assignment" {
  vpc_id                  = aws_vpc.assignment.id
  cidr_block              = "10.42.0.0/24"
  availability_zone       = try(local.eligible_zones[0], null)
  map_public_ip_on_launch = false
  tags                    = merge(local.tags, { Name = var.name_prefix })
  lifecycle {
    precondition {
      condition     = length(local.eligible_zones) > 0
      error_message = "No available AZ offers all five selected instance types."
    }
  }
}

resource "aws_internet_gateway" "assignment" {
  vpc_id = aws_vpc.assignment.id
  tags   = local.tags
}

resource "aws_route_table" "assignment" {
  vpc_id = aws_vpc.assignment.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.assignment.id
  }
  tags = local.tags
}

resource "aws_route_table_association" "assignment" {
  subnet_id      = aws_subnet.assignment.id
  route_table_id = aws_route_table.assignment.id
}

resource "aws_security_group" "assignment" {
  name        = "${var.name_prefix}-workloads"
  description = "No inbound access; HTTPS outbound only."
  vpc_id      = aws_vpc.assignment.id
  tags        = local.tags
}

resource "aws_vpc_security_group_egress_rule" "https" {
  security_group_id = aws_security_group.assignment.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  description       = "ECR image pulls and CloudWatch logs for public-IP Fargate tasks."
}
