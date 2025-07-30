terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"  # or latest
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"  # or latest
    }
  }
}

provider "aws" {
  region = "ap-southeast-7" # Thailand
}