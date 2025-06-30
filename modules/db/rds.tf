terraform {
  required_version = "> 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.44.0"
    }
  }
}

data "aws_rds_engine_version" "postgres_latest" {
  engine = "postgres"
}


resource "aws_db_subnet_group" "postgres" {
  name       = "django-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids

  tags = {
    Name = "Django DB subnet group"
  }
}

resource "aws_db_instance" "postgres" {
  identifier           = "django-db"
  engine               = "postgres"
  engine_version       = data.aws_rds_engine_version.postgres_latest.version
  instance_class       = "db.t3.micro"
  allocated_storage    = 20
  storage_type         = "gp2"
  storage_encrypted    = true

  username             = var.db_username
  password             = var.db_password
  db_name              = "django_db"

  vpc_security_group_ids = [var.rds_id]
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  

  skip_final_snapshot     = true
  multi_az                = false 
  

  publicly_accessible    = false
  deletion_protection    = false 
  apply_immediately      = true
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


