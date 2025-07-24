terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=5.70.0"
    }
  }
  backend "s3" {
    bucket         = "oyogbeche-terraform-state"
    key            = "oy-resume/terraform.tfstate"
    region         = "eu-west-1"
    encrypt        = true
  }
}

provider "aws" {
  region  = "eu-west-1"
}
