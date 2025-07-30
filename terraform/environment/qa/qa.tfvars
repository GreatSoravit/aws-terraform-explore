environment = {
  name           = "qa"
  network_prefix = "10.1"
}
instance_type                         = "t3.small"
min_size                              = 2
max_size                              = 4
desired_size                          = 2
enable_node_sg                        = true
create_node_security_group            = true
attach_cluster_primary_security_group = false