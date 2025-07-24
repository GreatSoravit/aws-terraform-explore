# --- Add this to a new file like auth.tf ---

# 1. Configure the Kubernetes Provider
# This tells Terraform how to connect to your EKS cluster.
# It uses the outputs from your existing EKS module to authenticate
# as the cluster creator, bypassing your local kubectl issues.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

# 2. Add your user to the aws-auth ConfigMap
# This resource will add your IAM user to the access list inside Kubernetes.
# It uses `kubernetes_config_map_v1_data` which is safer because it only
# patches the data; it doesn't try to manage the whole file.
resource "kubernetes_config_map_v1_data" "aws_auth_patch" {
  # This depends_on block is crucial. It waits for the EKS cluster and
  # its node group to be ready before trying to modify the ConfigMap.
  depends_on = [
    module.eks.cluster_id,
    module.eks.eks_managed_node_groups # Adjust if your node group has a different output name
  ]

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    # This uses yamlencode to correctly format the user mapping.
    "mapUsers" = yamlencode([
      {
        userarn  = "arn:aws:iam::656697807925:user/user-aws-terraform-explore"
        username = "user-aws-terraform-explore"
        groups   = ["system:masters"]
      }
    ])
  }
}
