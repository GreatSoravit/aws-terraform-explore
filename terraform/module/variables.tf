variable "instance_type" {
  description = "Type of EC2 instance to provision"
  default     = "t3.small"
}

variable "environment" {
  description = "Development Environment"

  type = object({
    name           = string
    network_prefix = string
  })
  default = {
    name = "dev"
    network_prefix = "10.0"
  }
}
 
variable "min_size" {
  description = "Minimum number of instances"
  default     = 2
}

variable "max_size" {
  description = "Max number of instances"
  default     = 2
}

variable "desired_size" {
  description = "Desired number of instances"
  default     = 2
}

variable "cluster_version" {
  description = "The version of the EKS cluster (e.g., 1.30)"
  type        = string
  default     = "1.32"
}

variable "cluster_security_group_id" {
  description = "An existing security group ID to use for the EKS cluster. If not provided, the module will create one."
  type        = string
  default     = null
}
