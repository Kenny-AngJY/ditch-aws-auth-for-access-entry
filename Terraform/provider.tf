terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">=6.30.0"
    }
  }

  required_version = "~> 1.14"
}

provider "aws" {
  region = var.region
  default_tags {
    tags = local.default_tags
  }
}