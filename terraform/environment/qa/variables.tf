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

variable "environment" {
  description = "QA environment"
  type = object({
    name           = string
    network_prefix = string
  })
}