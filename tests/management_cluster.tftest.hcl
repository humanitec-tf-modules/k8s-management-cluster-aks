# Verifies the inputs this module sets on the management-cluster-k8s module, and that variables are passed through.
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

run "sets_fixed_aks_inputs" {
  command = apply

  assert {
    condition     = module.management_cluster.resource_definition_driver_type == "humanitec/k8s-cluster-aks"
    error_message = "The Driver must be humanitec/k8s-cluster-aks"
  }

  assert {
    condition     = startswith(module.management_cluster.resource_definition_id, "management-cluster-aks-")
    error_message = "The generated Resource Definition ID must use the default prefix management-cluster-aks"
  }

  assert {
    condition     = module.management_cluster.cluster_access_subject.kind == "Group"
    error_message = "The cluster access subject must be a Group"
  }

  assert {
    condition     = module.management_cluster.cluster_access_subject.name == "00000000-0000-0000-0000-00000000000a"
    error_message = "The cluster access subject must be the object ID of the deploy access group"
  }

  assert {
    condition     = toset(keys(local.cluster_values)) == toset(["loadbalancer", "name", "resource_group", "server_app_id", "subscription_id"])
    error_message = "The cluster values must have exactly the keys loadbalancer, name, resource_group, server_app_id, subscription_id"
  }

  assert {
    condition     = local.cluster_values.loadbalancer == null
    error_message = "The loadbalancer cluster value must be null by default so that the Driver default applies"
  }

  assert {
    condition     = local.cluster_values.name == "my-aks"
    error_message = "The name cluster value must be the AKS cluster name"
  }

  assert {
    condition     = local.cluster_values.resource_group == "my-rg"
    error_message = "The resource_group cluster value must be the AKS resource group"
  }

  assert {
    condition     = local.cluster_values.server_app_id == "6dae42f8-4368-4678-94ff-3960e28e3630"
    error_message = "The server_app_id cluster value must be the AKS Entra ID server application ID"
  }

  assert {
    condition     = local.cluster_values.subscription_id == "00000000-0000-0000-0000-000000000001"
    error_message = "The subscription_id cluster value must be the subscription of the AKS cluster"
  }
}

run "sets_loadbalancer_and_existing_group" {
  command = apply

  variables {
    loadbalancer                  = "10.0.0.1"
    deploy_access_group_object_id = "00000000-0000-0000-0000-0000000000e1"
  }

  assert {
    condition     = local.cluster_values.loadbalancer == "10.0.0.1"
    error_message = "The loadbalancer cluster value must be taken from the loadbalancer variable"
  }

  assert {
    condition     = module.management_cluster.cluster_access_subject.name == "00000000-0000-0000-0000-0000000000e1"
    error_message = "The cluster access subject must be the object ID of the existing group"
  }
}

run "passes_through_variables" {
  command = apply

  variables {
    resource_definition_id       = "my-cluster"
    cluster_role_name            = "my-deploy-access"
    helm_release_name            = "my-operator"
    helm_release_namespace       = "my-namespace"
    helm_release_version         = "1.2.3"
    helm_release_repository      = "oci://example.com/charts"
    helm_release_chart           = "my-chart"
    enable_driver_authentication = true
    humanitec_org_id             = "my-org"
  }

  assert {
    condition     = module.management_cluster.resource_definition_id == "my-cluster"
    error_message = "resource_definition_id must be passed through"
  }

  assert {
    condition     = module.management_cluster.cluster_role_name == "my-deploy-access"
    error_message = "cluster_role_name must be passed through"
  }

  assert {
    condition     = module.management_cluster.helm_release_name == "my-operator"
    error_message = "helm_release_name must be passed through"
  }

  assert {
    condition     = module.management_cluster.helm_release_namespace == "my-namespace"
    error_message = "helm_release_namespace must be passed through"
  }

  assert {
    condition     = module.management_cluster.helm_release_version == "1.2.3"
    error_message = "helm_release_version must be passed through"
  }

  assert {
    condition     = module.management_cluster.helm_release_repository == "oci://example.com/charts"
    error_message = "helm_release_repository must be passed through"
  }

  assert {
    condition     = module.management_cluster.helm_release_chart == "my-chart"
    error_message = "helm_release_chart must be passed through"
  }

  assert {
    condition     = module.management_cluster.operator_private_key_secret_name == "humanitec-operator-private-key"
    error_message = "enable_driver_authentication must be passed through"
  }
}

