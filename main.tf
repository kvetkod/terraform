terraform {
  required_version = "> 1.0.0, < 2.0.0"

  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "alb" {
  source = "./modules/alb"
}

module "rds"{
  source = "./modules/db"

  db_password = var.db_password
  db_username = var.db_username
}

