# Backend
terraform {
  backend "s3" {
    bucket         = "terraform-demo-testing-2026-niladri"
    key            = "infra/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "terraform-locks"
    encrypt        = true
  }
}