variable "project" { type = string }
variable "environment" { type = string }
variable "region" { type = string }

variable "cidr_block" { type = string }
variable "public_subnets" { type = list(string) }
variable "private_subnets" { type = list(string) }

variable "az_count" { type = number default = 2 }

# Default to a modern EKS version – keep this updated as needed.
variable "k8s_version" { type = string default = "1.30" }

# Minimal managed node group to bootstrap core add-ons; Karpenter handles scale.
variable "bootstrap_instance_type" { type = string default = "t3.small" }
