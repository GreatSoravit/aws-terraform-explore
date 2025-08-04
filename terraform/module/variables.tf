variable "environment" {
  description = "Environment configuration (e.g., dev, qa, prod)"
  type = object({
    name           = string
    network_prefix = string
  })
  default = {
    name           = "dev"
    network_prefix = "10.0"
  }
}

variable "instance_type" {
  description = "Type of EC2 instance to provision"
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of instances"
  default     = 1
}

variable "max_size" {
  description = "Max number of instances"
  default     = 2
}

variable "desired_size" {
  description = "Desired number of instances"
  default     = 1
}

variable "cluster_version" {
  description = "The version of the EKS cluster (e.g., 1.30)"
  type        = string
  default     = "1.32"
}

variable "create_node_security_group" {
  description = "Whether to create a separate node security group"
  type        = bool
  default     = false
}

variable "enable_node_sg" {
  description = "Whether to enable node security group"
  type        = bool
  default     = false
}

variable "attach_cluster_primary_security_group" {
  description = "Whether to attach cluster security group"
  type        = bool
  default     = true
}

variable "eks_node_public_key" {
  description = "The public key material for the EKS node key pair."
  type        = string
} 