environment = {
  name           = "dev"
  network_prefix = "10.0"
}
instance_type                         = "g4dn.xlarge" #"t3.medium"
min_size                              = 1
max_size                              = 2
desired_size                          = 1
enable_node_sg                        = false
create_node_security_group            = false
attach_cluster_primary_security_group = true
use_custom_ami 						  = true
ami_type 							  = "AL2_x86_64_GPU"
ami_release_version 				  = null