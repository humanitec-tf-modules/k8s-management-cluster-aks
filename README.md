# Humanitec management cluster on AKS

This repository contains an OpenTofu/Terraform module for configuring an existing Azure AKS cluster as a Humanitec management cluster.

It wraps the [generic base module](https://github.com/humanitec-tf-modules/k8s-management-cluster) and adds the Azure specific elements around cluster access and Operator identity.

## Runner cluster

To also set up the cluster to execute runners, use the separate module for the [AKS runner cluster](https://github.com/humanitec-tf-modules/k8s-runner-cluster-aks).

## Operator installation

See the notes in the [generic base module](https://github.com/humanitec-tf-modules/k8s-management-cluster#operator-installation).

## Operator identity

The identity setup for the Operator is an outcome of the secret store configuration. The module uses [Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview) by default. See the [usage examples](#usage) for configuration details.

## Entra ID access group

This module requires the use of [Microsoft Entra ID authentication for the AKS control plane](https://learn.microsoft.com/en-us/azure/aks/entra-id-control-plane-authentication). An Entra ID security group receives the required role assignment, and the principal used in an [Azure Cloud Account](https://developer.humanitec.com/platform-orchestrator/docs/platform-orchestrator/security/cloud-accounts/azure/) is added as a member to that group

This module creates that Entra security group by default, or you can [bring your own](#bring-your-own-entra-id-security-group).

## Humanitec Agent

See the notes in the [generic base module](https://github.com/humanitec-tf-modules/k8s-management-cluster#humanitec-agent).

## Authentication for Drivers

See the notes in the [generic base module](https://github.com/humanitec-tf-modules/k8s-management-cluster#authentication-for-drivers).

## Usage

### Common usage: AKS workload identity, no authentication for Drivers, create the Entra ID security group

```hcl
module "my_management_cluster_aks" {
  source = "github.com/humanitec-tf-modules/k8s-management-cluster-aks?ref=vX.Y.Z"
  providers = {
    humanitec  = humanitec
    helm       = helm
    kubernetes = kubernetes
    azuread    = azuread
    azurerm    = azurerm
  }

  # Operator chart version
  helm_release_version = "X.Y.Z"

  # Cluster values
  aks_name           = "my-aks-cluster"
  aks_resource_group = "my-aks-resource-group"

  # ID of the Azure Cloud Account the Orchestrator uses to access the cluster
  cloud_account_id = "my-azure-cloud-account"
  # Object ID of the principal used by the Cloud Account
  cloud_account_principal_object_id = "11111111-1111-1111-1111-111111111111"
  
  # Client ID of the identity the Operator uses through Workload Identity
  workload_identity_client_id = "22222222-2222-2222-2222-222222222222"
}
```

When you manage the Cloud Account using the [Azure Cloud Account module](https://github.com/humanitec-tf-modules/orchestrator-cloud-account-azure-identity), pass in its outputs:

```hcl
module "my_management_cluster_aks" {
  source = "github.com/humanitec-tf-modules/k8s-management-cluster-aks?ref=vX.Y.Z"
  providers = {
    humanitec  = humanitec
    helm       = helm
    kubernetes = kubernetes
    azuread    = azuread
    azurerm    = azurerm
  }

  # All other values like in the preceding example, omitted

  cloud_account_id                  = module.cloud_account_azure_identity.cloud_account_id
  cloud_account_principal_object_id = module.cloud_account_azure_identity.managed_identity_object_id
}
```

The following examples configure the Operator installation. They omit the cluster inputs shown in the first example.

### Bring your own Entra ID security group

```hcl
module "my_management_cluster_aks" {
  source = "github.com/humanitec-tf-modules/k8s-management-cluster-aks?ref=vX.Y.Z"
  providers = {
    humanitec  = humanitec
    helm       = helm
    kubernetes = kubernetes
    azuread    = azuread
    azurerm    = azurerm
  }

  # All values like in the first example, omitted

  # Object ID of your existing security group. The Cloud Account principal will be added to it
  deploy_access_group_object_id = "33333333-3333-3333-3333-333333333333"
}
```

### Do not use workload identity

```hcl
module "my_management_cluster_aks" {
  source = "github.com/humanitec-tf-modules/k8s-management-cluster-aks?ref=vX.Y.Z"
  providers = {
    humanitec  = humanitec
    helm       = helm
    kubernetes = kubernetes
    azuread    = azuread
    azurerm    = azurerm
  }

  # Operator chart version
  helm_release_version = "X.Y.Z"

  # Cluster values
  aks_name           = "my-aks-cluster"
  aks_resource_group = "my-aks-resource-group"

  # ID of the Azure Cloud Account the Orchestrator uses to access the cluster
  cloud_account_id = "my-azure-cloud-account"
  # Object ID of the principal used by the Cloud Account
  cloud_account_principal_object_id = "11111111-1111-1111-1111-111111111111"
  
  use_workload_identity = false
}
```

### Enable authentication for Drivers with your own key pair

```hcl
module "my_management_cluster_aks" {
  source = "github.com/humanitec-tf-modules/k8s-management-cluster-aks?ref=vX.Y.Z"
  providers = {
    humanitec  = humanitec
    helm       = helm
    kubernetes = kubernetes
    azuread    = azuread
    azurerm    = azurerm
  }

  # Cluster values omitted

  enable_driver_authentication = true
  humanitec_org_id             = "my-org"
  operator_private_key         = "-----BEGIN PRIVATE KEY----- ..."
  operator_public_key          = "-----BEGIN PUBLIC KEY----- ..."
  helm_release_version         = "X.Y.Z"
}
```

### Enable authentication for Drivers with a convenience key pair

The module can generate a key pair for convenience, but we do not recommend this for production use because the module stores the private key in the Terraform state. Use an external key management solution and pass in the keys instead as shown in the preceding example.

```hcl
module "my_management_cluster_aks" {
  source = "github.com/humanitec-tf-modules/k8s-management-cluster-aks?ref=vX.Y.Z"
  providers = {
    humanitec  = humanitec
    helm       = helm
    kubernetes = kubernetes
    azuread    = azuread
    azurerm    = azurerm
  }

  # Cluster values omitted

  enable_driver_authentication = true
  humanitec_org_id             = "my-org"
}
```

### Set Helm chart values

By default, the module configures the Operator to use [Azure Workload Identity](https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview). Pass in the client ID of the Entra ID application or user-assigned managed identity for the Operator via `workload_identity_client_id`. The module then sets these Helm chart values for the Operator:

- The service account annotation `azure.workload.identity/client-id` with the client ID
- The Pod label `azure.workload.identity/use: "true"`

You can set any other Helm chart value through `helm_release_values` or `helm_release_set`. The module merges the values in `helm_release_values` with the Workload Identity values. If both set the same key, your value takes precedence.

This example uses Workload Identity and adds another Pod label:

```hcl
module "my_management_cluster_aks" {
  source = "github.com/humanitec-tf-modules/k8s-management-cluster-aks?ref=vX.Y.Z"
  providers = {
    humanitec  = humanitec
    helm       = helm
    kubernetes = kubernetes
    azuread    = azuread
    azurerm    = azurerm
  }

  # Cluster values omitted

  # Client ID of the identity the Operator uses through Workload Identity
  workload_identity_client_id = "22222222-2222-2222-2222-222222222222"

  # Additional Helm chart values, merged with the Workload Identity values
  helm_release_values = [
    yamlencode({
      controllerManager = {
        podLabels = {
          "team" = "platform"
        }
      }
    }),
  ]
}
```

To not use Workload Identity, set `use_workload_identity = false` and omit `workload_identity_client_id`.

### Self-hosting the Helm chart

```hcl
module "my_management_cluster_aks" {
  source = "github.com/humanitec-tf-modules/k8s-management-cluster-aks?ref=vX.Y.Z"
  providers = {
    humanitec  = humanitec
    helm       = helm
    kubernetes = kubernetes
    azuread    = azuread
    azurerm    = azurerm
  }

  # Cluster values omitted

  helm_release_repository         = "oci://my-registry.example.com/my/helm/charts"
  helm_release_chart              = "humanitec-operator"
  helm_release_version            = "X.Y.Z"
  helm_release_repository_ca_file = "..."
  # Use other "helm_release_repository_*" variables as required to access your own registry
}
```

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.11.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 3.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 4.0.0, < 6.0.0 |
| <a name="requirement_helm"></a> [helm](#requirement\_helm) | ~> 3.0 |
| <a name="requirement_humanitec"></a> [humanitec](#requirement\_humanitec) | ~> 1.9 |
| <a name="requirement_kubernetes"></a> [kubernetes](#requirement\_kubernetes) | ~> 3 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_management_cluster"></a> [management\_cluster](#module\_management\_cluster) | github.com/humanitec-tf-modules/k8s-management-cluster | add-operator-k8s |

## Resources

| Name | Type |
|------|------|
| [azuread_group.orchestrator_deploy_access](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/group) | resource |
| [azuread_group_member.orchestrator_deploy_access](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/group_member) | resource |
| [azurerm_role_assignment.orchestrator_deploy_access_cluster_user](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azuread_client_config.current](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/client_config) | data source |
| [azurerm_kubernetes_cluster.aks](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/kubernetes_cluster) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aks_name"></a> [aks\_name](#input\_aks\_name) | Name of the existing AKS cluster to use as the Humanitec management cluster. | `string` | n/a | yes |
| <a name="input_aks_resource_group"></a> [aks\_resource\_group](#input\_aks\_resource\_group) | Name of the resource group containing the AKS cluster. | `string` | n/a | yes |
| <a name="input_cloud_account_id"></a> [cloud\_account\_id](#input\_cloud\_account\_id) | ID of the Azure Cloud Account the Orchestrator uses to access the cluster. | `string` | n/a | yes |
| <a name="input_cloud_account_principal_object_id"></a> [cloud\_account\_principal\_object\_id](#input\_cloud\_account\_principal\_object\_id) | Object ID of the Entra ID principal (the service principal or managed identity behind the Humanitec Orchestrator cloud account) that gets deploy access to the cluster. The module adds it to the Entra ID security group for accessing the cluster, see the deploy\_access\_group\_object\_id variable. | `string` | n/a | yes |
| <a name="input_cluster_role_name"></a> [cluster\_role\_name](#input\_cluster\_role\_name) | Name of the Kubernetes ClusterRole and ClusterRoleBinding granting the Orchestrator access to the cluster. | `string` | `"humanitec-deploy-access"` | no |
| <a name="input_cluster_secrets"></a> [cluster\_secrets](#input\_cluster\_secrets) | Driver input secrets of the Resource Definition for the Driver `humanitec/k8s-cluster-aks`. See the Driver documentation at https://developer.humanitec.com/platform-orchestrator/docs/integration-and-extensions/drivers/k8-drivers/. If `enable_agent` is `true`, the module adds the key `agent_url`. | `any` | `{}` | no |
| <a name="input_deploy_access_group_display_name"></a> [deploy\_access\_group\_display\_name](#input\_deploy\_access\_group\_display\_name) | Display name of the Entra ID group the module creates. If null, a name is derived from the cluster name, resource group, and subscription. Ignored if deploy\_access\_group\_object\_id is set. | `string` | `null` | no |
| <a name="input_deploy_access_group_object_id"></a> [deploy\_access\_group\_object\_id](#input\_deploy\_access\_group\_object\_id) | Object ID of an existing Entra ID security group to use for deploy access to the cluster. If null, the module creates a new group. | `string` | `null` | no |
| <a name="input_deploy_access_group_owners"></a> [deploy\_access\_group\_owners](#input\_deploy\_access\_group\_owners) | Object IDs of the owners of the Entra ID group the module creates. If empty, the principal running Terraform becomes the owner. Ignored if deploy\_access\_group\_object\_id is set. | `list(string)` | `[]` | no |
| <a name="input_enable_agent"></a> [enable\_agent](#input\_enable\_agent) | Access the cluster through the Humanitec Agent. Adds the secret `agent_url`, referencing the output `url` of the Resource `agent#agent`, to the Resource Definition. Requires a Resource Definition of type `agent` matching the same Deployments as the cluster. See https://developer.humanitec.com/platform-orchestrator/docs/integration-and-extensions/humanitec-agent/overview/ | `bool` | `true` | no |
| <a name="input_enable_driver_authentication"></a> [enable\_driver\_authentication](#input\_enable\_driver\_authentication) | Enable authentication of the Operator against Humanitec-hosted Drivers. Requires `humanitec_org_id`. Registers the public key in the Humanitec Organization and stores the private key in the Kubernetes Secret `humanitec-operator-private-key` in the namespace `helm_release_namespace`. Pass in a key pair via `operator_private_key` and `operator_public_key`, or leave both unset to generate a convenience key pair. Only required if you use Humanitec-hosted Drivers. See https://developer.humanitec.com/platform-orchestrator/docs/integration-and-extensions/humanitec-operator/installation/#configure-authentication-for-drivers | `bool` | `false` | no |
| <a name="input_helm_release_atomic"></a> [helm\_release\_atomic](#input\_helm\_release\_atomic) | If set, installation process purges chart on fail. The wait flag will be set automatically if atomic is used. Defaults to `false`. | `bool` | `null` | no |
| <a name="input_helm_release_chart"></a> [helm\_release\_chart](#input\_helm\_release\_chart) | Chart name to be installed. A path may be used. | `string` | `"humanitec-operator"` | no |
| <a name="input_helm_release_cleanup_on_fail"></a> [helm\_release\_cleanup\_on\_fail](#input\_helm\_release\_cleanup\_on\_fail) | Allow deletion of new resources created in this upgrade when upgrade fails. Defaults to `false`. | `bool` | `null` | no |
| <a name="input_helm_release_create_namespace"></a> [helm\_release\_create\_namespace](#input\_helm\_release\_create\_namespace) | Choose whether to create the Kubernetes namespace | `bool` | `true` | no |
| <a name="input_helm_release_dependency_update"></a> [helm\_release\_dependency\_update](#input\_helm\_release\_dependency\_update) | Run helm dependency update before installing the chart. Defaults to `false`. | `bool` | `null` | no |
| <a name="input_helm_release_description"></a> [helm\_release\_description](#input\_helm\_release\_description) | Add a custom description | `string` | `null` | no |
| <a name="input_helm_release_devel"></a> [helm\_release\_devel](#input\_helm\_release\_devel) | Use chart development versions, too. Equivalent to version '>0.0.0-0'. If `helm_release_version` is set, this is ignored | `bool` | `null` | no |
| <a name="input_helm_release_disable_crd_hooks"></a> [helm\_release\_disable\_crd\_hooks](#input\_helm\_release\_disable\_crd\_hooks) | Prevent CRD hooks from running, but run other hooks. See helm install --no-crd-hook | `bool` | `null` | no |
| <a name="input_helm_release_disable_openapi_validation"></a> [helm\_release\_disable\_openapi\_validation](#input\_helm\_release\_disable\_openapi\_validation) | If set, the installation process will not validate rendered templates against the Kubernetes OpenAPI Schema. Defaults to `false`. | `bool` | `null` | no |
| <a name="input_helm_release_disable_webhooks"></a> [helm\_release\_disable\_webhooks](#input\_helm\_release\_disable\_webhooks) | Prevent hooks from running. Defaults to `false`. | `bool` | `null` | no |
| <a name="input_helm_release_force_update"></a> [helm\_release\_force\_update](#input\_helm\_release\_force\_update) | Force resource update through delete/recreate if needed. Defaults to `false`. | `bool` | `null` | no |
| <a name="input_helm_release_keyring"></a> [helm\_release\_keyring](#input\_helm\_release\_keyring) | Location of public keys used for verification. Used only if `helm_release_verify` is true. Defaults to `/.gnupg/pubring.gpg` in the location set by `home`. | `string` | `null` | no |
| <a name="input_helm_release_lint"></a> [helm\_release\_lint](#input\_helm\_release\_lint) | Run helm lint when planning. Defaults to `false`. | `bool` | `null` | no |
| <a name="input_helm_release_max_history"></a> [helm\_release\_max\_history](#input\_helm\_release\_max\_history) | Limit the maximum number of revisions saved per release. Use 0 for no limit. Defaults to 0 (no limit). | `number` | `null` | no |
| <a name="input_helm_release_name"></a> [helm\_release\_name](#input\_helm\_release\_name) | Name of the Helm release for the Operator | `string` | `"humanitec-operator"` | no |
| <a name="input_helm_release_namespace"></a> [helm\_release\_namespace](#input\_helm\_release\_namespace) | Kubernetes namespace where to install the Operator | `string` | `"humanitec-operator-system"` | no |
| <a name="input_helm_release_pass_credentials"></a> [helm\_release\_pass\_credentials](#input\_helm\_release\_pass\_credentials) | Pass credentials to all domains. Defaults to `false`. | `bool` | `null` | no |
| <a name="input_helm_release_postrender"></a> [helm\_release\_postrender](#input\_helm\_release\_postrender) | Postrender command configuration. | <pre>object({<br/>    binary_path = string<br/>    args        = optional(list(string))<br/>  })</pre> | `null` | no |
| <a name="input_helm_release_recreate_pods"></a> [helm\_release\_recreate\_pods](#input\_helm\_release\_recreate\_pods) | Perform pods restart during upgrade/rollback. Defaults to `false`. | `bool` | `null` | no |
| <a name="input_helm_release_render_subchart_notes"></a> [helm\_release\_render\_subchart\_notes](#input\_helm\_release\_render\_subchart\_notes) | If set, render subchart notes along with the parent. Defaults to `true`. | `bool` | `null` | no |
| <a name="input_helm_release_replace"></a> [helm\_release\_replace](#input\_helm\_release\_replace) | Re-use the given name, even if that name is already used. This is unsafe in production. Defaults to `false`. | `bool` | `null` | no |
| <a name="input_helm_release_repository"></a> [helm\_release\_repository](#input\_helm\_release\_repository) | Repository where to locate the requested chart. If is a URL the chart is installed without installing the repository. Set it to `null` for a local chart. | `string` | `"oci://ghcr.io/humanitec/charts"` | no |
| <a name="input_helm_release_repository_ca_file"></a> [helm\_release\_repository\_ca\_file](#input\_helm\_release\_repository\_ca\_file) | The repositories CA File | `string` | `null` | no |
| <a name="input_helm_release_repository_cert_file"></a> [helm\_release\_repository\_cert\_file](#input\_helm\_release\_repository\_cert\_file) | The repositories cert file | `string` | `null` | no |
| <a name="input_helm_release_repository_key_file"></a> [helm\_release\_repository\_key\_file](#input\_helm\_release\_repository\_key\_file) | The repositories cert key file | `string` | `null` | no |
| <a name="input_helm_release_repository_password"></a> [helm\_release\_repository\_password](#input\_helm\_release\_repository\_password) | Password for HTTP basic authentication | `string` | `null` | no |
| <a name="input_helm_release_repository_username"></a> [helm\_release\_repository\_username](#input\_helm\_release\_repository\_username) | Username for HTTP basic authentication | `string` | `null` | no |
| <a name="input_helm_release_reset_values"></a> [helm\_release\_reset\_values](#input\_helm\_release\_reset\_values) | When upgrading, reset the values to the ones built into the chart. Defaults to `false`. | `bool` | `null` | no |
| <a name="input_helm_release_reuse_values"></a> [helm\_release\_reuse\_values](#input\_helm\_release\_reuse\_values) | When upgrading, reuse the last release's values and merge in any overrides. If 'helm\_release\_reset\_values' is specified, this is ignored. Defaults to `false`. | `bool` | `null` | no |
| <a name="input_helm_release_set"></a> [helm\_release\_set](#input\_helm\_release\_set) | Custom values to be merged with the values. | <pre>list(object({<br/>    name  = string<br/>    value = optional(string)<br/>    type  = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_helm_release_set_list"></a> [helm\_release\_set\_list](#input\_helm\_release\_set\_list) | Custom list values to be merged with the values. | <pre>list(object({<br/>    name  = string<br/>    value = list(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_helm_release_set_sensitive"></a> [helm\_release\_set\_sensitive](#input\_helm\_release\_set\_sensitive) | Custom sensitive values to be merged with the values. | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>    type  = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_helm_release_set_wo"></a> [helm\_release\_set\_wo](#input\_helm\_release\_set\_wo) | Custom values to be merged with the values. This is the same as "helm\_release\_set" but write-only. | <pre>list(object({<br/>    name  = string<br/>    value = string<br/>    type  = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_helm_release_set_wo_revision"></a> [helm\_release\_set\_wo\_revision](#input\_helm\_release\_set\_wo\_revision) | The current revision of the write-only "helm\_release\_set\_wo" attribute. Incrementing this integer value will cause Terraform to update the write-only value. | `number` | `null` | no |
| <a name="input_helm_release_skip_crds"></a> [helm\_release\_skip\_crds](#input\_helm\_release\_skip\_crds) | If set, no CRDs will be installed. By default, CRDs are installed if not already present. Defaults to `false`. | `bool` | `null` | no |
| <a name="input_helm_release_take_ownership"></a> [helm\_release\_take\_ownership](#input\_helm\_release\_take\_ownership) | If set, allows Helm to adopt existing resources not marked as managed by the release. Defaults to `false`. | `bool` | `null` | no |
| <a name="input_helm_release_timeout"></a> [helm\_release\_timeout](#input\_helm\_release\_timeout) | Time in seconds to wait for any individual Kubernetes operation. Defaults to 300 seconds. | `number` | `null` | no |
| <a name="input_helm_release_upgrade_install"></a> [helm\_release\_upgrade\_install](#input\_helm\_release\_upgrade\_install) | If true, the provider will install the release at the specified version even if a release not controlled by the provider is present: this is equivalent to running 'helm upgrade --install' with the Helm CLI. WARNING: this may not be suitable for production use -- see the 'Upgrade Mode' note in the provider documentation. Defaults to `false`. | `bool` | `null` | no |
| <a name="input_helm_release_values"></a> [helm\_release\_values](#input\_helm\_release\_values) | List of values in raw yaml format to pass to Helm. If `use_workload_identity` is `true`, the module prepends the Workload Identity values, so values passed in here are merged with them and take precedence. | `list(string)` | `null` | no |
| <a name="input_helm_release_verify"></a> [helm\_release\_verify](#input\_helm\_release\_verify) | Verify the package before installing it. Defaults to `false`. | `bool` | `null` | no |
| <a name="input_helm_release_version"></a> [helm\_release\_version](#input\_helm\_release\_version) | Chart version to use for the Operator installation in the format `X.Y.Z`. If this is not specified, the latest version is installed. | `string` | `null` | no |
| <a name="input_helm_release_wait"></a> [helm\_release\_wait](#input\_helm\_release\_wait) | Will wait until all resources are in a ready state before marking the release as successful. Defaults to `true`. | `bool` | `null` | no |
| <a name="input_helm_release_wait_for_jobs"></a> [helm\_release\_wait\_for\_jobs](#input\_helm\_release\_wait\_for\_jobs) | If wait is enabled, will wait until all Jobs have been completed before marking the release as successful. Defaults to `false`. | `bool` | `null` | no |
| <a name="input_humanitec_org_id"></a> [humanitec\_org\_id](#input\_humanitec\_org\_id) | Humanitec Organization ID. Required if `enable_driver_authentication` is `true`, ignored otherwise. | `string` | `null` | no |
| <a name="input_loadbalancer"></a> [loadbalancer](#input\_loadbalancer) | The IP or DNS name representing the cluster load balancer. | `string` | `null` | no |
| <a name="input_operator_private_key"></a> [operator\_private\_key](#input\_operator\_private\_key) | Private key for the Humanitec Operator authentication against Humanitec-hosted Drivers. Must be a multiline string starting with -----BEGIN PRIVATE KEY----- and having a final line break. Both or neither of `operator_public_key` and `operator_private_key` must be set, and only if `enable_driver_authentication` is `true`. If not set while `enable_driver_authentication` is `true`, a convenience key pair will be generated using a `tls_private_key` resource and stored in the Terraform state, but this is not recommended for production use. | `string` | `null` | no |
| <a name="input_operator_public_key"></a> [operator\_public\_key](#input\_operator\_public\_key) | Public key for the Humanitec Operator authentication against Humanitec-hosted Drivers. Must be a multiline string starting with -----BEGIN PUBLIC KEY----- and having a final line break. Both or neither of `operator_public_key` and `operator_private_key` must be set, and only if `enable_driver_authentication` is `true`. If not set while `enable_driver_authentication` is `true`, a convenience key pair will be generated using a `tls_private_key` resource and stored in the Terraform state, but this is not recommended for production use. | `string` | `null` | no |
| <a name="input_resource_definition_criteria"></a> [resource\_definition\_criteria](#input\_resource\_definition\_criteria) | Matching Criteria for the Resource Definition, directing Deployments to the cluster. Each entry creates one Matching Criteria. Unset attributes match any value. See https://developer.humanitec.com/platform-orchestrator/docs/platform-orchestrator/resources/resource-definitions/#matching-criteria | <pre>list(object({<br/>    app_id   = optional(string)<br/>    env_id   = optional(string)<br/>    env_type = optional(string)<br/>    res_id   = optional(string)<br/>    class    = optional(string)<br/>  }))</pre> | `[]` | no |
| <a name="input_resource_definition_id"></a> [resource\_definition\_id](#input\_resource\_definition\_id) | ID of the Resource Definition of type `k8s-cluster` representing the cluster. Must be unique within the Humanitec Organization. Defaults to `<resource_definition_id_prefix>-<suffix>` with a random suffix of four lowercase alphanumeric characters. | `string` | `null` | no |
| <a name="input_resource_definition_id_prefix"></a> [resource\_definition\_id\_prefix](#input\_resource\_definition\_id\_prefix) | Prefix of the generated `resource_definition_id`. Ignored if `resource_definition_id` is set. | `string` | `"management-cluster-aks"` | no |
| <a name="input_resource_definition_name"></a> [resource\_definition\_name](#input\_resource\_definition\_name) | Display name of the Resource Definition. Defaults to `resource_definition_id`. | `string` | `null` | no |
| <a name="input_use_workload_identity"></a> [use\_workload\_identity](#input\_use\_workload\_identity) | Configure the Operator to use Azure Workload Identity. Adds the Helm chart values for the service account annotation `azure.workload.identity/client-id` and the Pod label `azure.workload.identity/use` before any values passed in via `helm_release_values`. Requires `workload_identity_client_id`. See https://learn.microsoft.com/en-us/azure/aks/workload-identity-overview | `bool` | `true` | no |
| <a name="input_workload_identity_client_id"></a> [workload\_identity\_client\_id](#input\_workload\_identity\_client\_id) | Client ID of the Entra ID application or user-assigned managed identity the Operator uses through Azure Workload Identity. Required if `use_workload_identity` is `true`, ignored otherwise. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aks_cluster_id"></a> [aks\_cluster\_id](#output\_aks\_cluster\_id) | ID of the AKS cluster. |
| <a name="output_cluster_access_subject"></a> [cluster\_access\_subject](#output\_cluster\_access\_subject) | Subject of the Kubernetes ClusterRoleBinding, i.e. the identity the Orchestrator uses to access the cluster, as an object with the attributes `kind` and `name` |
| <a name="output_cluster_role_binding_name"></a> [cluster\_role\_binding\_name](#output\_cluster\_role\_binding\_name) | Name of the Kubernetes ClusterRoleBinding granting the Orchestrator access to the cluster |
| <a name="output_cluster_role_name"></a> [cluster\_role\_name](#output\_cluster\_role\_name) | Name of the Kubernetes ClusterRole granting the Orchestrator access to the cluster |
| <a name="output_deploy_access_group_object_id"></a> [deploy\_access\_group\_object\_id](#output\_deploy\_access\_group\_object\_id) | Object ID of the Entra ID group granting deploy access to the cluster, either created by the module or passed in. |
| <a name="output_helm_release_chart"></a> [helm\_release\_chart](#output\_helm\_release\_chart) | Chart name used for the Operator Helm chart |
| <a name="output_helm_release_name"></a> [helm\_release\_name](#output\_helm\_release\_name) | Name of the Helm release for the Operator |
| <a name="output_helm_release_namespace"></a> [helm\_release\_namespace](#output\_helm\_release\_namespace) | Kubernetes namespace where the Operator is installed |
| <a name="output_helm_release_repository"></a> [helm\_release\_repository](#output\_helm\_release\_repository) | Repository used for the Operator Helm chart |
| <a name="output_helm_release_version"></a> [helm\_release\_version](#output\_helm\_release\_version) | Chart version used for the Operator installation |
| <a name="output_operator_private_key"></a> [operator\_private\_key](#output\_operator\_private\_key) | Private key of the Operator in PEM format. `null` if `enable_driver_authentication` is `false`. |
| <a name="output_operator_private_key_secret_name"></a> [operator\_private\_key\_secret\_name](#output\_operator\_private\_key\_secret\_name) | Name of the Kubernetes Secret holding the private key of the Operator. `null` if `enable_driver_authentication` is `false`. |
| <a name="output_operator_public_key"></a> [operator\_public\_key](#output\_operator\_public\_key) | Public key of the Operator in PEM format. `null` if `enable_driver_authentication` is `false`. |
| <a name="output_operator_public_key_fingerprint"></a> [operator\_public\_key\_fingerprint](#output\_operator\_public\_key\_fingerprint) | Fingerprint (SHA256 hash of the DER representation) of the public key registered in the Humanitec Organization. Use it to debug authentication against Humanitec-hosted Drivers. `null` if `enable_driver_authentication` is `false`. |
| <a name="output_operator_public_key_id"></a> [operator\_public\_key\_id](#output\_operator\_public\_key\_id) | ID of the public key registered in the Humanitec Organization. `null` if `enable_driver_authentication` is `false`. |
| <a name="output_resource_definition_driver_type"></a> [resource\_definition\_driver\_type](#output\_resource\_definition\_driver\_type) | Driver type of the Resource Definition |
| <a name="output_resource_definition_id"></a> [resource\_definition\_id](#output\_resource\_definition\_id) | ID of the Resource Definition of type `k8s-cluster` representing the cluster |
| <a name="output_role_assignment_id"></a> [role\_assignment\_id](#output\_role\_assignment\_id) | ID of the role assignment granting the deploy access group the Azure Kubernetes Service Cluster User Role on the cluster. |
<!-- END_TF_DOCS -->
