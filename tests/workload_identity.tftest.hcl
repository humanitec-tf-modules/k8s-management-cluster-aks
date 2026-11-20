# Verifies the Helm chart values making the Operator use Azure Workload Identity, and their merging with values passed in.
#
# All providers are mocked, so these tests run without Azure credentials, a Kubernetes cluster, or a Humanitec Organization.

mock_provider "azurerm" {
  mock_data "azurerm_kubernetes_cluster" {
    defaults = {
      id = "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/my-rg/providers/Microsoft.ContainerService/managedClusters/my-aks"
    }
  }
}

mock_provider "azuread" {
  mock_data "azuread_client_config" {
    defaults = {
      object_id = "00000000-0000-0000-0000-00000000000c"
    }
  }
  mock_resource "azuread_group" {
    defaults = {
      object_id = "00000000-0000-0000-0000-00000000000a"
    }
  }
}

mock_provider "kubernetes" {}
mock_provider "helm" {}
mock_provider "humanitec" {}
mock_provider "random" {}
mock_provider "tls" {}

variables {
  aks_name                          = "my-aks"
  aks_resource_group                = "my-rg"
  cloud_account_principal_object_id = "00000000-0000-0000-0000-00000000000b"
  cloud_account_id                  = "my-azure-cloud-account"

  # terraform test sets the default of an ephemeral root variable only during apply, failing the apply. Set it explicitly
  helm_release_set_wo = []

  workload_identity_client_id = "22222222-2222-2222-2222-222222222222"
}

run "adds_workload_identity_values_by_default" {
  command = plan

  assert {
    condition     = length(local.helm_release_values) == 1
    error_message = "Only the Workload Identity values must be set if no values are passed in"
  }

  assert {
    condition     = yamldecode(local.helm_release_values[0]).controllerManager.serviceAccount.annotations["azure.workload.identity/client-id"] == "22222222-2222-2222-2222-222222222222"
    error_message = "The service account annotation must hold the Workload Identity client ID"
  }

  assert {
    condition     = yamldecode(local.helm_release_values[0]).controllerManager.podLabels["azure.workload.identity/use"] == "true"
    error_message = "The Pod label azure.workload.identity/use must be the string \"true\""
  }
}

run "merges_workload_identity_values_with_values_passed_in" {
  command = plan

  variables {
    helm_release_values = [
      yamlencode({ controllerManager = { podLabels = { team = "platform" } } }),
      yamlencode({ foo = "bar" }),
    ]
  }

  assert {
    condition     = length(local.helm_release_values) == 3
    error_message = "The Workload Identity values and all values passed in must be set"
  }

  assert {
    condition     = yamldecode(local.helm_release_values[0]).controllerManager.serviceAccount.annotations["azure.workload.identity/client-id"] == "22222222-2222-2222-2222-222222222222"
    error_message = "The Workload Identity values must come first so that the values passed in take precedence"
  }

  assert {
    condition     = slice(local.helm_release_values, 1, 3) == tolist(var.helm_release_values)
    error_message = "The values passed in must follow the Workload Identity values in their original order"
  }
}

run "omits_workload_identity_values_if_disabled" {
  command = plan

  variables {
    use_workload_identity       = false
    workload_identity_client_id = null
  }

  assert {
    condition     = local.helm_release_values == null
    error_message = "No Helm values must be set if Workload Identity is disabled and no values are passed in"
  }
}

run "passes_values_through_if_disabled" {
  command = plan

  variables {
    use_workload_identity = false
    helm_release_values   = [yamlencode({ foo = "bar" })]
  }

  assert {
    condition     = local.helm_release_values == tolist(var.helm_release_values)
    error_message = "The values passed in must be used unchanged if Workload Identity is disabled"
  }
}

run "rejects_missing_client_id" {
  command = plan

  variables {
    workload_identity_client_id = null
  }

  expect_failures = [var.workload_identity_client_id]
}

run "rejects_invalid_client_id" {
  command = plan

  variables {
    workload_identity_client_id = "not-a-uuid"
  }

  expect_failures = [var.workload_identity_client_id]
}
