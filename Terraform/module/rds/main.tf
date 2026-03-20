# DB Subnet Group — tells RDS which subnets it can live in
resource "aws_db_subnet_group" "rds_subnet_group" {
  name       = "resqops-rds-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name = "resqops-rds-subnet-group"
  }
}

# Security Group for RDS — ONLY allows traffic from EC2
resource "aws_security_group" "rds_sg" {
  name        = "resqops-rds-sg"
  description = "Allow Postgres only from EC2"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.ec2_security_group_id]  # EC2 only — not 0.0.0.0/0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# The RDS instance itself
resource "aws_db_instance" "postgres" {
  identifier        = "resqops-db"
  engine            = "postgres"
  engine_version    = "14.13"
  instance_class    = "db.t3.micro"   # free tier eligible
  allocated_storage = 20

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  multi_az               = false   # set true in prod — costs more
  publicly_accessible    = false   # critical — keeps DB private
  skip_final_snapshot    = true    # set false in real prod
  deletion_protection    = false   # set true in real prod

  tags = {
    Name    = "resqops-postgres"
    Project = "ResQOps"
  }
}

output "rds_endpoint" {
  value       = aws_db_instance.postgres.endpoint
  description = "RDS connection endpoint for Flask app"
}

output "rds_sg_id" {
  value = aws_security_group.rds_sg.id
}