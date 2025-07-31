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
#-----------------------------------SG-----------------------------------------
# Security group for eks cluster
#resource "aws_security_group" "eks_cluster_sg" {
#  name_prefix = "${var.environment.name}-eks-cluster"
#  description = "EKS cluster primary security group."
#  vpc_id      = module.vpc.vpc_id

#  tags = {
#    Name   = "${var.environment.name}-eks-cluster"
#  }
#}

#resource "null_resource" "wait_for_nodes" {
#  depends_on = [module.eks.node_security_group_id]
#}

#data "aws_security_group" "node_sg" {
  # EKS module to finish creating the node security group.
#  depends_on = [module.eks.eks_managed_node_groups]
#  filter {
#    name   = "tag:Name"
#    values = ["eks-cluster-sg-dev-eks-cluster-*"] # ["${var.environment.name}-eks-cluster-node"]
#  }
#   filter {
#     name   = "tag:aws:eks:cluster-name"
#     values = ["dev-eks-cluster"]
#   }
#  vpc_id = module.vpc.vpc_id
#}

#variable "remove_owned_tag" {
#  type    = bool
#  default = true  # Set to true to remove the tag
#}

#resource "aws_ec2_tag" "remove_owned_tag_from_cluster_sg" {
  #count = var.remove_owned_tag ? 1 : 0

#  for_each = toset(data.aws_security_groups.eks_cluster_tag_sg.ids)
#  resource_id = each.value
#  resource_id = data.aws_security_group.node_sg.id
  #key         = "kubernetes.io/cluster/${data.aws_security_group.eks_cluster_tag_sg.tags["aws:eks:cluster-name"]}"
#  key         = "kubernetes.io/cluster/${module.eks.cluster_name}"
#  value       = ""  # Can also be "null", AWS treats both as effectively unsetting

  #depends_on = [aws_security_group.node_sg]
#}

#resource "aws_ec2_tag" "eks_node_sg_owned_tag" {
  #depends_on = [module.eks.node_security_group_id]
#  resource_id = data.aws_security_group.node_sg.id
  #resource_id = module.eks.node_security_group_id
  #resource_id = module.eks.eks_managed_node_groups["default"].security_group_id

#  key         = "kubernetes.io/cluster/${module.eks.cluster_name}"
#  value       = "owned"
#}

# Allows HTTP traffic from the ALB to the nodes
#resource "aws_security_group_rule" "allow_alb_http_to_nodes" {
#  description              = "Allow HTTP from ALB to EKS nodes"
#  type                     = "ingress"
#  from_port                = 80
#  to_port                  = 80
#  protocol                 = "tcp"
#  #source_security_group_id = aws_security_group.eks_cluster_sg.id
#  #security_group_id        = module.eks.node_security_group_id
#  source_security_group_id = module.eks.cluster_primary_security_group_id
#  security_group_id        = module.eks.node_security_group_id
#}

# Allows HTTPS traffic from the ALB to the nodes
#resource "aws_security_group_rule" "allow_alb_https_to_nodes" {
#  description              = "Allow HTTPS from ALB to EKS nodes"
#  type                     = "ingress"
#  from_port                = 443
#  to_port                  = 443
#  protocol                 = "tcp"
#  source_security_group_id = aws_security_group.eks_cluster_sg.id
#  security_group_id        = module.eks.node_security_group_id
#  #source_security_group_id = module.eks.cluster_primary_security_group_id
#  #security_group_id        = module.eks.node_security_group_id
#}
#--------------------------------------------------------------------------------
# aws username that link with terraform
data "aws_iam_user" "terraform_user" {
  user_name = "user-aws-terraform-explore"
}

data "aws_iam_policy" "additional" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Creates the dedicated IAM role for the AWS Load Balancer Controller
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "EKS-ALB-Controller-Role-${var.environment.name}" # Use the same name you created in the console

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = module.eks.oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            # Ensures only the controller's service account can assume this role
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

# Use IAM policy json file to create policy
resource "aws_iam_policy" "lb_controller_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy-${var.environment.name}"
  path        = "/"
  description = "Policy for AWS Load Balancer Controller in ${var.environment.name} environment"
  policy      = file("${path.module}/IAM/aws_load_balancer_controller_iam_policy.json")  # path to downloaded file
}

# Attaches the required AWS-managed policy to the role
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.lb_controller_policy.arn
}

#--------------------------------------------------------------------------------
# key pair generate in local machine then upload to aws attach to instance
resource "aws_key_pair" "eks_node_key" {
  key_name   = "${var.environment.name}-eks-node-key"
  public_key = file("${path.module}/eks-node-key.pub")
}

# seach the lastest AMI based on filter 
data "aws_ami" "eks_worker" {
  most_recent = true
  filter {
    name   = "name"
    values = ["amazon-eks-node-${var.cluster_version}-v*"]
  }
  owners = ["121268973566"] 
}

# launch template for eks_node
resource "aws_launch_template" "eks_nodes" {
  name_prefix   = "${var.environment.name}-eks-nodes"
  image_id      = data.aws_ami.eks_worker.id
  instance_type = var.instance_type
  
  #vpc_security_group_ids = [
    #aws_security_group.eks_cluster_sg.id
    # module.eks.cluster_primary_security_group_id
  #]

  block_device_mappings {
      device_name = "/${var.environment.name}/xvda"
      ebs {
        volume_size           = local.ebs_volume_sizes[var.environment.name]
        volume_type           = "gp3"
        iops                  = local.ebs_iops[var.environment.name]
        throughput            = local.ebs_throughput[var.environment.name]
        delete_on_termination = true
      }
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.environment.name}-aws-terraform-explore"
    }
  }
}

