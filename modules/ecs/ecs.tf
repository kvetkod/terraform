terraform {
  required_version = "> 1.0.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.44.0"
    }
  }
}


resource "aws_ecs_cluster" "main" {
  name = "django-cluster"
}

resource "aws_ecr_repository" "my_repo" {
  name = "my-django-app"
}

resource "aws_ecs_task_definition" "django" {
    family                   = "django-task"
    network_mode             = "awsvpc"
    requires_compatibilities = ["FARGATE"]
    cpu                      = "256"  
    memory                   = "512"
    
    execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
    
    container_definitions = jsonencode([

        {
        name      = "django-app",
        image     = "${aws_ecr_repository.my_repo.repository_url}:latest",
        essential = true,
        portMappings = [
            {
            containerPort = 8000,
            hostPort      = 8000,
            protocol      = "tcp"
            }
        ],
        environment = [
            { name = "DJANGO_SETTINGS_MODULE", value = "project.settings" },
            { name = "DB_HOST", value = var.db_host },
            { name = "DB_NAME", value = var.db_name },
            { name = "DB_USER", value = var.db_username },
            { name = "DB_PASSWORD", value = var.db_password }
        ],
        },
        
    ])
}

resource "aws_ecs_service" "service" {
    name = "django_ecs_service"
    cluster = aws_ecs_cluster.main.id
    task_definition = aws_ecs_task_definition.django.arn
    desired_count   = 1

    launch_type = "FARGATE"

    load_balancer {
    target_group_arn = var.tg_arn
    container_name   = "django-app"                
    container_port   = 8000                   
  }

    network_configuration {
    subnets          = data.aws_subnets.default.ids
    security_groups  = [aws_security_group.ecs_service.id]
    assign_public_ip = true
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
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_ecr_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
