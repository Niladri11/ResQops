variable "vpc_id" {
  description = "VPC where EC2 will be launched"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID for EC2"
  type        = string
}

variable "ami_id" {
  description = "Ubuntu AMI ID"
  type        = string
  default     = "ami-05d2d839d4f73aafb"
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
}

variable "ecr_image_url" {
  description = "Full ECR image URL to run on boot"
  type        = string
}


variable "aws_account_id" {
  description = "AWS account ID used to construct ECR URLs"
  type        = string
}


variable "aws_region" {
  description = "AWS region where ECR lives"
  type        = string
  default     = "ap-south-1"
}


variable "admin_cidr" {
  description = "Your IP in CIDR notation for SSH access, e.g. 203.0.113.5/32"
  type        = string
}

