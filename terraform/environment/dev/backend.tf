terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "soravit"

    workspaces {
      name = "aws-terraform-explore"
    }
  }
  backend "s3" {
    bucket         = "terraform-explore-project-initials-tfstate"
    key            = "dev/eks/terraform.tfstate"
    region         = "ap-southeast-7"
    dynamodb_table = "terraform-explore-project-lock"
  }
}
