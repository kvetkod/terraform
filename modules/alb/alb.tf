terraform {
  required_version = "> 1.0.0, < 2.0.0"

  required_providers {
    aws = {
        source = "hashicorp/aws"
        version = "~> 6.0"
    }
  }
}

resource "aws_alb" "django_lb" {
    name = "django-lb"
    load_balancer_type = "application"
    security_groups = [aws_security_group.django_sg.id]
    subnets = data.aws_subnets.default.ids
}

resource "aws_lb_listener" "django-listener" {
    load_balancer_arn = aws_alb.django_lb.arn
    port = 80
    protocol = "HTTP"

    default_action {
      type = "fixed-response"

      fixed_response {
        content_type = "text/plain"
        message_body = "404: page not found"
        status_code = 404
      }
    }
}

resource "aws_security_group" "django_sg" {
    name = "django-security-group"

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}


data "aws_vpc" "default" {
    default = true
}

data "aws_subnets" "default" {
    filter{
        name = "vpc-id"
        values = [data.aws_vpc.default.id]
    }
}

resource "aws_lb_target_group" "django_tg" {
    name = "django-target-group"
    port = 8080
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id

    health_check {
        path = "/"
        protocol = "HTTP"
        matcher = "200"
        interval = 15
        timeout = 3
        healthy_threshold = 2
        unhealthy_threshold = 2
    }  
}


resource "aws_lb_listener_rule" "asg" {
  listener_arn = aws_lb_listener.django-listener.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.django_tg.arn
  }
}