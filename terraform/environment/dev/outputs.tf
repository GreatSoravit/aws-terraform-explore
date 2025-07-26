output "cluster_name" {
  value       = module.dev.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "configure_kubectl" {
  value       = module.dev.configure_kubectl
}
