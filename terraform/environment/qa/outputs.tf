# terraform/modules/outputs.tf

output "qa_cluster_name" {
  description = "The name of the qa EKS cluster."
  value       = module.qa.cluster_name
}

output "cluster_endpoint" {
  value = module.qa.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.qa.cluster_certificate_authority_data
}

output "vpc_id" {
  value = module.qa.vpc_id
}

output "aws_region_name" {
  value = module.qa.aws_region_name
}

output "aws_load_balancer_controller_iam_role_arn" {
  value = module.qa.aws_load_balancer_controller_iam_role_arn
}

output "configure_kubectl" {
  value = module.qa.configure_kubectl
}

output "eks_cluster_security_group_id" {
  value = module.qa.eks_cluster_security_group_id
}