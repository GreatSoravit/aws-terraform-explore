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
  region = "ap-southeast-7" 
}

provider "kubernetes" {
  alias					 = "eks"
  host                   = module.dev.cluster_endpoint
  cluster_ca_certificate = base64decode(module.dev.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  alias = "eks"
  kubernetes {
    host                   = module.dev.cluster_endpoint
    cluster_ca_certificate = base64decode(module.dev.cluster_certificate_authority_data)
    #token                  = data.aws_eks_cluster_auth.this.token
	exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      args        = ["eks", "get-token", "--cluster-name", module.dev.cluster_name]
      command     = "aws"
    }
  }
}