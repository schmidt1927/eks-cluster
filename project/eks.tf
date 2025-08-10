# EKS control-plane role
resource "aws_iam_role" "eks" {
  name               = "${local.cluster_name}-control-plane"
  assume_role_policy = data.aws_iam_policy_document.eks_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "eks_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["eks.amazonaws.com"] }
  }
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_security_group" "cluster" {
  name        = "${local.cluster_name}-sg"
  description = "Cluster communication with worker nodes"
  vpc_id      = aws_vpc.this.id
  tags        = merge(local.tags, { 
    Name = "${local.cluster_name}-sg",
    # Allow Karpenter to discover and use this SG
    "karpenter.sh/discovery" = local.cluster_name
  })
}

resource "aws_eks_cluster" "this" {
  name     = local.cluster_name
  version  = var.k8s_version
  role_arn = aws_iam_role.eks.arn

  vpc_config {
    subnet_ids              = concat([for s in aws_subnet.public : s.id], [for s in aws_subnet.private : s.id])
    endpoint_public_access  = true
    endpoint_private_access = false
    security_group_ids      = [aws_security_group.cluster.id]
  }

  tags = local.tags
}

# Small bootstrap node group so cluster components can start; Karpenter does the rest
resource "aws_iam_role" "ng" {
  name               = "${local.cluster_name}-ng"
  assume_role_policy = data.aws_iam_policy_document.ng_assume.json
  tags               = local.tags
}

data "aws_iam_policy_document" "ng_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["ec2.amazonaws.com"] }
  }
}

resource "aws_iam_role_policy_attachment" "ng_worker" {
  role       = aws_iam_role.ng.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "ng_cni" {
  role       = aws_iam_role.ng.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "ng_ecr" {
  role       = aws_iam_role.ng.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
resource "aws_iam_role_policy_attachment" "ng_ssm" {
  role       = aws_iam_role.ng.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_eks_node_group" "bootstrap" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "bootstrap"
  node_role_arn   = aws_iam_role.ng.arn
  subnet_ids      = [for s in aws_subnet.private : s.id]

  scaling_config { desired_size = 1, min_size = 1, max_size = 1 }
  instance_types = [var.bootstrap_instance_type]

  update_config { max_unavailable = 1 }

  tags = merge(local.tags, { Name = "${local.cluster_name}-bootstrap" })
}

# Providers need cluster connection
data "aws_eks_cluster" "this" { name = aws_eks_cluster.this.name }
data "aws_eks_cluster_auth" "this" { name = aws_eks_cluster.this.name }
