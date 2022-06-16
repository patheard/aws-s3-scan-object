terraform {
  required_version = "=1.2.3"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "= 3.73.0"
    }
  }
}

provider "aws" {
  region = "ca-central-1"
}
