module "qa" {
    source = "../../module/"
}

data "aws_eks_cluster_auth" "this" {
  name = module.qa.cluster_name
}

provider "kubernetes" {
  host                   = module.qa.cluster_endpoint
  cluster_ca_certificate = base64decode(module.qa.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.this.token
}

provider "helm" {
  kubernetes {
    host                   = module.qa.cluster_endpoint
    cluster_ca_certificate = base64decode(module.qa.cluster_certificate_authority_data)
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
      clusterName = module.qa.cluster_name
      region      = module.qa.aws_region_name
      vpcId       = module.qa.vpc_id

      serviceAccount = {
        create = true
        name   = "aws-load-balancer-controller"
        annotations = {
          "eks.amazonaws.com/role-arn" = module.qa.aws_load_balancer_controller_iam_role_arn
        }
      }
    })
  ]

  # Ensures the EKS cluster is ready before trying to install the chart
  depends_on = [
    module.qa
  ]
}