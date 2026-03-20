variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for RDS"
  type        = list(string)
}

variable "ec2_security_group_id" {
  description = "EC2 SG ID — RDS will only accept traffic from this"
  type        = string
}

variable "db_username" {
  type      = string
  sensitive = true   # hides this from terraform plan output
}

variable "db_password" {
  type      = string
  sensitive = true
}

variable "db_name" {
  type    = string
  default = "resqops_db"
}