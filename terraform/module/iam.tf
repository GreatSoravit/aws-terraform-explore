
#-------------------------------------IAM----------------------------------------
# aws username that link with terraform
data "aws_iam_user" "terraform_user" {
  user_name = "user-aws-terraform-explore"
}

data "aws_iam_policy" "additional" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

# Creates the dedicated IAM role for the AWS Load Balancer Controller
resource "aws_iam_role" "aws_load_balancer_controller" {
  name = "EKS-ALB-Controller-Role-${var.environment.name}" # Use the same name you created in the console

  assume_role_policy = jsonencode({
    Version   = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Federated = module.eks.oidc_provider_arn
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            # Ensures only the controller's service account can assume this role
            "${module.eks.oidc_provider}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          }
        }
      }
    ]
  })
}

# Use IAM policy json file to create policy
resource "aws_iam_policy" "lb_controller_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy-${var.environment.name}"
  path        = "/"
  description = "Policy for AWS Load Balancer Controller in ${var.environment.name} environment"
  policy      = file("${path.module}/IAM/aws_load_balancer_controller_iam_policy.json")  # path to downloaded file
}

# Attaches the required AWS-managed policy to the role
resource "aws_iam_role_policy_attachment" "aws_load_balancer_controller" {
  role       = aws_iam_role.aws_load_balancer_controller.name
  policy_arn = aws_iam_policy.lb_controller_policy.arn
}
#--------------------------------------------------------------------------------