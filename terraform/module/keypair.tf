#-------------------------------KEY PAIR----------------------------------------------
# key pair generate in local machine then upload to aws attach to instance
resource "aws_key_pair" "eks_node_key" {
  key_name   = "${var.environment.name}-eks-node-key"
  public_key = var.eks_node_public_key # file("${path.module}/keypair/eks-node-key.pub")
}

# seach the lastest AMI based on filter 
#data "aws_ami" "eks_worker" {
#  most_recent = true
#  filter {
#    name   = "name"
#    values = ["amazon-eks-node-${var.cluster_version}-v*"]
#  }
#  owners = ["121268973566"] 
#} 

# add new ami that use gpu for train model in mlops
data "aws_ssm_parameter" "eks_gpu_ami" {
  name = "/aws/service/eks/optimized-ami/1.32/amazon-linux-2-gpu/recommended/image_id"
}

# launch template for eks_node
#resource "aws_launch_template" "eks_nodes" {
#  name_prefix   = "${var.environment.name}-eks-nodes"
  #image_id     = data.aws_ami.eks_worker.id
#  image_id 		= data.aws_ssm_parameter.eks_gpu_ami.value
#  instance_type = var.instance_type
#  key_name      = aws_key_pair.eks_node_key.key_name 

  #vpc_security_group_ids = [
    #aws_security_group.eks_cluster_sg.id
    # module.eks.cluster_primary_security_group_id
  #]

#  block_device_mappings {
#      device_name = "/dev/xvda"
#      ebs {
#        volume_size           = local.ebs_volume_sizes[var.environment.name]
#        volume_type           = "gp3"
#        iops                  = local.ebs_iops[var.environment.name]
#        throughput            = local.ebs_throughput[var.environment.name]
#        delete_on_termination = true
#      }
#  }

#  tag_specifications {
#    resource_type = "instance"
#    tags = {
#      Name = "${var.environment.name}-aws-terraform-explore"
#    }
#  }
#}
#-------------------------------------------------------------------------------------
