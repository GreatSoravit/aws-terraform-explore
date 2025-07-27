output "cluster_name" {
  description = "The name of the EKS cluster."
  value       = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "aws_region_name" {
  value = data.aws_region.current.name
}

output "aws_load_balancer_controller_iam_role_arn" {
  value = aws_iam_role.aws_load_balancer_controller.arn
}

output "configure_kubectl" {
  description = "Run this command to configure kubectl to connect to the EKS cluster."
  value       = "aws eks update-kubeconfig --region ${data.aws_region.current.name} --name ${module.eks.cluster_name}"
}

output "aws_security_group" "node_sg" {
  id = data.aws_security_group.node_security_group_id
}

