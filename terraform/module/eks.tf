# This module creates the EKS control plane, node group, and all necessary IAM roles.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "main-eks-cluster"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # This section defines your 2-node EC2 instance group.
  eks_managed_node_groups = {
    general_purpose = {
      instance_types = ["${var.instance_type}"] # variable t3.micro Free Tier eligible instance type.

      # --- fixed-size, 2-node cluster -------------------
      min_size       = var.min_size
      max_size       = var.max_size
      desired_size   = var.desired_size
      # --------------------------------------------------

      # Attach the additional security group
      attach_cluster_primary_security_group = false # This is often needed
      vpc_security_group_ids                = [aws_security_group.ssh_access_sg.id]
    }
  }

  # This add-on installs the AWS EBS CSI Driver, which is the recommended way
  # to manage and mount EBS volumes for pods running in your EKS cluster.
  cluster_addons = {
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }
}
