# main.tf

# ─────────────────────────────────────────
# VPC
# ─────────────────────────────────────────


resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true   # EC2 instances get DNS names — required for ALB health checks
  enable_dns_support   = true   # Required for DNS hostnames to work

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-vpc"
  })
}

# ─────────────────────────────────────────
# PUBLIC SUBNETS
# ─────────────────────────────────────────

# count = 2 creates two subnet resources from one block.
# count.index is 0 for the first, 1 for the second.
# This is how Terraform avoids copy-paste infrastructure.
#
# Two subnets in two AZs = multi-AZ coverage.
# If us-east-1a has an outage, us-east-1b keeps serving traffic.
# This is the difference between 99.5% and 99.95% availability.
resource "aws_subnet" "public" {
  count = length(var.public_subnet_cidrs)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true   # Instances launched here get a public IP automatically

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-subnet-${count.index + 1}"
    Type = "public"
  })
}

# ─────────────────────────────────────────
# INTERNET GATEWAY
# ─────────────────────────────────────────


resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-igw"
  })
}

# ─────────────────────────────────────────
# ROUTE TABLE
# ─────────────────────────────────────────


resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-public-rt"
  })
}


resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id

  # Must wait for IGW to exist before this route can be created
  depends_on = [aws_internet_gateway.main]
}

# ─────────────────────────────────────────
# ROUTE TABLE ASSOCIATIONS
# ─────────────────────────────────────────

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}
