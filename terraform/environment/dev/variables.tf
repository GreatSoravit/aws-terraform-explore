variable "environment" {
  description = "DEV environment"
  type = object({
    name           = string
    network_prefix = string
  })
}

variable "instance_type" {
  description = "Type of EC2 instance to provision"
  type        = string
}

variable "min_size" {
  description = "Minimum number of instances"
  type        = number
}

variable "max_size" {
  description = "Max number of instances"
  type        = number
}

variable "desired_size" {
  description = "Desired number of instances"
  type        = number
}

variable "attach_cluster_primary_security_group" {
  description = "Attach cluster primary security group"
  type        = bool
}

variable "create_node_security_group" {
  description = "Create dedicated node security group"
  type        = bool
}

variable "enable_node_sg" {
  description = "Enable create node of security group"
  type        = bool
}
