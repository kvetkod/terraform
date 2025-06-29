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
    port = 443
    protocol = "HTTPS"
    ssl_policy        = "ELBSecurityPolicy-2016-08"
    certificate_arn   = aws_acm_certificate_validation.cert_validation.certificate_arn


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
      from_port   = 443
      to_port     = 443
      protocol    = "tcp"
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
    port = 8000
    protocol = "HTTP"
    vpc_id = data.aws_vpc.default.id
    target_type = "ip"
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


resource "aws_route53_zone" "my_zone" {
  name = "site-for-agency.com" 
}

resource "aws_route53_record" "www" {
  zone_id = aws_route53_zone.my_zone.zone_id
  name     = "www.site-for-agency.com" 
  type     = "A"

 
  alias {
    name                   = aws_alb.django_lb.dns_name
    zone_id                = aws_alb.django_lb.zone_id
    evaluate_target_health = true
  }

  depends_on = [aws_acm_certificate_validation.cert_validation]
}


resource "aws_acm_certificate" "cert" {
  domain_name       = "www.site-for-agency.com"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
      zone_id = aws_route53_zone.my_zone.zone_id
    }
  }

  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = each.value.zone_id
}

resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn = aws_acm_certificate.cert.arn
  validation_record_fqdns = [
    for record in aws_route53_record.cert_validation : record.fqdn
  ]

  
  depends_on = [aws_alb.django_lb]
}
