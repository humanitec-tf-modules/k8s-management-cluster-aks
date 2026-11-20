# See https://developer.hashicorp.com/terraform/language/tests for more on how to write tests.
# See https://developer.hashicorp.com/terraform/language/tests/mocking for information on mocking providers.
#
# All providers are mocked, so these tests run without Azure credentials and create no real infrastructure.

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

run "creates_group_with_defaults" {
  command = apply

  assert {
    condition     = length(azuread_group.orchestrator_deploy_access) == 1
    error_message = "The deploy access group must be created when no existing group is passed in"
  }

  assert {
    condition     = azuread_group.orchestrator_deploy_access[0].display_name == "Humanitec Orchestrator deploy access to AKS cluster my-aks (resource group my-rg, subscription 00000000-0000-0000-0000-000000000001)"
    error_message = "The group display name must be derived from cluster name, resource group, and subscription"
  }

  assert {
    condition     = azuread_group.orchestrator_deploy_access[0].security_enabled
    error_message = "The group must be a security group"
  }

  assert {
    condition     = toset(azuread_group.orchestrator_deploy_access[0].owners) == toset(["00000000-0000-0000-0000-00000000000c"])
    error_message = "The group owner must default to the current client"
  }

  assert {
    condition     = azuread_group_member.orchestrator_deploy_access.group_object_id == "00000000-0000-0000-0000-00000000000a"
    error_message = "The cloud account principal must be added to the created group"
  }

  assert {
    condition     = azuread_group_member.orchestrator_deploy_access.member_object_id == "00000000-0000-0000-0000-00000000000b"
    error_message = "The group member must be the cloud account principal"
  }

  assert {
    condition     = azurerm_role_assignment.orchestrator_deploy_access_cluster_user.principal_id == "00000000-0000-0000-0000-00000000000a"
    error_message = "The role must be assigned to the created group"
  }

  assert {
    condition     = azurerm_role_assignment.orchestrator_deploy_access_cluster_user.scope == "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/my-rg/providers/Microsoft.ContainerService/managedClusters/my-aks"
    error_message = "The role must be assigned on the AKS cluster scope"
  }

  assert {
    condition     = azurerm_role_assignment.orchestrator_deploy_access_cluster_user.role_definition_name == "Azure Kubernetes Service Cluster User Role"
    error_message = "The role must be the AKS Cluster User Role"
  }

  assert {
    condition     = output.deploy_access_group_object_id == "00000000-0000-0000-0000-00000000000a"
    error_message = "The group output must be the object ID of the created group"
  }

  assert {
    condition     = output.role_assignment_id == azurerm_role_assignment.orchestrator_deploy_access_cluster_user.id
    error_message = "The role assignment output must be the role assignment ID"
  }

  assert {
    condition     = output.aks_cluster_id == "/subscriptions/00000000-0000-0000-0000-000000000001/resourceGroups/my-rg/providers/Microsoft.ContainerService/managedClusters/my-aks"
    error_message = "The cluster output must be the AKS cluster ID"
  }
}

run "creates_group_with_custom_name_and_owners" {
  command = apply

  variables {
    deploy_access_group_display_name = "my-custom-group"
    deploy_access_group_owners = [
      "00000000-0000-0000-0000-0000000000d1",
      "00000000-0000-0000-0000-0000000000d2",
    ]
  }

  assert {
    condition     = azuread_group.orchestrator_deploy_access[0].display_name == "my-custom-group"
    error_message = "The group display name must use the value passed in"
  }

  assert {
    condition     = toset(azuread_group.orchestrator_deploy_access[0].owners) == toset(["00000000-0000-0000-0000-0000000000d1", "00000000-0000-0000-0000-0000000000d2"])
    error_message = "The group owners must use the values passed in"
  }
}

run "uses_existing_group" {
  command = apply

  variables {
    deploy_access_group_object_id = "00000000-0000-0000-0000-0000000000e1"
  }

  assert {
    condition     = length(azuread_group.orchestrator_deploy_access) == 0
    error_message = "No group must be created when an existing group is passed in"
  }

  assert {
    condition     = azuread_group_member.orchestrator_deploy_access.group_object_id == "00000000-0000-0000-0000-0000000000e1"
    error_message = "The cloud account principal must be added to the existing group"
  }

  assert {
    condition     = azurerm_role_assignment.orchestrator_deploy_access_cluster_user.principal_id == "00000000-0000-0000-0000-0000000000e1"
    error_message = "The role must be assigned to the existing group"
  }

  assert {
    condition     = output.deploy_access_group_object_id == "00000000-0000-0000-0000-0000000000e1"
    error_message = "The group output must be the object ID of the existing group"
  }
}

run "rejects_invalid_principal_object_id" {
  command = plan

  variables {
    cloud_account_principal_object_id = "not-a-uuid"
  }

  expect_failures = [var.cloud_account_principal_object_id]
}

run "rejects_invalid_group_object_id" {
  command = plan

  variables {
    deploy_access_group_object_id = "not-a-uuid"
  }

  expect_failures = [var.deploy_access_group_object_id]
}

run "rejects_invalid_group_owners" {
  command = plan

  variables {
    deploy_access_group_owners = ["not-a-uuid"]
  }

  expect_failures = [var.deploy_access_group_owners]
}

run "rejects_empty_group_display_name" {
  command = plan

  variables {
    deploy_access_group_display_name = ""
  }

  expect_failures = [var.deploy_access_group_display_name]
}
