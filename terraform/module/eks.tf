#--------------------------------KMS---------------------------------------------
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
#-------------------------------EKS----------------------------------------------
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
    },
	
	github_actions_admin = {
		principal_arn = "arn:aws:iam::656697807925:role/GitHubOIDCRole-aws-terraform-explore"
		policy_associations = {
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

  # disable when in dev environment
  create_node_security_group = var.create_node_security_group

  # set when need to create custom security group for node to tag
  node_security_group_tags = var.enable_node_sg ? { 
    "kubernetes.io/cluster/${var.environment.name}-eks-cluster" = null } : {}

  # Extend node-to-node security group only outside dev environment
  node_security_group_additional_rules = var.create_node_security_group ? local.node_security_group_rules : null

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    attach_cluster_primary_security_group = var.attach_cluster_primary_security_group
    # set when need to custom security group for node
    # iam_role_additional_policies = { additional = data.aws_iam_policy.additional.arn }
  }

  eks_managed_node_groups = {
    "${var.environment.name}-node" = {
      ami_type = "AL2_x86_64_GPU"
      ami_id   = data.aws_ssm_parameter.eks_gpu_ami.value
      
      subnet_ids              = module.vpc.public_subnets
      version                 = null
      #version                = var.cluster_version # AMI don't need to specify version
      min_size                = var.min_size
      max_size                = var.max_size
      desired_size            = var.desired_size
	  
	  # Use spot instance for development project where interruption are not critical
	  capacity_type 		  = "SPOT"
	  instance_types = [var.instance_type]
      
      create_launch_template     = false
      use_custom_launch_template = true
      
      #launch_template_id         = aws_launch_template.eks_nodes.id
      #launch_template_version    = aws_launch_template.eks_nodes.latest_version    

      update_config = {
        max_unavailable_percentage = 33
      }
    }
  }
}
#-------------------------------------------------------------------------------------