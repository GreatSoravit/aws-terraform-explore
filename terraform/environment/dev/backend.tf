terraform {
  backend "remote" {
    hostname     = "app.terraform.io"
    organization = "soravit"

    workspaces {
      name = "aws-terraform-explore"
    }
  }
}
