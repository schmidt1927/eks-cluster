terraform {
  required_version = ">= 1.7.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.50"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.13"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.29"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0"
    }
  }
}
