module "eks" {
  source                                 = "terraform-aws-modules/eks/aws"
  version                                = "20.8.5"
  cluster_name                           = local.cluster_name
  cluster_version                        = "1.29"
  authentication_mode                    = "API" # API | CONFIG_MAP | API_AND_CONFIG_MAP
  cluster_endpoint_public_access         = true
  cloudwatch_log_group_retention_in_days = 30
  create_kms_key                         = false

  cluster_encryption_config = {}

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id     = var.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  subnet_ids = var.create_vpc ? module.vpc[0].list_of_subnet_ids : var.list_of_subnet_ids

  # EKS Managed Node Group(s)
  eks_managed_node_group_defaults = {
    instance_types = ["t3.small"]
  }

  eks_managed_node_groups = {
    node_group_1 = {
      min_size     = 1
      max_size     = 1
      desired_size = 1

      capacity_type = "SPOT"
    }
  }

  # Cluster access entry
  # To add the current caller identity as an administrator
  enable_cluster_creator_admin_permissions = true

  /*
  Instead of creating additional access entries within this module, 
  I have created them below as a standalone resource block instead 
  for clarity and better understanding.
  */
  # access_entries = {
  #   # One access entry with a policy associated
  #   example = {
  #     kubernetes_groups = []
  #     principal_arn     = "arn:aws:iam::123456789012:role/something"

  #     policy_associations = {
  #       example = {
  #         policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  #         access_scope = {
  #           namespaces = ["default"]
  #           type       = "namespace"
  #         }
  #       }
  #     }
  #   }
  # }

  cluster_enabled_log_types = [
    "audit",
    "api",
    "authenticator"
  ]

  tags = local.default_tags
}

# Create an access entry for the "cluster-read-only" IAM role
resource "aws_eks_access_entry" "eksClusterReadOnlyAccessEntry" {
  cluster_name  = module.eks.cluster_name
  principal_arn = aws_iam_role.eksClusterReadOnlyRole.arn
  # kubernetes_groups = ["group-1", "group-2"]
  type = "STANDARD"
}

/*
Associate an access policy to the above access entry.
If none of the access policies meet your requirements, then don't associate an access policy to an access entry. 
Instead, specify Kubernetes group name(s) for the access entry within the "aws_eks_access_entry" resource block.
*/
resource "aws_eks_access_policy_association" "eksClusterReadOnlyAccessPolicy" {
  cluster_name  = module.eks.cluster_name
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSViewPolicy"
  principal_arn = aws_iam_role.eksClusterReadOnlyRole.arn

  access_scope {
    type = "cluster" # namespace | cluster
    # namespaces = ["example-namespace"]
  }
}