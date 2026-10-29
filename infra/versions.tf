terraform {
  required_version = ">= 1.10.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  cloud {
    organization = "successfulsuccess-stashnid"

    workspaces {
      name = "successfulsuccess-dev"
    }
  }
}

provider "aws" {
  region = var.aws_region
}
