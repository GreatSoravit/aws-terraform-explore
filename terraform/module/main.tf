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

  cluster_name    = "main-eks-cluster"
  cluster_version = "1.29"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # This section defines your 2-node EC2 instance group.
  eks_managed_node_groups = {
    general_purpose = {
      instance_types = ["${var.instance_type}"] # variable t3.micro Free Tier eligible instance type.
      cluster_name = "${var.environment.name}-eks-cluster"

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

# Creates a private S3 bucket, useful for storing application data, logs, or backups.
resource "aws_s3_bucket" "application_bucket" {
  bucket        = "s3-aws-terraform-explore" # S3 bucket names must be globally unique
  force_destroy = true                       # Allows deletion even if files exist (for dev/test buckets)

  tags = {
    Name        = "s3-bucket"
    Project     = "aws-terraform-explore"
  }
}

resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.application_bucket.id
  versioning_configuration {
    status = "Suspended"  # Save costs; versioning costs extra
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.application_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"  # Free SSE encryption
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  bucket = aws_s3_bucket.application_bucket.id

  rule {
    id     = "transition-to-infrequent-access"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"  # Cheaper after 30 days
    }

    expiration {
      days = 365  # Optional: expire objects after 1 year to save space
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Creates a standalone General Purpose SSD (gp3) EBS volume.
# This volume can be dynamically provisioned to pods in EKS using the EBS CSI Driver.
resource "aws_ebs_volume" "database_volume" {
  availability_zone = module.vpc.azs[0]  # Must be in the same AZ as the node that will use it.
  size              = 8                  # minimum size in GB (8GB is the smallest allowed)
  type              = "gp3"              # cheapest general purpose SSD volume

  # tune IOPS and throughput to lowest values for cost savings
  iops              = 300           # minimum for gp3 (300 IOPS)
  throughput        = 125           # minimum throughput (MB/s)

  tags = {
    Name    = "ebs"
    Project = "aws-terraform-explore"
  }
}
