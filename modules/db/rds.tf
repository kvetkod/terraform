terraform {
  required_version = "> 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

data "aws_rds_engine_version" "postgres_latest" {
  engine = "postgres"
}


resource "aws_db_subnet_group" "postgres" {
  name       = "django-db-subnet-group"
  subnet_ids = data.aws_subnets.default.ids
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

  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.postgres.name
  

  skip_final_snapshot     = true
  multi_az                = false 
  

  publicly_accessible    = false
  deletion_protection    = false 
  apply_immediately      = true
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


resource "aws_security_group" "ecs_service" {
  name        = "django-ecs-sg"
  description = "Security group for Django ECS service"
  vpc_id      = data.aws_vpc.default.id

  egress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    security_groups = [aws_security_group.rds.id]
  }
}
