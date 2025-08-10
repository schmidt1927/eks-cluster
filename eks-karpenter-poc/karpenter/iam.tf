# IRSA for Karpenter controller
resource "aws_iam_role" "karpenter_controller" {
  name               = "${local.cluster_name}-karpenter-controller"
  assume_role_policy = data.aws_iam_policy_document.karpenter_irsa.json
  tags               = local.tags
}

data "aws_iam_policy_document" "karpenter_irsa" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals { type = "Federated" identifiers = [aws_iam_openid_connect_provider.eks.arn] }
    condition {
      test     = "StringEquals"
      variable = "${replace(aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub"
      values   = ["system:serviceaccount:karpenter:karpenter"]
    }
  }
}

# OIDC provider for cluster
resource "aws_iam_openid_connect_provider" "eks" {
  url             = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.${data.aws_partition.current.dns_suffix}"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
}

data "tls_certificate" "oidc" { url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer }

# Minimal Karpenter controller policy (POC). For prod, sync with upstream.
resource "aws_iam_policy" "karpenter_controller" {
  name   = "${local.cluster_name}-karpenter-controller"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { "Effect": "Allow", "Action": [
          "ec2:CreateLaunchTemplate",
          "ec2:DeleteLaunchTemplate",
          "ec2:CreateFleet",
          "ec2:RunInstances",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:TerminateInstances",
          "ec2:Describe*",
          "iam:PassRole"
        ], "Resource": "*" },
      { "Effect": "Allow", "Action": [
          "pricing:GetProducts",
          "ssm:GetParameter"
        ], "Resource": "*" }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "karpenter_controller_attach" {
  role       = aws_iam_role.karpenter_controller.name
  policy_arn = aws_iam_policy.karpenter_controller.arn
}

# Node role used by instances that Karpenter creates
resource "aws_iam_role" "karpenter_node" {
  name               = "${local.cluster_name}-karpenter-node"
  assume_role_policy = data.aws_iam_policy_document.ng_assume.json
  tags               = local.tags
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_role_policy_attachment" "node_ssm" {
  role       = aws_iam_role.karpenter_node.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "karpenter_node" {
  name = "${local.cluster_name}-karpenter-node"
  role = aws_iam_role.karpenter_node.name
}
