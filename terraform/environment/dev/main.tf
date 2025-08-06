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
	eks_node_public_key 				  = file("../../module/keypair/eks-node-key.pub")
}

data "aws_eks_cluster_auth" "this" {
  name = module.dev.cluster_name
}

# Installs the AWS Load Balancer Controller using its Helm chart
resource "helm_release" "aws_load_balancer_controller" {
  provider = helm.eks
  
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

resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  version    = "5.51.2" # recent version

  create_namespace = true

  # make the server accessible via a LoadBalancer:
  set {
    name  = "server.service.type"
    value = "LoadBalancer"
  }
  
  # Ensures the EKS cluster is ready before trying to install argocd
  depends_on = [
    module.dev
  ]
}

data "kubernetes_secret_v1" "argocd_initial_admin_secret" {
  # fully installed before trying to read the secret
  depends_on = [helm_release.argocd]

  metadata {
    name      = "argocd-initial-admin-secret"
    namespace = "argocd"
  }
}