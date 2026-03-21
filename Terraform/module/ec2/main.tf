# Security Group — what traffic is allowed in/out
resource "aws_security_group" "ec2_sg" {
  name        = "resqops-ec2-sg"
  description = "Allow SSH, HTTP, and Flask port"
  vpc_id      = var.vpc_id

  # Allow SSH from anywhere (tighten this later)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow Flask app port
  ingress {
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role — lets EC2 pull images from ECR without static keys
resource "aws_iam_role" "ec2_role" {
  name = "resqops-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

# Attach ECR read policy to the role
resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Instance profile — this is what attaches the IAM role TO the EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "resqops-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# The actual EC2 instance
resource "aws_instance" "app_server" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true
   key_name               = "resq"

  # This script runs automatically when EC2 boots for the first time
 user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y docker.io awscli
    systemctl start docker
    systemctl enable docker
    usermod -a -G docker ubuntu

    # Login to ECR
    aws ecr get-login-password --region us-east-1 | \
      docker login --username AWS --password-stdin ${var.ecr_image_url}

    # Pull and run your Flask container
    docker pull ${var.ecr_image_url}
    docker run -d \
      -p 5000:5000 \
      --name resqops-api \
      --restart always \
      ${var.ecr_image_url}
  EOF
  
  tags = {
    Name    = "resqops-app-server"
    Project = "ResQOps"
  }
}

output "app_server_ip" {
  value = aws_instance.app_server.public_ip
}

output "ec2_sg_id" {
  value = aws_security_group.ec2_sg.id
}