# Create a K8S personal lab environment
# Let's start by setting up remote state, for both sharing and referencing in other templates
terraform {
  backend "s3" {
    bucket = "bobs-tfstates-bucket"
    key    = "demo_projects/hello_rails/tf_infra/"
    region = "us-east-1"
    dynamodb_table = "terraform_locks"
  }
}

provider "aws" {
  # Credentials expected from ENV or ~/.aws/credentials
  version = "~> 2.0"
  region  = var.primary_aws_region
}

locals {
  tags = merge({ Terraform = "true" }, { Workspace = terraform.workspace}, { Name_prefix = var.name_prefix }, var.tags)
  kubeconfig = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    server: ${aws_eks_cluster.k8s.endpoint}
    certificate-authority-data: ${aws_eks_cluster.k8s.certificate_authority.0.data}
  name: kubernetes
contexts:
- context:
    cluster: kubernetes
    user: aws
  name: aws
current-context: aws
kind: Config
preferences: {}
users:
- name: aws
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - ${aws_eks_cluster.k8s.name}
KUBECONFIG
}

# First we setup all networking related concerns, like a VPC and default security groups.
# External modules can be restrictive at times, but they're also quite convenient so...
module "k8s_vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.21.0"

  name = join("-", [var.name_prefix, "k8s-vpc", terraform.workspace])
  cidr = var.main_vpc_cidr

  azs             = data.aws_availability_zones.available.names
  private_subnets = var.main_vpc_private_subnets
  public_subnets  = var.main_vpc_public_subnets

  enable_nat_gateway = true
  single_nat_gateway = true
  enable_vpn_gateway = false

  create_database_subnet_group = false

  tags = local.tags
}

# The main Application Load Balancer that will shield our instances and provide ssl offloading
resource aws_security_group "k8s_alb" {
  name_prefix = "${var.name_prefix}-k8s-alb-${terraform.workspace}"
  description = "Allows traffic from internet to LB, and from LB to destination target groups"
  vpc_id      = module.k8s_vpc.vpc_id
  # Rules not included. Using external rules allows instances to add themselves as needed
}

resource "aws_security_group_rule" "k8s_alb_443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.k8s_alb.id
}

resource aws_lb "k8s" {
  # lb name_prefixes must be 6 characters or less
  name_prefix        = "k8s${substr(terraform.workspace, 0, 3)}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.k8s_alb.id]
  subnets            = module.k8s_vpc.public_subnets
  tags               = local.tags
}

resource "aws_lb_listener" "k8s_443" {
  load_balancer_arn = aws_lb.k8s.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = var.certificate_arn
  # We use host-based routing, so we need a default message if the LB is reached through
  # unintended means, like IP or AWS-assigned DNS entry.
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "There's nothing here :O You sure you got the address right?"
      status_code  = "404"
    }
  }
}

resource aws_security_group "k8s" {
  name_prefix = join( "-", [var.name_prefix, "k8s", terraform.workspace])
  description = "Allows http ingress from main ALB"
  vpc_id      = module.k8s_vpc.vpc_id

  ingress {
    # Default rails port
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    # Limit traffic to only this VPC; public subnets contain the LB
    # and private subnets contain the EKS + FARGATE K8S pods
    cidr_blocks = concat(var.main_vpc_public_subnets, var.main_vpc_private_subnets)
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# K8S shtuff
resource "aws_iam_role" "k8s" {
  name_prefix = "${var.name_prefix}-k8s-eks-${terraform.workspace}"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY

}

resource "aws_iam_role_policy_attachment" "k8s-eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy" # This is an Amazon managed policy
  role       = aws_iam_role.k8s.name
}

resource "aws_iam_role_policy_attachment" "k8s-eks_service_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSServicePolicy" # This is an amazon managed policy
  role       = aws_iam_role.k8s.name
}

resource "aws_eks_cluster" "k8s" {
  name     = join("-", [var.name_prefix, "k8s", terraform.workspace])
  role_arn = aws_iam_role.k8s.arn

  vpc_config {
    subnet_ids = module.k8s_vpc.private_subnets
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Cluster handling.
  # Otherwise, EKS will not be able to properly delete EKS managed EC2 infrastructure such as Security Groups.
  depends_on = [
    aws_iam_role_policy_attachment.k8s-eks_cluster_policy,
    aws_iam_role_policy_attachment.k8s-eks_service_policy,
  ]
}

# A CNAME + ALIAS record for the K8S endpoint
resource "aws_route53_record" "k8s" {
  zone_id = var.r53_zone_id
  name = "k8s.${data.aws_route53_zone.this.name}"
  type = "CNAME"
  ttl = 300
  records = [aws_eks_cluster.k8s.endpoint]
}

#resource "aws_route53_record" "k8s_alias" {
#  zone_id = var.r53_zone_id
#  name = "k8s.${data.aws_route53_zone.this.name}"
#  type = "CNAME"
#
#  alias {
#    name = "k8s_c.${data.aws_route53_zone.this.name}"
#    zone_id = var.r53_zone_id
#    evaluate_target_health = false
#  }
#  depends_on = [aws_route53_record.k8s]
#}

resource "aws_eks_fargate_profile" "k8s" {
  cluster_name           = aws_eks_cluster.k8s.name
  fargate_profile_name   = join("-", [var.name_prefix, "k8s", terraform.workspace])
  pod_execution_role_arn = aws_iam_role.k8s_fargate_default.arn
  subnet_ids             = module.k8s_vpc.private_subnets

  selector {
    namespace = "fargate"
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_role" "k8s_fargate_default" {
  name_prefix = join("-", [var.name_prefix, "k8s_fargate", terraform.workspace])
  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks-fargate-pods.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}
