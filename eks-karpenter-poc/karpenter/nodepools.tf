# A shared EC2NodeClass that discovers subnets/SGs via tags and sets the instance role.
resource "kubernetes_manifest" "ec2_nodeclass_general" {
  manifest = {
    apiVersion = "karpenter.k8s.aws/v1beta1"
    kind       = "EC2NodeClass"
    metadata   = { name = "general" }
    spec = {
      amiFamily = "AL2"
      role      = aws_iam_role.karpenter_node.name
      subnetSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = local.cluster_name } }
      ]
      securityGroupSelectorTerms = [
        { tags = { "karpenter.sh/discovery" = local.cluster_name } }
      ]
      tags = {
        "KubernetesCluster" = local.cluster_name
      }
    }
  }

  depends_on = [helm_release.karpenter]
}

# x86/amd64 pool with Spot preference
resource "kubernetes_manifest" "nodepool_amd64" {
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata   = { name = "amd64-spot" }
    spec = {
      template = {
        spec = {
          nodeClassRef = { name = kubernetes_manifest.ec2_nodeclass_general.manifest.metadata.name }
          requirements = [
            { key = "kubernetes.io/arch", operator = "In", values = ["amd64"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot", "on-demand"] },
          ]
          kubelet = { systemReserved = { "cpu" = "100m", "memory" = "200Mi" } }
        }
      }
      limits = { cpu = "1000" }
      disruption = { consolidationPolicy = "WhenUnderutilized" }
    }
  }
  depends_on = [kubernetes_manifest.ec2_nodeclass_general]
}

# arm64/Graviton pool
resource "kubernetes_manifest" "nodepool_arm64" {
  manifest = {
    apiVersion = "karpenter.sh/v1beta1"
    kind       = "NodePool"
    metadata   = { name = "arm64-spot" }
    spec = {
      template = {
        spec = {
          nodeClassRef = { name = kubernetes_manifest.ec2_nodeclass_general.manifest.metadata.name }
          requirements = [
            { key = "kubernetes.io/arch", operator = "In", values = ["arm64"] },
            { key = "karpenter.sh/capacity-type", operator = "In", values = ["spot", "on-demand"] },
          ]
          kubelet = { systemReserved = { "cpu" = "100m", "memory" = "200Mi" } }
        }
      }
      limits = { cpu = "1000" }
      disruption = { consolidationPolicy = "WhenUnderutilized" }
    }
  }
  depends_on = [kubernetes_manifest.ec2_nodeclass_general]
}
