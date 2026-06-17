provider "aws" {
  region = "ap-southeast-1"
  alias  = "dr"
}

# VPC for DR region
resource "aws_vpc" "dr_vpc" {
  provider   = aws.dr
  cidr_block = "10.1.0.0/16"
  tags = {
    Name = "resqops-dr-vpc"
  }
}

resource "aws_subnet" "dr_public" {
  provider                = aws.dr
  vpc_id                  = aws_vpc.dr_vpc.id
  cidr_block              = "10.1.1.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "resqops-dr-public"
  }
}

resource "aws_iam_instance_profile" "dr_profile" {
  provider = aws.dr
  name     = "resqops-dr-profile"
  role     = "resqops-ec2-role"
}

resource "aws_internet_gateway" "dr_igw" {
  provider = aws.dr
  vpc_id   = aws_vpc.dr_vpc.id
  tags = {
    Name = "resqops-dr-igw"
  }
}

resource "aws_route_table" "dr_rt" {
  provider = aws.dr
  vpc_id   = aws_vpc.dr_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dr_igw.id
  }
}

resource "aws_route_table_association" "dr_rta" {
  provider       = aws.dr
  subnet_id      = aws_subnet.dr_public.id
  route_table_id = aws_route_table.dr_rt.id
}

resource "aws_security_group" "dr_sg" {
  provider    = aws.dr
  name        = "resqops-dr-sg"
  description = "DR security group"
  vpc_id      = aws_vpc.dr_vpc.id

  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "dr_ec2" {
  provider               = aws.dr
  ami                    = "ami-0497a974f8d5dcef8"
  instance_type          = "t2.micro"
  key_name               = "resq"
  subnet_id              = aws_subnet.dr_public.id
  vpc_security_group_ids = [aws_security_group.dr_sg.id]
  iam_instance_profile   = aws_iam_instance_profile.dr_profile.name

  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io unzip curl
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ubuntu

    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install

    
    aws ecr get-login-password --region ${var.primary_aws_region} | \
      docker login --username AWS --password-stdin ${var.aws_account_id}.dkr.ecr.${var.primary_aws_region}.amazonaws.com

    docker pull ${var.aws_account_id}.dkr.ecr.${var.primary_aws_region}.amazonaws.com/resqops-api:latest

    docker run -d \
      --name resqops-api \
      --restart always \
      -p 5000:5000 \
      -e AWS_REGION=ap-southeast-1 \
      ${var.aws_account_id}.dkr.ecr.${var.primary_aws_region}.amazonaws.com/resqops-api:latest
  EOF

  tags = {
    Name = "resqops-dr-ec2"
  }
}

output "dr_ec2_public_ip" {
  value = aws_instance.dr_ec2.public_ip
}


variable "aws_account_id" {
  description = "AWS account ID used to construct ECR URLs"
  type        = string
}

variable "primary_aws_region" {
  description = "Primary region where ECR repository lives"
  type        = string
  default     = "ap-south-1"
}

variable "admin_cidr" {
  description = "Your IP in CIDR notation for SSH access, e.g. 203.0.113.5/32"
  type        = string
}
