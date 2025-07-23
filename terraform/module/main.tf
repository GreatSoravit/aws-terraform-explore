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

# This module creates the EKS control plane, node group, and all necessary IAM roles.
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${var.environment.name}-eks-cluster"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets
  eks_managed_node_groups = {}
}

resource "aws_launch_template" "eks_nodes" {
  name_prefix = "eks-nodes-"
  
  # The instance type is now defined here.
  instance_type = var.instance_type

  # Attach the additional security group
  vpc_security_group_ids = [aws_security_group.ssh_access_sg.id]

  # Define the custom block device (EBS volume) settings.
  block_device_mappings {
    device_name = "/dev/xvda" # The root device for Amazon Linux
    ebs {
      volume_size = 8
      volume_type = "gp3"
      delete_on_termination = true
    }
  }
}

# Create the IAM role that EKS nodes will use.
resource "aws_iam_role" "eks_nodes" {
  name = "eks-node-group-role"

  # This policy allows EC2 instances to assume this role.
  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Action    = "sts:AssumeRole",
        Effect    = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# Attach the required AWS-managed policies to the role.
resource "aws_iam_role_policy_attachment" "amazon_eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_nodes.name
}

resource "aws_iam_role_policy_attachment" "amazon_eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_nodes.name
}

# This section defines 2-node EC2 instance group.
resource "aws_eks_node_group" "general_purpose" {
  cluster_name    = module.eks.cluster_name
  node_group_name = "general-purpose"

  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = module.vpc.private_subnets
  
  launch_template {
    id      = aws_launch_template.eks_nodes.id
    version = aws_launch_template.eks_nodes.latest_version
  }

  scaling_config {
    desired_size = var.desired_size
    max_size     = var.max_size
    min_size     = var.min_size
  }

  # This ensures the control plane is ready before creating nodes.
  depends_on = [
    module.eks,
    aws_iam_role_policy_attachment.amazon_eks_worker_node_policy,
    aws_iam_role_policy_attachment.amazon_ec2_container_registry_read_only,
    aws_iam_role_policy_attachment.amazon_eks_cni_policy,
]
}

# Create the add-on, making it depend on the node group.
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = module.eks.cluster_id
  addon_name   = "aws-ebs-csi-driver"

  # This ensures nodes are ready before installing the add-on.
  depends_on = [aws_eks_node_group.general_purpose]
}

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
