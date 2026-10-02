# IAM module — human and machine access to the platform, least-privilege by default.
#
# Two roles:
#   1. cluster-admin   — for platform engineers (assumable by SSO/admin principals).
#      Maps to the Kubernetes cluster-admin ClusterRole via aws-iam-authenticator.
#   2. ci-deployer      — for the CI system. Scoped to describing the cluster,
#      pushing/pulling ECR images, and nothing else. No console access.

# --- Cluster admin role ------------------------------------------------------
resource "aws_iam_role" "cluster_admin" {
  name        = "${var.name_prefix}-cluster-admin"
  description = "Platform engineers: full EKS admin via aws-iam-authenticator mapping. Assumable only by the listed SSO/admin principals."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = var.admin_principal_arns }
      Action    = "sts:AssumeRole"
      Condition = { Bool = { "aws:MultiFactorAuthPresent" = "true" } }
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_admin_eks" {
  role       = aws_iam_role.cluster_admin.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# --- CI deployer role ---------------------------------------------------------
resource "aws_iam_role" "ci_deployer" {
  name        = "${var.name_prefix}-ci-deployer"
  description = "CI system: describe the EKS cluster and push/pull ECR images. Cannot touch IAM, VPCs, or nodes."

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = var.ci_principal_arns }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "sts:ExternalId" = var.ci_external_id }
      }
    }]
  })

  tags = var.tags
}

resource "aws_iam_policy" "ci_deployer" {
  name        = "${var.name_prefix}-ci-deployer-policy"
  description = "Scoped CI permissions: read the cluster, manage ECR images, write deploy logs."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DescribeCluster"
        Effect   = "Allow"
        Action   = ["eks:DescribeCluster", "eks:ListClusters"]
        Resource = var.cluster_arn
      },
      {
        Sid    = "EcrAuth"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        # GetAuthorizationToken only supports "*".
        Resource = "*"
      },
      {
        Sid      = "EcrPushPull"
        Effect   = "Allow"
        Action   = ["ecr:BatchCheckLayerAvailability", "ecr:BatchGetImage", "ecr:CompleteLayerUpload", "ecr:InitiateLayerUpload", "ecr:PutImage", "ecr:UploadLayerPart"]
        Resource = "arn:aws:ecr:${var.region}:${var.account_id}:repository/${var.name_prefix}/*"
      },
      {
        Sid      = "DeployLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${var.region}:${var.account_id}:log-group:/ci/${var.name_prefix}/*"
      },
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ci_deployer" {
  role       = aws_iam_role.ci_deployer.name
  policy_arn = aws_iam_policy.ci_deployer.arn
}
