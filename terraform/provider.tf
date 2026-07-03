terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = var.region
  profile = "terraform"

  default_tags {
    tags = {
      Project     = "breakfix-lab"
      Environment = "lab"
      ManagedBy   = "terraform"
      Owner       = "qhorton"
    }
  }
}

