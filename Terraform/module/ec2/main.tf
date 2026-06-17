# Security Group — what traffic is allowed in/out
resource "aws_security_group" "ec2_sg" {
  name        = "resqops-ec2-sg"
  description = "Allow SSH, HTTP, and Flask port"
  vpc_id      = var.vpc_id

  # FIXED: SSH restricted to your admin IP only (was 0.0.0.0/0)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_cidr]
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
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# Attach ECR read policy to the role
resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Instance profile — attaches IAM role to EC2
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "resqops-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# EC2 Instance
resource "aws_instance" "app_server" {
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [aws_security_group.ec2_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name
  associate_public_ip_address = true
  key_name                    = "resq"

  user_data = <<-EOF
    #!/bin/bash
    exec > /var/log/user-data.log 2>&1
    set -e

    echo "STEP 1: Updating packages"
    sleep 30
    apt-get update -y

    echo "STEP 2: Installing Docker"
    apt-get install -y docker.io curl unzip

    echo "STEP 3: Starting Docker"
    systemctl start docker
    systemctl enable docker
    usermod -aG docker ubuntu

    echo "STEP 4: Installing AWS CLI v2"
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"
    unzip -q /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install

    echo "STEP 5: Waiting for IAM role"
    sleep 15

    echo "STEP 6: ECR Login"
    /usr/local/bin/aws ecr get-login-password --region ${var.aws_region} | \
      docker login --username AWS --password-stdin \
      ${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com

    echo "STEP 7: Pulling image"
    docker pull ${var.ecr_image_url}

    echo "STEP 8: Running container"
    docker run -d \
      --name resqops-api \
      --restart always \
      -p 5000:5000 \
      -e AWS_REGION=${var.aws_region} \
      ${var.ecr_image_url}

    echo "DONE"
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
