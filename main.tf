data "azuread_client_config" "current" {}

data "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_name
  resource_group_name = var.aks_resource_group
}

locals {
  create_deploy_access_group = var.deploy_access_group_object_id == null

  # Cluster ID format: /subscriptions/<subscription id>/resourceGroups/<rg>/providers/Microsoft.ContainerService/managedClusters/<name>
  aks_subscription_id = split("/", data.azurerm_kubernetes_cluster.aks.id)[2]

  deploy_access_group_display_name = coalesce(
    var.deploy_access_group_display_name,
    "Humanitec Orchestrator deploy access to AKS cluster ${var.aks_name} (resource group ${var.aks_resource_group}, subscription ${local.aks_subscription_id})",
  )

  deploy_access_group_owners = length(var.deploy_access_group_owners) > 0 ? var.deploy_access_group_owners : [data.azuread_client_config.current.object_id]

  deploy_access_group_object_id = local.create_deploy_access_group ? azuread_group.orchestrator_deploy_access[0].object_id : var.deploy_access_group_object_id

  # Driver input values for humanitec/k8s-cluster-aks. The child module drops null values so that the Driver defaults apply
  cluster_values = {
    loadbalancer   = var.loadbalancer
    name           = var.aks_name
    resource_group = var.aks_resource_group
    # Application ID of the Microsoft-managed Entra ID application used by AKS for Entra ID integration
    server_app_id   = "6dae42f8-4368-4678-94ff-3960e28e3630"
    subscription_id = local.aks_subscription_id
  }

  # Helm chart values making the Operator use Azure Workload Identity
  workload_identity_helm_values = yamlencode({
    controllerManager = {
      serviceAccount = {
        annotations = {
          "azure.workload.identity/client-id" = var.workload_identity_client_id
        }
      }
      podLabels = {
        # Must be the string "true", not a boolean
        "azure.workload.identity/use" = "true"
      }
    }
  })

  # Helm merges values documents in order, so the values passed in come last to take precedence
  helm_release_values = var.use_workload_identity ? concat(
    [local.workload_identity_helm_values],
    var.helm_release_values != null ? var.helm_release_values : [],
  ) : var.helm_release_values
}

# Entra ID security group for deploy access to the cluster
# Created only if no existing group is passed in via var.deploy_access_group_object_id
resource "azuread_group" "orchestrator_deploy_access" {
  count = local.create_deploy_access_group ? 1 : 0

  display_name     = local.deploy_access_group_display_name
  owners           = local.deploy_access_group_owners
  security_enabled = true
  # Note: Do not add members in this resource to avoid a conflict with azuread_group_member resources
}

resource "azuread_group_member" "orchestrator_deploy_access" {
  group_object_id  = local.deploy_access_group_object_id
  member_object_id = var.cloud_account_principal_object_id
}

resource "azurerm_role_assignment" "orchestrator_deploy_access_cluster_user" {
  scope                = data.azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = local.deploy_access_group_object_id
  principal_type       = "Group"
}

module "management_cluster" {
  source = "github.com/humanitec-tf-modules/k8s-management-cluster?ref=v1.0.0"

  driver_type                 = "humanitec/k8s-cluster-aks"
  cluster_access_subject_kind = "Group"
  cluster_access_subject_name = local.deploy_access_group_object_id
  cluster_values              = local.cluster_values

  # Pass-through variables
  resource_definition_id                  = var.resource_definition_id
  resource_definition_id_prefix           = var.resource_definition_id_prefix
  resource_definition_name                = var.resource_definition_name
  resource_definition_criteria            = var.resource_definition_criteria
  cloud_account_id                        = var.cloud_account_id
  enable_agent                            = var.enable_agent
  cluster_role_name                       = var.cluster_role_name
  cluster_secrets                         = var.cluster_secrets
  humanitec_org_id                        = var.humanitec_org_id
  enable_driver_authentication            = var.enable_driver_authentication
  operator_private_key                    = var.operator_private_key
  operator_public_key                     = var.operator_public_key
  helm_release_namespace                  = var.helm_release_namespace
  helm_release_create_namespace           = var.helm_release_create_namespace
  helm_release_name                       = var.helm_release_name
  helm_release_version                    = var.helm_release_version
  helm_release_repository                 = var.helm_release_repository
  helm_release_chart                      = var.helm_release_chart
  helm_release_atomic                     = var.helm_release_atomic
  helm_release_cleanup_on_fail            = var.helm_release_cleanup_on_fail
  helm_release_dependency_update          = var.helm_release_dependency_update
  helm_release_description                = var.helm_release_description
  helm_release_devel                      = var.helm_release_devel
  helm_release_disable_crd_hooks          = var.helm_release_disable_crd_hooks
  helm_release_disable_openapi_validation = var.helm_release_disable_openapi_validation
  helm_release_disable_webhooks           = var.helm_release_disable_webhooks
  helm_release_force_update               = var.helm_release_force_update
  helm_release_keyring                    = var.helm_release_keyring
  helm_release_lint                       = var.helm_release_lint
  helm_release_max_history                = var.helm_release_max_history
  helm_release_pass_credentials           = var.helm_release_pass_credentials
  helm_release_postrender                 = var.helm_release_postrender
  helm_release_recreate_pods              = var.helm_release_recreate_pods
  helm_release_render_subchart_notes      = var.helm_release_render_subchart_notes
  helm_release_replace                    = var.helm_release_replace
  helm_release_repository_ca_file         = var.helm_release_repository_ca_file
  helm_release_repository_cert_file       = var.helm_release_repository_cert_file
  helm_release_repository_key_file        = var.helm_release_repository_key_file
  helm_release_repository_password        = var.helm_release_repository_password
  helm_release_repository_username        = var.helm_release_repository_username
  helm_release_reset_values               = var.helm_release_reset_values
  helm_release_reuse_values               = var.helm_release_reuse_values
  helm_release_set                        = var.helm_release_set
  helm_release_set_wo                     = var.helm_release_set_wo
  helm_release_set_wo_revision            = var.helm_release_set_wo_revision
  helm_release_set_list                   = var.helm_release_set_list
  helm_release_set_sensitive              = var.helm_release_set_sensitive
  helm_release_skip_crds                  = var.helm_release_skip_crds
  helm_release_take_ownership             = var.helm_release_take_ownership
  helm_release_timeout                    = var.helm_release_timeout
  helm_release_upgrade_install            = var.helm_release_upgrade_install
  helm_release_values                     = local.helm_release_values
  helm_release_verify                     = var.helm_release_verify
  helm_release_wait                       = var.helm_release_wait
  helm_release_wait_for_jobs              = var.helm_release_wait_for_jobs
}
