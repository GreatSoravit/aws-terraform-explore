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
	use_custom_ami						  = var.use_custom_ami
	ami_type							  = var.ami_type
	ami_release_version					  = var.ami_release_version
	eks_node_public_key 				  = file("../../module/keypair/eks-node-key.pub")
}

data "aws_eks_cluster_auth" "this" {
  name = module.dev.cluster_name
}

# Install metric service for kube-system
resource "helm_release" "metrics_server" {
  provider   = helm.eks
  
  name       = "metrics-server"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.13.0" # Check for latest version: https://artifacthub.io/packages/helm/metrics-server/metrics-server

  set {
    name  = "args"
    value = "{--kubelet-insecure-tls, --kubelet-preferred-address-types=InternalIP}"
  }
  depends_on = [
    module.dev
  ]
}

# Installs the AWS Load Balancer Controller using its Helm chart
resource "helm_release" "aws_load_balancer_controller" {
  provider   = helm.eks
  
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
  count    = var.enable_argocd ? 1 : 0
  provider = helm.eks
  timeout  = 600
  
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
    module.dev
  ]
}

resource "kubernetes_job" "argocd_pre_delete_cleanup" {
  # depends on the same conditional as Argo CD release
  count    = var.enable_argocd ? 1 : 0
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

resource "kubernetes_service_account" "training_job_sa" {
  metadata {
    name      = "training-job-sa"
    namespace = "ml-jobs"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.dev.training_job_role_arn
    }
  }
}
