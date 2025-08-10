resource "kubernetes_namespace" "karpenter" {
  metadata { name = "karpenter" }
}

# Install Karpenter via OCI helm chart
resource "helm_release" "karpenter" {
  name       = "karpenter"
  namespace  = kubernetes_namespace.karpenter.metadata[0].name
  repository = "oci://public.ecr.aws/karpenter/karpenter"
  chart      = "karpenter"
  # Pin a recent version; update as needed.
  version    = "v0.37.0"

  values = [
    yamlencode({
      serviceAccount = {
        annotations = {
          "eks.amazonaws.com/role-arn" = aws_iam_role.karpenter_controller.arn
        }
      }
      settings = {
        clusterName       = aws_eks_cluster.this.name
        clusterEndpoint   = data.aws_eks_cluster.this.endpoint
        interruptionQueue = null
      }
    })
  ]

  depends_on = [aws_eks_node_group.bootstrap]
}
