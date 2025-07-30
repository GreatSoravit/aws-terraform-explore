module "dev" {
    source = "../../module/"

    cluster_security_group_id = aws_security_group.custom_cluster_sg.id
}

data "aws_eks_cluster_auth" "this" {
  name = module.dev.cluster_name
}

provider "kubernetes" {
  host                   = module.dev.cluster_endpoint
  cluster_ca_certificate = base64decode(module.dev.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.dev.cluster_endpoint
    cluster_ca_certificate = base64decode(module.dev.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

# Installs the AWS Load Balancer Controller using its Helm chart
resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.8.1"

  # Pass values to the Helm chart
  values = [
    yamlencode({
      clusterName = module.dev.cluster_name
      region      = module.dev.aws_region_name
      vpcId       = module.dev.vpc_id

      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.dev.aws_load_balancer_controller_iam_role_arn
        }
      }
    })
  ]

  # Ensures the EKS cluster is ready before trying to install the chart
  depends_on = [
    module.dev
  ]
}

resource "aws_security_group" "custom_cluster_sg" {

  vpc_id = module.dev.vpc_id

  description = "Custom primary security group for EKS cluster"

  # Inbound rule allowing all traffic from the security group itself
  ingress {
    description = "Allows EFA traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true 
  }

  # Outbound rule allowing all traffic to any destination
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] [cite: 2]
  }

  tags = {
    # Per your request, only a simple Name tag is applied.
    Name = "custom-cluster-security-group"
  }
}
