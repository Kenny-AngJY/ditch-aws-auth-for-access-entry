/* -----------------------------------------------------------------------------------
eksClusterReadOnlyRole
----------------------------------------------------------------------------------- */
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
}

/* -----------------------------------------------------------------------------------
VPC CNI
----------------------------------------------------------------------------------- */
resource "aws_iam_role" "eks_vpc_cni_role" {
  name        = "vpc-cni-irsa"
  description = "IAM role for VPC-CNI add-on"

  assume_role_policy = var.use_eks_pod_identity_agent ? jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowEksAuthToAssumeRoleForPodIdentity",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "pods.eks.amazonaws.com"
        },
        "Action" : [
          "sts:AssumeRole",
          "sts:TagSession"
        ],
        "Condition" : {
          "StringEquals" : {
            "aws:SourceAccount" : "${data.aws_caller_identity.current.id}"
          },
          "ArnEquals" : {
            "aws:SourceArn" : "${module.eks.cluster_arn}"
          }
        }
      }
    ]
    }) : jsonencode({
    "Version" : "2012-10-17"
    "Statement" : [
      {
        "Effect" : "Allow",
        "Principal" : {
          "Federated" : "${module.eks.oidc_provider_arn}"
        },
        "Action" : "sts:AssumeRoleWithWebIdentity",
        "Condition" : {
          "StringLike" : {
            "${module.eks.oidc_provider}:sub" : "system:serviceaccount:kube-system:aws-node",
            "${module.eks.oidc_provider}:aud" : "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "eks_vpc_cni_policy_attachment" {
  role       = aws_iam_role.eks_vpc_cni_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_eks_pod_identity_association" "example" {
  count           = var.use_eks_pod_identity_agent ? 1 : 0
  cluster_name    = module.eks.cluster_name
  namespace       = "kube-system"
  service_account = "aws-node"
  role_arn        = aws_iam_role.eks_vpc_cni_role.arn
}