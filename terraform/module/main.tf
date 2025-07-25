# Region
data "aws_region" "current" {}

# This module creates a best-practice VPC, subnets, route tables,
# an internet gateway, and a NAT gateway for private subnets.
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "eks-project-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["${data.aws_region.current.name}a", "${data.aws_region.current.name}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  # A NAT Gateway is required for nodes in private subnets to pull images from the internet.
  enable_nat_gateway = true
  single_nat_gateway = true

  # Tags required by Kubernetes for service discovery (e.g., for Load Balancers).
  public_subnet_tags = {
    "kubernetes.io/cluster/main-eks-cluster" = "shared"
    "kubernetes.io/role/elb"                 = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/main-eks-cluster" = "shared"
    "kubernetes.io/role/internal-elb"        = "1"
  }
}

resource "aws_security_group" "additional" {
  name_prefix = "aws-terraform-explore-additional"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port = 22
    to_port   = 22
    protocol  = "tcp"
    cidr_blocks = [
      "10.0.0.0/8",
      "172.16.0.0/12",
      "192.168.0.0/16",
    ]
  }

  tags = { Name = "aws-terraform-explore" }
}

data "aws_iam_policy" "additional" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
#--------------------------------------------------------------------------------
resource "aws_key_pair" "eks_node_key" {
  key_name   = "eks-node-key"
  public_key = file("${path.module}/eks-node-key.pub")
}
data "aws_iam_user" "terraform_user" {
  user_name = "user-aws-terraform-explore"
}
#--------------------------------------------------------------------------------
data "aws_ami" "eks_worker" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.cluster_version}-v*"]
  }
  owners = ["602401143452"] 
}

resource "aws_launch_template" "eks_nodes" {
  name_prefix   = "eks-nodes-"
  image_id      = data.aws_ami.eks_worker.id
  instance_type = var.instance_type
  key_name      = aws_key_pair.eks_node_key.key_name

  block_device_mappings = {
    xvda = {
      device_name = "/dev/xvda"
      ebs = {
        volume_size           = 8
        volume_type           = "gp3"
        iops                  = 3000
        throughput            = 150
            delete_on_termination = true
      }
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "eks-node"
    }
  }

# Attach the additional security group
#  vpc_security_group_ids = [
#    module.eks.cluster_primary_security_group_id,
#    aws_security_group.ssh_access_sg.id]

#}
#--------------------------------------------------------------------------------
# Create a KMS key for EKS secrets encryption
resource "aws_kms_key" "eks_secrets" {
  description             = "KMS key for EKS cluster secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

# Create an alias for the key to make it easier to reference
resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/eks-secrets-key"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

# This module creates the EKS control plane, node group, and all necessary IAM roles.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.environment.name}-eks-cluster"
  cluster_version = "1.29"
  cluster_endpoint_public_access = true

  access_entries = {
    # A descriptive name for the access entry
    terraform_user_admin = {
      principal_arn = data.aws_iam_user.terraform_user.arn
      
      # A list of policies to associate with user
      policy_associations = {
        # A descriptive name for the policy association
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = {
            type = "cluster"
          }
        }
      }
    }
  }

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    aws-ebs-csi-driver = {
      most_recent = true
    }
  }

  cluster_encryption_config = {
    provider_key_arn = aws_kms_key.eks_secrets.arn
    resources        = ["secrets"]
  }

  iam_role_additional_policies = {
    additional = data.aws_iam_policy.additional.arn
  }

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # Extend cluster security group rules
  cluster_security_group_additional_rules = {
    ingress_nodes_ephemeral_ports_tcp = {
      description                = "Nodes on ephemeral ports"
      protocol                   = "tcp"
      from_port                  = 1025
      to_port                    = 65535
      type                       = "ingress"
      source_node_security_group = true
    }
    # Test: https://github.com/terraform-aws-modules/terraform-aws-eks/pull/2319
    ingress_source_security_group_id = {
      description              = "Ingress from another computed security group"
      protocol                 = "tcp"
      from_port                = 22
      to_port                  = 22
      type                     = "ingress"
      source_security_group_id = aws_security_group.additional.id
    }
  }
 # Extend node-to-node security group rules
  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    # Test: https://github.com/terraform-aws-modules/terraform-aws-eks/pull/2319
    ingress_source_security_group_id = {
      description              = "Ingress from another computed security group"
      protocol                 = "tcp"
      from_port                = 22
      to_port                  = 22
      type                     = "ingress"
      source_security_group_id = aws_security_group.additional.id
    }
  }

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = [var.instance_type]

    attach_cluster_primary_security_group = true
    vpc_security_group_ids                = [aws_security_group.additional.id]
    iam_role_additional_policies = {
      additional = data.aws_iam_policy.additional.arn
    }
  }

  eks_managed_node_groups = {
    default = {
      min_size     = var.min_size
      max_size     = var.max_size
      desired_size = var.desired_size

      instance_types = [var.instance_type]
      capacity_type  = "ON_DEMAND"

      launch_template = {
        id      = aws_launch_template.eks_node_lt.id
        version = "$Latest"
      }

      # Needed by the aws-ebs-csi-driver
      #iam_role_additional_policies = {
        #AmazonEBSCSIDriverPolicy = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
      #}

      update_config = {
        max_unavailable_percentage = 33 # or set `max_unavailable`
      }
    }
  }
}
#--------------------------------------------------------------------------------
# EKS nodes with IAM role
#data "aws_iam_role" "eks_nodes" {
#  name = "eks-node-group-role"
#}
#--------------------------------------------------------------------------------
# This section defines 2-node EC2 instance group.
#resource "aws_eks_node_group" "general_purpose" {
#  cluster_name    = module.eks.cluster_name
#  node_group_name = "general-purpose"

#  node_role_arn   = data.aws_iam_role.eks_nodes.arn
#  subnet_ids      = module.vpc.private_subnets
  
#  launch_template {
#    id      = aws_launch_template.eks_nodes.id
#    version = aws_launch_template.eks_nodes.latest_version
#  }

#  scaling_config {
#    desired_size = var.desired_size
#    max_size     = var.max_size
#    min_size     = var.min_size
#  }

  # This ensures the control plane is ready before creating nodes.
#  depends_on = [module.eks]
#}
#--------------------------------------------------------------------------------
# Data source to get your current IP address
data "http" "my_ip" {
  url = "http://ipv4.icanhazip.com"
}

# Creates a new security group
resource "aws_security_group" "ssh_access_sg" {
  name        = "ssh-from-my-ip"
  description = "Allow SSH inbound traffic from my IP"
  vpc_id      = module.vpc.vpc_id # Associates it with your VPC

  # Rule allowing incoming SSH traffic from your IP
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${chomp(data.http.my_ip.response_body)}/32"]
  }

  # Allows all outbound traffic (common practice)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creates a standalone General Purpose SSD (gp3) EBS volume.
# This volume can be dynamically provisioned to pods in EKS using the EBS CSI Driver.
# resource "aws_ebs_volume" "database_volume" {
#  availability_zone = module.vpc.azs[0]  # Must be in the same AZ as the node that will use it.
#  size              = 8                  # minimum size in GB (8GB is the smallest allowed)
#  type              = "gp3"              # cheapest general purpose SSD volume

  # tune IOPS and throughput to lowest values for cost savings
#  iops              = 300           # minimum for gp3 (300 IOPS)
#  throughput        = 125           # minimum throughput (MB/s)

#  tags = {
#    Name    = "ebs"
#    Project = "aws-terraform-explore"
#  }
#}
