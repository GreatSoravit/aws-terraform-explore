terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "soravit"

    workspaces {
      name = "qa-aws-terraform-explore"
    }
  }
  backend "s3" {
    bucket         = "terraform-explore-project-initials-tfstate"
    key            = "qa/eks/terraform.tfstate"
    region         = "ap-southeast-7"
    dynamodb_table = "terraform-explore-project-lock"
  }
}