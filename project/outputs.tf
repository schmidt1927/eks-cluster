output "cluster_name" { value = local.cluster_name }
output "region"       { value = var.region }
output "vpc_id"       { value = aws_vpc.this.id }
