module "dev" {
    source = "../../module/"

    # Setup variable for dev environment
    instance_type                         = var.instance_type
    min_size                              = var.min_size
    max_size                              = var.max_size
    desired_size                          = var.desired_size
    environment                           = var.environment
    enable_node_sg                        = var.enable_node_sg
    create_node_security_group            = var.create_node_security_group
    attach_cluster_primary_security_group = var.attach_cluster_primary_security_group
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
