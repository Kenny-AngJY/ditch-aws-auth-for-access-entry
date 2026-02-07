module "eks" {
  source                                 = "terraform-aws-modules/eks/aws"
  version                                = "21.15.1" # Published January 21, 2026
  create                                 = true
  name                                   = local.cluster_name
  kubernetes_version                     = "1.35"
  authentication_mode                    = "API" # API | CONFIG_MAP | API_AND_CONFIG_MAP
  endpoint_private_access                = true  # Indicates whether or not the Amazon EKS private API server endpoint is enabled
  endpoint_public_access                 = true  # Indicates whether or not the Amazon EKS public API server endpoint is enabled
  cloudwatch_log_group_retention_in_days = 30
  create_kms_key                         = var.create_kms_key
  enable_irsa                            = true # Determines whether to create an OpenID Connect Provider for EKS to enable IRSA

  encryption_config = {}

  addons = {
    coredns = {
      before_compute = true
      most_recent    = true
    }
    # kube-proxy pod (that is deployed as a daemonset) shares the same IPv4 address as the node it's on.
    kube-proxy = {
      before_compute = true
      most_recent    = true
    }
    # Network interface will show all IPs used in the subnet
    # VPC CNI add-on will create the "aws-node" daemonset in the kube-system namespace.
    vpc-cni = {
      before_compute           = true
      addon_version            = "v1.21.1-eksbuild.3" # major-version.minor-version.patch-version-eksbuild.build-number.
      service_account_role_arn = aws_iam_role.eks_vpc_cni_role.arn
      configuration_values = jsonencode(
        {
          enableNetworkPolicy = "true" # To enable using the NetworkPolicy controller
          env = {
            # https://docs.aws.amazon.com/eks/latest/userguide/cni-increase-ip-addresses.html
            # https://github.com/aws/amazon-vpc-cni-k8s/blob/master/README.md
            # kubectl get ds aws-node -n kube-system -o yaml
            WARM_IP_TARGET    = "3" # Specifies the number of free IP addresses that the ipamd daemon should attempt to keep available for pod assignment on the node.
            MINIMUM_IP_TARGET = "3" # Specifies the number of total IP addresses that the ipamd daemon should attempt to allocate for pod assignment on the node.
            # ENABLE_PREFIX_DELEGATION = true # To enable prefix delegation on nitro instances. Setting ENABLE_PREFIX_DELEGATION to true will start allocating a prefix (/28 for IPv4 and /80 for IPv6) instead of a secondary IP in the ENIs subnet.
            # NETWORK_POLICY_ENFORCING_MODE = "strict" # strict | standard
          }
        }
      )
    }
  }

  vpc_id = var.create_vpc ? module.vpc[0].vpc_id : var.vpc_id
  /* -----------------------------------------------------------------------------------
  A list of subnet IDs where the nodes/node groups will be provisioned.
  If control_plane_subnet_ids is not provided, the EKS cluster control plane (ENIs) will be provisioned in these subnets
  ----------------------------------------------------------------------------------- */
  subnet_ids = var.create_vpc ? (var.create_eks_worker_nodes_in_private_subnet ? module.vpc[0].list_of_private_subnet_ids : module.vpc[0].list_of_public_subnet_ids) : var.list_of_subnet_ids

  /* -----------------------------------------------------------------------------------
  A list of subnet IDs where the EKS Managed ENIs will be provisioned.
  Used for expanding the pool of subnets used by nodes/node groups without replacing the EKS control plane
  ----------------------------------------------------------------------------------- */
  control_plane_subnet_ids = var.create_vpc ? (var.create_eks_worker_nodes_in_private_subnet ? module.vpc[0].list_of_private_subnet_ids : module.vpc[0].list_of_public_subnet_ids) : var.list_of_subnet_ids

  # EKS Managed Node Group(s)
  eks_managed_node_groups = {
    node_group_1 = {
      instance_types = ["t3.medium", "t3.large"]
      min_size       = 1
      max_size       = 1
      desired_size   = 1
      capacity_type  = "SPOT"
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

  enabled_log_types = [
    "audit",
    "api",
    "authenticator",
    "controllerManager",
    "scheduler"
  ]
  deletion_protection = false
  tags                = local.default_tags
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