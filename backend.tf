terraform {
  backend "s3" {
    bucket = "kvetkod-django-tf-state"
    key    = "kvetkod-django/terraform.tfstate"
    region = "us-east-1"
  }
}