locals {
  name         = "ditch-aws-auth"
  cluster_name = format("%s-%s", local.name, "eks-cluster")

  default_tags = {
    stack       = local.name
    terraform   = true
    description = "Demo usage of access entries for authentication mode."
  }
}

module "vpc" {
  count          = var.create_vpc ? 1 : 0
  source         = "./modules/vpc"
  stack_name     = local.name
  vpc_cidr_block = "10.1.0.0/16"

  list_of_azs        = ["ap-southeast-1a", "ap-southeast-1b", "ap-southeast-1c"]
  list_of_cidr_range = ["10.1.101.0/24", "10.1.102.0/24", "10.1.103.0/24"]

  default_tags = local.default_tags
}

resource "aws_iam_role" "eksClusterReadOnlyRole" {
  name        = "cluster-read-only"
  description = "Sample IAM role to map to an access entry"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "eks.amazonaws.com"
        }
      },
    ]
  })

  tags = local.default_tags
}

resource "aws_eks_access_entry" "eksClusterReadOnlyAccessEntry" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.eksClusterReadOnlyRole.arn
  # kubernetes_groups = ["group-1", "group-2"]
  type = "STANDARD"
}

resource "aws_eks_access_policy_association" "eksClusterReadOnlyAccessPolicy" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  principal_arn = aws_iam_role.eksClusterReadOnlyRole.arn

  access_scope {
    type = "cluster" # namespace | cluster
    # namespaces = ["example-namespace"]
  }
}