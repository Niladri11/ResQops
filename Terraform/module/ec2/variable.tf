variable "vpc_id" {
  description = "VPC where EC2 will be launched"
  type        = string
}

variable "subnet_id" {
  description = "Public subnet ID for EC2"
  type        = string
}

variable "ami_id" {
  description = "Ubuntu-AMI ID"
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