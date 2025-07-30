# terraform/modules/outputs.tf

output "dev_cluster_name" {
  description = "The name of the dev EKS cluster."
  value       = module.dev.cluster_name
}

output "cluster_endpoint" {
  value = module.dev.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.dev.cluster_certificate_authority_data
}

output "vpc_id" {
  value = module.dev.vpc_id
}

output "aws_region_name" {
  value = module.dev.aws_region_name
}

output "aws_load_balancer_controller_iam_role_arn" {
  value = module.dev.aws_load_balancer_controller_iam_role_arn
}

output "configure_kubectl" {
  value = module.dev.configure_kubectl
}

output "eks_cluster_security_group_id" {
  value = module.dev.eks_cluster_security_group_id
}
