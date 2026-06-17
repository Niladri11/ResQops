provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name  = "resqops-vpc"
    Owner = "Niladri"
  }
}

# Public Subnet 1 — AZ a
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_1_cidr
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name  = "resqops-public-subnet-1"
    Owner = "Niladri"
  }
}

# Public Subnet 2 — AZ b
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_2_cidr
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name  = "resqops-public-subnet-2"
    Owner = "Niladri"
  }
}

# Private Subnet 1 — AZ a
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = "${var.aws_region}a"

  tags = {
    Name  = "resqops-private-subnet-1"
    Owner = "Niladri"
  }
}

# Private Subnet 2 — AZ b
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = "${var.aws_region}b"

  tags = {
    Name  = "resqops-private-subnet-2"
    Owner = "Niladri"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name  = "resqops-igw"
    Owner = "Niladri"
  }
}

# Public Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name  = "resqops-public-rt"
    Owner = "Niladri"
  }
}

# Associate BOTH public subnets to public route table
resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table (no internet route — for RDS)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name  = "resqops-private-rt"
    Owner = "Niladri"
  }
}

resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}

module "ec2" {
  source        = "../module/ec2"
  vpc_id        = aws_vpc.main.id                  # ← direct resource reference
  subnet_id     = aws_subnet.public_subnet_1.id    # ← direct resource reference
  ecr_image_url = var.ecr_image_url
}

module "rds" {
  source                = "../module/rds"
  vpc_id                = aws_vpc.main.id           # ← direct resource reference
  private_subnet_ids    = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]  # ← direct
  ec2_security_group_id = module.ec2.ec2_sg_id
  db_username           = var.db_username
  db_password           = var.db_password
}