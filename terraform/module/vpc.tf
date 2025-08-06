# Region
data "aws_region" "current" {}
#-----------------------------------VPC-----------------------------------------
# This module creates a best-practice VPC, subnets, route tables,
# an internet gateway, and a NAT gateway for private subnets.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.environment.name}-eks-project-vpc"
  cidr = "${var.environment.network_prefix}.0.0/16"

  azs             = ["${data.aws_region.current.name}a", "${data.aws_region.current.name}b"]
  private_subnets = ["${var.environment.network_prefix}.1.0/24", "${var.environment.network_prefix}.2.0/24"]
  public_subnets  = ["${var.environment.network_prefix}.101.0/24", "${var.environment.network_prefix}.102.0/24"]

  # set public IP to connect with Internet
  map_public_ip_on_launch = true

  # A NAT Gateway is required for nodes in private subnets to pull images from the internet.
  enable_nat_gateway = true
  single_nat_gateway = true

  # Tags required by Kubernetes for service discovery (e.g., for Load Balancers).
  public_subnet_tags = {
    "kubernetes.io/cluster/${var.environment.name}-eks-cluster" = "shared"
    "kubernetes.io/role/elb"                                    = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${var.environment.name}-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"                           = "1"
  }
}
#-------------------------------------------------------------------------------