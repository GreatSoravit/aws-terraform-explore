output "cluster_name" {
  value       = module.dev.cluster_name
}

output "s3_bucket_name" {
  value       = module.dev.s3_bucket_name
}

output "configure_kubectl" {
  value       = module.dev.configure_kubectl
}
