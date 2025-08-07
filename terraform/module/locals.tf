#----------------------------------locals---------------------------------------------
locals {
    ebs_volume_sizes = {
      dev = 20
      qa  = 20 
      prd = 30  
    }

    ebs_iops = {
      dev = 3000  
      qa  = 4000
      prd = 4000
    }

    ebs_throughput = {
      dev = 125
      qa  = 150
      prd = 200
    }

    # Base cluster SG rules when node SG is disabled
    temp_ephemeral_rule = {
    description                = "Nodes on ephemeral ports"
    protocol                   = "tcp"
    from_port                  = 1025
    to_port                    = 65535
    type                       = "ingress"
    source_node_security_group = var.enable_node_sg ? true : null
    cidr_blocks                = !var.enable_node_sg ? ["${var.environment.network_prefix}.0.0/16"] : null
  }
    
    ssh_from_trusted_cidrs = {
      description = "SSH access from internal & specific external IPs"
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      type        = "ingress"
      cidr_blocks = [
        "${var.environment.network_prefix}.0.0/16",
        "172.16.0.0/12",
        "192.168.0.0/16",
        "184.22.32.81/32"
      ]
    }

    cluster_sg_common_rules = {
    # Create the final rule by iterating over the temporary rule and filtering out null values.
    ingress_nodes_ephemeral_ports_tcp = {
      for k, v in local.temp_ephemeral_rule : k => v if v != null
    }

    ssh_from_trusted_cidrs = local.ssh_from_trusted_cidrs
  }


  # Only include allow_http if node SG is enabled
  cluster_sg_http_rule = var.enable_node_sg ? {
    allow_http = {
      description                = "Allow HTTP from ALB to EKS nodes"
      protocol                   = "tcp"
      from_port                  = 80
      to_port                    = 80
      type                       = "ingress"
      source_node_security_group = true
    }
  } : {}

  # Final rules: merged
  cluster_security_group_additional_rules = merge(
    local.cluster_sg_common_rules,
    local.cluster_sg_http_rule
  )

  node_security_group_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }

    ssh_from_trusted_cidrs = {
      description = "SSH access from internal & specific external IPs"
      protocol    = "tcp"
      from_port   = 22
      to_port     = 22
      type        = "ingress"
      cidr_blocks = [
        "${var.environment.network_prefix}.0.0/16",
        "172.16.0.0/12",
        "192.168.0.0/16",
        "184.22.32.81/32"
      ]
    }
  }
}
#-------------------------------------------------------------------------------------