locals {
  name_prefix  = "${var.project}-${var.environment}"
  cluster_name = "${local.name_prefix}-eks"
  tags = {
    Project     = var.project
    Environment = var.environment
    Terraform   = "true"
  }
}
