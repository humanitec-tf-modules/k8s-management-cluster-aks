terraform {
  # The management-cluster-k8s child module requires >= 1.11.0 for write-only attributes
  required_version = ">= 1.11.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 3"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.0.0, < 6.0.0"
    }
    humanitec = {
      source  = "humanitec/humanitec"
      version = "~> 1.9"
    }
  }
}
