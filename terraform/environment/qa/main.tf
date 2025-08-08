module "qa" {
    source = "../../module/"

    # Setup variable for qa environment 
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
  name = module.qa.cluster_name
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

resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0
  provider = helm.eks
  timeout = 600
  
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  version    = "5.51.2" # recent version

  create_namespace  = true

  # make the server accessible with HTTP:
  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }
  
  # make the argo cd not redirect to HTTPS
  values = [
    <<-EOF
    configs:
      params:
        server.insecure: "true"
    EOF
  ]
  
  # Ensures the EKS cluster is ready before trying to install argocd
  depends_on = [
    module.qa
  ]
}

resource "kubernetes_job" "argocd_pre_delete_cleanup" {
  # This depends on the same conditional as your Argo CD release
  count = var.enable_argocd ? 1 : 0
  provider = kubernetes.eks

  metadata {
    name      = "argocd-cleanup-finalizers"
    namespace = "argocd"
    annotations = {
      # This Helm hook tells it to run BEFORE the release is deleted
      "helm.sh/hook" = "pre-delete"
      "helm.sh/hook-delete-policy" = "hook-succeeded"
    }
  }
  spec {
    template {
	  metadata {
        name = "argocd-cleanup-pod"
      }	
      spec {
        service_account_name = "argocd-server"
        container {
          name  = "cleanup"
          image = "bitnami/kubectl" # Use a kubectl image
          command = [
            "/bin/sh",
            "-c",
            # This script finds all applications and removes their finalizers
            "kubectl patch applications --all -n argocd -p '{\"metadata\":{\"finalizers\":[]}}' --type=merge; kubectl delete applications --all -n argocd"
          ]
        }
        restart_policy = "Never"
      }
    }
  }
 depends_on = [helm_release.argocd]   
}

#------------------------------------MANIFEST#------------------------------------
data "http" "metrics_server_manifest" {
  # kubernetes metrics	
  url = "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml"
}

resource "kubernetes_manifest" "metrics_server" {
  provider 	 = kubernetes.eks
  manifest   = yamldecode(data.http.metrics_server_manifest.response_body)
  depends_on = [module.dev]
}

data "http" "argocd_ingress_manifest" {
  # Argocd ingress manifest
  url = "https://raw.githubusercontent.com/GreatSoravit/aws-terraform-explore/v2.00-argocd/kubernetes/argocd-ingress.yaml"
}


resource "kubernetes_manifest" "argocd_ingress" {
  manifest 	 = yamldecode(data.http.argocd_ingress_manifest.response_body)
  depends_on = [helm_release.argocd]
}

data "http" "webapp_application_manifest" {
  # Argocd manifest link with githubs for GitOps
  url = "https://raw.githubusercontent.com/GreatSoravit/aws-argocd-explore/main/webapp-application.yaml"
}


resource "kubernetes_manifest" "webapp_application" {
  manifest 	 = yamldecode(data.http.webapp_application_manifest.response_body)
  depends_on = [helm_release.argocd]
}