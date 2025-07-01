terraform {
  required_version = "> 1.0.0, < 2.0.0"

  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 5.44.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  profile = "ugenka"
}

module "alb" {
  source = "./modules/alb"
}

module "rds"{
  source = "./modules/db"

  db_password = var.db_password
  db_username = var.db_username
  rds_id = aws_security_group.rds.id
}

module "ecs" {
  source = "./modules/ecs"
  depends_on = [ module.alb ]

  db_host = module.rds.db_host
  db_name = var.db_name
  db_password = var.db_password
  db_username = var.db_username
  rds_id = aws_security_group.rds.id
  tg_arn = module.alb.tg_arn
}


resource "aws_security_group" "rds" {
  name        = "django-rds-sg"
  description = "Security group for Django RDS instance"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    cidr_blocks = ["172.31.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["172.31.0.0/16"]
  }

  tags = {
    Name = "django-rds-sg"
  }
}

data "aws_subnets" "default" {
    filter{
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

data "aws_vpc" "default" {
    default = true
}