#--------------------------------------------------------------------------------
# Create a KMS key for EKS secrets encryption
resource "aws_kms_key" "eks_secrets" {
  description             = "KMS key for EKS cluster secrets encryption"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

# Create an alias for the key to make it easier to reference
resource "aws_kms_alias" "eks_secrets" {
  name          = "alias/${var.environment.name}-eks-secrets-key"
  target_key_id = aws_kms_key.eks_secrets.key_id
}

# This module creates the EKS control plane, node group, and all necessary IAM roles.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                   = "${var.environment.name}-eks-cluster"
  cluster_version                = var.cluster_version
  cluster_endpoint_public_access = true

  #create_cluster_primary_security_group_tags = false
  #create_cluster_security_group = false
  #cluster_security_group_id = aws_security_group.eks_cluster_sg.id
  #cluster_security_group_id = var.cluster_security_group_id
  #depends_on = [aws_security_group.eks_cluster_sg]

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

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  # Extend cluster security group rules
  cluster_security_group_additional_rules = local.cluster_security_group_additional_rules

#    allow_https = {
#      description              = "Allow HTTPS from ALB to EKS nodes"
#      protocol                 = "tcp"
#      from_port                = 443
#      to_port                  = 443
#      type                     = "ingress"
#      source_node_security_group = true
#    }

  # disable when in dev environment
  create_node_security_group = var.create_node_security_group

  # set when need to create custom security group for node to tag
  node_security_group_tags = var.enable_node_sg ? { 
    "kubernetes.io/cluster/${var.environment.name}-eks-cluster" = null } : {}

  # Extend node-to-node security group only outside dev environment
  node_security_group_additional_rules = var.create_node_security_group ? local.node_security_group_rules : null

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    ami_type       = "AL2_x86_64"
    instance_types = [var.instance_type]

    attach_cluster_primary_security_group = var.attach_cluster_primary_security_group
    # set when need to custom security group for node
    # vpc_security_group_ids = [aws_security_group.additional.id] 
    iam_role_additional_policies = {
      additional = data.aws_iam_policy.additional.arn
    }
  }

  eks_managed_node_groups = {
    "default" = {
      subnet_ids   = module.vpc.public_subnets
      min_size     = var.min_size
      max_size     = var.max_size
      desired_size = var.desired_size
      launch_template_id      = aws_launch_template.eks_nodes.id
      launch_template_version = aws_launch_template.eks_nodes.latest_version      
      key_name     = aws_key_pair.eks_node_key.key_name # include key pair in node_group

      update_config = {
        max_unavailable_percentage = 33
      }
    }
  }
}
#----------------------------------locals---------------------------------------------
locals {
    ebs_volume_sizes = {
      dev = 8
      qa  = 10 
      prd = 20  
    }

    ebs_iops = {
      dev = 3000  
      qa  = 4000
      prd = 4000
    }

    ebs_throughput = {
      dev = 125
      qa  = 150
      prd = 200
    }

    # Base cluster SG rules when node SG is disabled
    temp_ephemeral_rule = {
    description                = "Nodes on ephemeral ports"
    protocol                   = "tcp"
    from_port                  = 1025
    to_port                    = 65535
    type                       = "ingress"
    source_node_security_group = var.enable_node_sg ? true : null
    cidr_blocks                = !var.enable_node_sg ? ["${var.environment.network_prefix}.0.0/16"] : null
  }
    
    ssh_from_trusted_cidrs = {
      description = "SSH access from internal & specific external IPs"
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      type        = "ingress"
      cidr_blocks = [
        "${var.environment.network_prefix}.0.0/16",
        "172.16.0.0/12",
        "192.168.0.0/16",
        "49.228.99.81/32"
      ]
    }

    cluster_sg_common_rules = {
    # Create the final rule by iterating over the temporary rule and filtering out null values.
    ingress_nodes_ephemeral_ports_tcp = {
      for k, v in local.temp_ephemeral_rule : k => v if v != null
    }

    ssh_from_trusted_cidrs = local.ssh_from_trusted_cidrs
  }


  # Only include allow_http if node SG is enabled
  cluster_sg_http_rule = var.enable_node_sg ? {
    allow_http = {
      description                = "Allow HTTP from ALB to EKS nodes"
      protocol                   = "tcp"
      from_port                  = 80
      to_port                    = 80
      type                       = "ingress"
      source_node_security_group = true
    }
  } : {}

  # Final rules: merged
  cluster_security_group_additional_rules = merge(
    local.cluster_sg_common_rules,
    local.cluster_sg_http_rule
  )

  node_security_group_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    ssh_from_trusted_cidrs = {
      description = "SSH access from internal & specific external IPs"
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      type        = "ingress"
      cidr_blocks = [
        "${var.environment.network_prefix}.0.0/16",
        "172.16.0.0/12",
        "192.168.0.0/16",
        "49.228.99.81/32"
      ]
    }
  }
}