run "passes_through_resource_definition_id_prefix" {
  command = apply

  variables {
    resource_definition_id_prefix = "my-prefix"
  }

  assert {
    condition     = can(regex("^my-prefix-[a-z0-9]{4}$", module.management_cluster.resource_definition_id))
    error_message = "resource_definition_id_prefix must be passed through"
  }
}

run "passes_through_outputs" {
  command = apply

  # Enable driver authentication and set a chart version so that all outputs have non-null values
  variables {
    enable_driver_authentication = true
    humanitec_org_id             = "my-org"
    helm_release_version         = "1.2.3"
  }

  assert {
    condition     = alltrue([for v in [output.operator_public_key, output.operator_private_key, output.operator_public_key_id, output.operator_public_key_fingerprint, output.operator_private_key_secret_name, output.helm_release_version] : v != null])
    error_message = "The operator and chart version outputs must not be null when driver authentication is enabled"
  }

  assert {
    condition     = output.operator_public_key == module.management_cluster.operator_public_key
    error_message = "Output operator_public_key must be passed through from the management-cluster-k8s module"
  }

  assert {
    condition     = output.operator_private_key == module.management_cluster.operator_private_key
    error_message = "Output operator_private_key must be passed through from the management-cluster-k8s module"
  }

  assert {
    condition     = output.operator_public_key_id == module.management_cluster.operator_public_key_id
    error_message = "Output operator_public_key_id must be passed through from the management-cluster-k8s module"
  }

  assert {
    condition     = output.operator_public_key_fingerprint == module.management_cluster.operator_public_key_fingerprint
    error_message = "Output operator_public_key_fingerprint must be passed through from the management-cluster-k8s module"
  }

  assert {
    condition     = output.operator_private_key_secret_name == module.management_cluster.operator_private_key_secret_name
    error_message = "Output operator_private_key_secret_name must be passed through from the management-cluster-k8s module"
  }

  assert {
    condition     = output.helm_release_namespace == module.management_cluster.helm_release_namespace
    error_message = "Output helm_release_namespace must be passed through from the management-cluster-k8s module"
  }

  assert {
    condition     = output.helm_release_name == module.management_cluster.helm_release_name
    error_message = "Output helm_release_name must be passed through from the management-cluster-k8s module"
  }

  assert {
    condition     = output.helm_release_version == module.management_cluster.helm_release_version
    error_message = "Output helm_release_version must be passed through from the management-cluster-k8s module"
  }

  assert {
    condition     = output.helm_release_repository == module.management_cluster.helm_release_repository
    error_message = "Output helm_release_repository must be passed through from the management-cluster-k8s module"
  }

  assert {
    condition     = output.helm_release_chart == module.management_cluster.helm_release_chart
    error_message = "Output helm_release_chart must be passed through from the management-cluster-k8s module"
  }

  assert {
    condition     = output.resource_definition_id == module.management_cluster.resource_definition_id
    error_message = "Output resource_definition_id must be passed through from the management-cluster-k8s module"
  }

  assert {
    condition     = output.resource_definition_driver_type == module.management_cluster.resource_definition_driver_type
    error_message = "Output resource_definition_driver_type must be passed through from the management-cluster-k8s module"
  }

  assert {
    condition     = output.cluster_role_name == module.management_cluster.cluster_role_name
    error_message = "Output cluster_role_name must be passed through from the management-cluster-k8s module"
  }

  assert {
    condition     = output.cluster_role_binding_name == module.management_cluster.cluster_role_binding_name
    error_message = "Output cluster_role_binding_name must be passed through from the management-cluster-k8s module"
  }

  assert {
    condition     = output.cluster_access_subject == module.management_cluster.cluster_access_subject
    error_message = "Output cluster_access_subject must be passed through from the management-cluster-k8s module"
  }
}
