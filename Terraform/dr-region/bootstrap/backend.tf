terraform {
  backend "s3" {
    bucket         = "resqops-tfstate"
    key            = "dr/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "resqops-tfstate-lock"
    encrypt        = true
  }
}