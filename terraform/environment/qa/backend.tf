terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "soravit"

    workspaces {
      name = "qa-aws-terraform-explore"
    }
  }
}