# Comprehensive Guide to Krateo Composable FinOps
This cheatsheet provides an overview of how to:
- [prepare the Azure environment for Krateo Composable FinOps](#prepare-the-azure-environment-for-krateo-composable-finops)
- [integrate Krateo Composable FinOps into an existing composition with Azure resources](#integrate-krateo-composable-finops-into-an-existing-composition-with-azure-resources)
- [customize or extend the example composition to include more Azure resources](#customize-or-extend-the-example-composition-to-include-more-azure-resources)

## Prepare the Azure Environment for Krateo Composable FinOps
To prepare the Azure environment for Krateo Composable FinOps you can use the guide and template available at [krateo-template-finops-azure-configuration](https://github.com/krateoplatformops/krateo-template-finops-azure-configuration). This is a "one-shot" operation and only needs to be done once.

### Other Service Providers
The development of dedicated guides and example compositions for cloud providers different from Azure is currently underway. In the meantime, if you want to start using Krateo Composable FinOps on GCP or AWS right away, the following pointers may help you setup your environment.

**Pricing**: Both AWS and GCP have a pricing service like Azure, however, only [GCP](https://cloud.google.com/billing/docs/reference/pricing-api/rest) has an API. You can use a similar approach to the Azure Pricing API with the [
azure-pricing-rest-dynamic-controller-plugin
](https://github.com/krateoplatformops/azure-pricing-rest-dynamic-controller-plugin), which takes advantage of a [rest definition](https://github.com/krateoplatformops/azure-pricing-rest-dynamic-controller-plugin-chart/blob/main/chart/templates/restdefinition.yaml) for the [oasgen-provider](https://github.com/krateoplatformops/oasgen-provider/) (which also has a detailed cheatsheet that you can follow to replicate on GCP). For AWS, there will probably be a need for a custom tool that makes use of the aws-cli. Note that the pricing APIs for AWS and GCP are authenticated, unlike Azure's.

**Billing and costs**: the approach on AWS and GCP is similar to Azure: you will need to create periodic exports on permanent storage (i.e., [bucket S3 on AWS](https://aws.amazon.com/blogs/aws-cloud-financial-management/announcing-data-exports-for-focus-1-0-preview-in-aws-billing-and-cost-management/) and storage account on GCP). For AWS, you can learn more on the [FinOps foundation website](https://focus.finops.org/get-started/aws/) directly, [likewise on GCP](https://focus.finops.org/get-started/google-cloud/) which relies on BigQuery integration.

**Usage Metrics**: on AWS: the ACK controllers place the id of the resource in the status, here for an example on the [EC2 controller](https://github.com/aws-controllers-k8s/ec2-controller/blob/main/config/crd/bases/ec2.services.k8s.aws_instances.yaml#L18). Then, you can use the CloudWatch REST API to get the [metrics](https://docs.aws.amazon.com/AmazonCloudWatch/latest/APIReference/API_GetMetricStatistics.html). On GCP: the GCP Config Connector operator also places the instance id in the status of a resource, example for a [compute instance](https://github.com/GoogleCloudPlatform/k8s-config-connector/blob/master/config/crds/resources/apiextensions.k8s.io_v1_customresourcedefinition_computeinstances.compute.cnrm.cloud.google.com.yaml#L997). Then, you can use the [REST API](https://cloud.google.com/monitoring/api/metrics_gcp#gcp-compute) to gather all the metrics that you need by composing the path just like for Azure.

Note: the Krateo Composable FinOps exporter does not currently support the AWS or GCP schemas for metrics, you will therefore need a middleware that parses these data and converts them.

### On-Premises systems
Differently from cloud providers, while our approach for usage metrics may be similar (i.e., through prometheus exporters), billing information has to be manually parsed. Since on-premises systems do not create billing reports automatically, you will need to write your own tool to parse usage data and combine it with pricing data to create a FOCUS report. For example, if we know a new node costs 1€/h (explicitly encoded pricing information), and from the usage metrics we see that a node has been used for 4h in the last month (usage metrics), then we can generate an entry in the FOCUS report of 4€ for the specific node (billing report).

Additionally, tools like OpenStack support resource tagging, either through the `Tags` fields (e.g., on nodes for Ironic), or through the extra fields (i.e., a JSON field without schema). This allows to place the composition id there as well, and then expose in the metrics this field, allowing our custom tool to create the FOCUS report and including the composition id in the tags field.


## Integrate Krateo Composable FinOps Into an Existing Composition with Azure Resources
There are six main features that Krateo offers with regards to FinOps:
- [Pricing](#pricing): the cost per unit of measure of a given resource or service
- [Billing and costs](#billing-and-costs): the actual billed cost incurred due to utilization of a given resource or service
- [Usage Metrics](#usage-metrics): the usage metrics of a given resource
- [Optimization](#optimization): the optimization proposed by the optimization architecture (applies to resources with percentage-based usage only)
- [FinOps tab](#finops-tab-in-the-composition-page): the tab in the composition page that summarizes the costs, usages and optimizations of your composition
- [FinOps dashboard](#finops-dashboard): the overall view of all the costs in your billing report, with a list of compositions along their costs and warnings

Each one of these categories requires some explicit configuration in your existing Composition Definition Template.

### Pricing
The pricing features rely on three components:
- the [focus-data-presentation-azure](https://github.com/krateoplatformops/focus-data-presentation-azure) composition: it allows to download sets of prices from the Azure pricing API
- the pricing annotation: it allows to define a special name which will be used to reconcile the prices and the resources
- the frontend button for the pricing drawer and the pricing drawer

The pricing is static, and parsed from the pricing API through the [focus-data-presentation-azure](https://github.com/krateoplatformops/focus-data-presentation-azure) **before** a composition is created. It applies to `CompositionDefinitions`. The pricing information is continuously pulled and updated. To download a price into the FinOps database, you need to create the following configuration. All fields are explained in the comment above the field.
```yaml
apiVersion: composition.krateo.io/v0-1-0
kind: FocusDataPresentationAzure
metadata:
  name: standard-b2s-pricing
  namespace: azure-pricing-system
spec:
  # Annotation key that has to match the annotation in the Azure resources in the Composition Definition Template, you can use any value as long as it matches
  annotationKey: krateo-finops-focus-resource
  # The filter allows to select which prices we want from the Azure pricing API
  # Important: the armSkuName is used to match the price to the resource, this will be explained thoroughly later
  # If your filter produces a list of prices, rather than a single price, the highest one will be used
  filter: serviceName eq 'Virtual Machines' and armSkuName eq 'Standard_B2s' and type eq 'Consumption'
  # The namespace of the finops-operator-focus
  # This is the same as the krateo namespace if you installed Krateo with the installer
  operatorFocusNamespace: krateo-system
  # Where to store the data, in which database, in which table and how often
  scraperConfig:
    tableName: pricing_table
    pollingInterval: "1h"
    scraperDatabaseConfigRef: 
      name: finops-database-handler
      namespace: krateo-system
```
The above examples downloads the highest Consumption type price for Virtual Machines of SKU Standard_B2s (since different regions have different prices). If instead we wanted a different SKU, for example, the default machine for AKS clusters in the Italy North region, we would need to change the filter to:
```yaml
  filter: serviceName eq 'Virtual Machines' and armSkuName eq 'Standard_D4as_v5' and armRegionName eq 'italynorth' and type eq 'Consumption'
```
You can list the name of all the regions with the Azure command:
```sh
az account list-locations -o table
```
You can create as many pricing compositions as you want. Do note however that each composition will only produce a single price, therefore you need to be somewhat specific in the filter for the prices that you want. If your filter produces a list of values, rather than a single price, the highest one will be used. You can test your filters in the pricing API, by writing it directly in the address bar:
```
https://prices.azure.com/api/retail/prices?$filter=serviceName eq 'Virtual Machines'
```
The [official documentation](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-) contains more examples.

Then, to reconcile the price just downloaded to the Composition Definition Template that actually has the Azure resources, we need to add an annotation to the resources for which we just downloaded the pricing for. For example, in our case, we want to add the pricing annotation to our virtual machine template:
```diff
apiVersion: compute.azure.com/v1api20220301
kind: VirtualMachine
metadata:
  name: {{ .Values.name }}
+ annotations: 
+   krateo-finops-focus-resource: '["{{ .Values.vmSize }}"]'
spec:
  hardwareProfile:
    vmSize: {{ .Values.vmSize }}
...
```
Important: the annotation key `krateo-finops-focus-resource` has to match the one we used in the composition above. The annotation value has to correspond to the `armSkuName` produced by the API (it will be the one of the highest price obtained from your filter in the Azure pricing API).

This value is parsed by the [finops-composition-definition-parser](https://github.com/krateoplatformops/finops-composition-definition-parser), which can also resolve references to the values.yaml file. Note: the annotation value is static and will take the default value from the values.yaml file. This happens **before** a composition is created, therefore no custom value can be put here by a user.

Finally, we need to configure the frontend panel to accomodate the pricing. We reccomend adding a button that opens a drawer. To do so, you need to create a new button for your panel:
```yaml
kind: Button
apiVersion: widgets.templates.krateo.io/v1beta1
metadata:
  name: finops-pricing-panel-button
  namespace: azure-pricing-system
spec:
  widgetData:
    icon: fa-solid fa-dollar-sign
    type: default
    shape: circle
    clickActionId: open-pricing-drawer
    actions:
      openDrawer:
        - id: open-pricing-drawer
          resourceRefId: pricing-information
          # Since we want to open a drawer, we need to set the type to openDrawer
          type: openDrawer 
  resourcesRefs:
    # We reference a new panel that inside will contain a paragraph, compiled with a RESTAction
    - id: pricing-information
      apiVersion: widgets.templates.krateo.io/v1beta1
      resource: panel
      name: finops-pricing-panel
      namespace: azure-pricing-system
      verb: GET
```
The `Paragraph` can be found [here](./portal/2.5.0/paragraph.finops-template-panel-pricing-paragraph.yaml): it calls a `RESTAction` to compile its contents. The `RESTAction` can be found [here](./portal/2.5.0/restaction.finops-get-pricing-information.yaml): it calls a notebook in the [finops-database-handler](https://github.com/krateoplatformops/finops-database-handler) with the uid of the `CompositionDefinition` to obtain the pricing information.

All other template resources for the frontend portal, such as the other buttons, forms, etc., are [here](./portal/2.5.0/).

Finally, add the button to your panel:
```diff
...
  widgetData:
    clickActionId: template-click-action
    footer:
+     - resourceRefId: pricing-panel-button
      - resourceRefId: template-panel-button
    tags: 
      - azure-pricing-system
      - "0.2.0"
    icon:
...
      namespace: azure-pricing-system
      resource: buttons
      verb: GET
+   - id: pricing-panel-button
+     apiVersion: widgets.templates.krateo.io/v1beta1
+     name: finops-pricing-panel-button
+     namespace: azure-pricing-system
+     resource: buttons
+     verb: GET
    - id: template-form
      apiVersion: widgets.templates.krateo.io/v1beta1
      name: finops-template-panel-form
...
```

### Billing and Costs
Billing information comes from the FOCUS report that we download from the storage account, and, therefore, is all available in the database. However, we need to identify which resources belong to which compositions. To do so, we utilize the standard tagging approach. 

The Azure Service Operator supports tagging directly in the custom resources, therefore we just need to update each template that will produce a cost on Azure with:
```diff
apiVersion: compute.azure.com/v1api20220301
kind: VirtualMachine
metadata:
  name: {{ .Values.name }}
  annotations: 
    krateo-finops-focus-resource: '["{{ .Values.vmSize }}"]'
spec:
+ tags:
+   compositionId: {{ .Values.global.compositionId }}
  hardwareProfile:
    vmSize: {{ .Values.vmSize }}
...
```
Now, the resources created through this composition definition will have the composition id reported in the billing report inside the tags column, allowing the Krateo Composable FinOps to retrieve costs for your Azure components.

### Usage Metrics
The usage metrics are collected separetly from the billing/cost metrics. They rely on the same exporter/scraper flow, but instead of targeting a service account, they target the management REST API. The following [custom resource](./chart/templates/exporterscraperconfig.yaml) gathers CPU usage for the virtual machine in the example composition, and is somewhat specific to Azure. Let's analyze it line by line.
```yaml
{{- $vm := lookup "compute.azure.com/v1api20220301" "VirtualMachine" .Release.Namespace .Values.name }}
```
Firstly, we lookup the virtual machine we just created through the composition. This function calls the Kubernetes API server to obtain the actual object in the JSON/YAML format to read all its values, including the status. You can change the parameters of the lookup if you are targeting a different resource. The lookup is structured as:
```yaml
lookup apiGroup/apiVersion kind namespace name
```
With the virtual machine object, we can now make three checks:
```yaml
{{- if $vm }}
{{- if eq $vm.status.provisioningState "Succeeded" }}
{{- if $vm.status.id }}
{{- $vmId := $vm.status.id }}
```
We verify if the virtual machine custom resource actually exists, if its provisoning state is "Succeded" and finally if it has an id. The last one is especially important: the id corresponds to the resouce id, which on Azure also corresponds to the REST API path for the resource. The REST API path allows us to query for the metrics. In fact, the following lines compute the suffix that will be attached to the resource id to complete the path for the metrics for a virtual machine:
```yaml
{{- $currentDate := now }}
{{- $backupRange := list .Values.metricExporter.timespan $currentDate.Year $currentDate.Month $currentDate.Day | include "dates.dateRange" }}
{{- $metricName := .Values.metricExporter.metricName | replace " " "%20" -}}
{{- $resourceSuffix := printf "/providers/microsoft.insights/metrics?api-version=2023-10-01&metricnames=%s&timespan=%s&interval=%s" $metricName $backupRange .Values.metricExporter.interval }}
```
Specifically, we compute the dates range for the metrics, which can be `year`, `month` and `day`, depending on your needs. In this example, we take the value from the values.yaml file with `.Values.metricExporter.timespan`. Then, we prepare the metric name by making spaces URL friendly. Finally, we compute the whole suffix, which is mostly static for virtual machines' metrics.

Finally, the `ExporterScraperConfig` is particularly important:
```yaml
  exporterConfig:
    api: 
      # The path will be exactly our resource id followed by the resource suffix 
      path: {{ printf "%s%s" $vmId $resourceSuffix | quote }}
      verb: GET
      # The endpoint needs to point to the azure management api, but you created this with the step on preparing your environment
      endpointRef:
        name: azure-management-api
        namespace: {{ .Values.global.krateoNamespace }}
    # Set the metric type to resource, which will change the expected schema for the database
    metricType: resource
    pollingInterval: {{ .Values.metricExporter.pollingInterval | quote }}
    additionalVariables:
      # Importantly, you need to also specify the resource id in the additional variables for reconciliation in
      # the database with the FOCUS report, since there is no way to recover the resource id from the path alone 
      # (we do not know where the resource id ends and the suffix starts)
      ResourceId: {{ $vmId }}
```

Then, lastly, we need to add the proper configuration values to the values.yaml file:
```diff
+metricExporter:
+  timespan: "month" # one of day, month, year, see helper dates for customization
+  interval: "PT15M"
+  metricName: "Percentage CPU"
+  pollingInterval: "1h"
+  scraperDatabaseConfigRef:
+    name: finops-database-handler
+    namespace: krateo-system
```
In our case, the `ExporterScraperConfig` will be automatically created by the composition controller when the virtual machine is successfully provisioned by the Azure Service Operator (due to the ifs at the beginning of the template). 

### Optimization
Krateo Composable FinOps relies on Open Policy Agent (OPA) to analyze and optimize compositions. It targets resources that have percentage-based utilizations to identify underutilization and propose an optimization which will be displayed in the frontend. 

OPA relies on a set of webhooks to call upon the policies, therefore, we need to configure a webhook for the resource of our composition definition. To do so, we need to add to our Chart.yaml the following:
```diff
apiVersion: v2
name: vm-azure
description: Krateo FinOps Example Pricing for Azure VM
type: application
version: CHART_VERSION
appVersion: APP_VERSION
+dependencies:
+- name: finops-webhook-template
+  condition: webhook.enabled
+  version: "0.1.0"
+  repository: "https://charts.krateo.io"
+  alias: webhook
```
The [finops-webhook-template](github.com/krateoplatformops/finops-webhook-template-chart/) automatically configures a webhook for the specific composition resource, utilizing the OPA certificates installed with the Krateo installer.
> [!NOTE]
> If you manually install OPA or modify the installation, you need to check the certificates

To configure the webhook you can add the following to your values.yaml file:
```yaml
# Webhook configuration, the certificare and the service should match the OPA install
# Default values match the krateo-installer
webhook:
  enabled: true
  fullnameOverride: mutating-webhook-vmazures
  # To set annotations on all admissionController resources (Secret/Certificate/Issuer/AdmissionController)
  # annotations:
  #   example: value

  # Adds a namespace selector to the admission controller webhook
  namespaceSelector:
    matchExpressions:
    - key: openpolicyagent.org/webhook
      operator: NotIn
      values: 
        - ignore

  # SideEffectClass for the webhook, setting to NoneOnDryRun enables dry-run.
  # Only None and NoneOnDryRun are permitted for admissionregistration.k8s.io/v1.
  sideEffect: None

  useHttps: true
  generatedCerts: true # If this is set to true, the chart will look for the certsSecretRef secret
  # The webhook lookup will look for the field "caBundle"
  certsSecretRef:
    name: opa-kube-mgmt-cert
    namespace: krateo-system
  # Otherwise it will use the CA Bundle specified in CA
  CA: ""

  service:
    name: opa-kube-mgmt
    namespace: krateo-system
    port: 8181
```

You will need to customize the `webhook.fullnameOverride`, we suggest using the `resource` name of the composition (i.e., the plural of the composition kind). The rest of the fields can be left as is if you installed OPA through Krateo. Otherwise, you will need to specify the certificate, with `webhook.certsSecretRef`, or specify a CA bundle with `webhook.CA`. Finally, you will need to change the service and port in `webhook.service`.

Even if you create more than one composition, only one webhook will ever be installed (thanks to Helm templating and lookups).

We provide pre-installed in OPA the following [policies](https://github.com/krateoplatformops/finops-moving-window-policy-chart/tree/main/policies):
- main router: depending on the resource type, it will route the webhook request to a different policy
- moving window: an optimizatio policy that looks for underutilization and tries to size correctly resources with percentage-based utilization
- api client: it allows to obtain objects from Kubernetes in a Rego policy

You will need to modify these to add your own policies. After you modify and re-apply the chart, you also need to restart OPA, since these are bootstrap policies. We reccomend packing your policies into a container and configuring them in OPA separately.

<details>
  <summary>If you want to use the moving window optimization:</summary>

For the moving window optimization (provided by [this microservice](https://github.com/krateoplatformops/finops-moving-window-microservice), called by the moving window policy), you also need to add to the values.yaml file:

```diff
+optimization: "The resource utilization and the proposed optimization for the given resource." # Default text for the optimization panel
...
+policyAdditionalValues:
+  cronJobSchedule: "0 0 * * *" # default: daily
+  optimizationServiceEndpointRef:
+    name: finops-moving-window-microservice-endpoint
+    namespace: azure-pricing-system
```

The first field, `optimization`, will be patched by the policy with the proposed optimization. 
The field `policyAdditionalValues.optimizationServiceEndpointRef` has to contain the reference to the service of the [microservice](https://github.com/krateoplatformops/finops-moving-window-microservice). Finally, the `policyAdditionalValues.cronJobSchedule` is how often the optimization should be triggered.

We trigger the optimization with a `CronJob` that updates the composition resource with a label that contains the timestamp of the last optimization request. This, in turn, triggers the webhook, activating our policies. You can find all the resources for the `CronJob` [here](./chart/templates/cronjob.yaml). Aside from the templating names (i.e., `vm-azure.xxxxx`), the `CronJob` can be copied into any other composition.

</details>

### FinOps Tab in the Composition Page
To visualize the graphics in the frontend composition page, you need to use a different dependency for the frontend elements in your Chart.yaml file:

```diff
apiVersion: v2
name: vm-azure
description: Krateo FinOps Example Pricing for Azure VM
type: application
version: CHART_VERSION
appVersion: APP_VERSION
dependencies:
 - name: finops-webhook-template
   condition: webhook.enabled
   version: "0.1.0"
   repository: "https://charts.krateo.io"
   alias: webhook
+- name: composition-portal-starter-finops
+  condition: portal.enabled
+  version: "0.1.4"
+  repository: "https://charts.krateo.io"
+  alias: portal
```

This modified version of the [composition-portal-starter](https://github.com/krateoplatformops/composition-portal-starter), the [composition-portal-starter-finops](https://github.com/krateoplatformops/composition-portal-starter-finops), contains an additional tab with many new widgets and rest actions that allow you to visualize the data you have just configured for collection.

### FinOps Dashboard
No configuration is required for this component, you can install it directly in the Krateo namespace:
```sh
helm install finops-dashboard krateo/finops-dashboard -n krateo-system
```

## Customize or Extend the Example Composition to Include More Azure Resources
If you want to utilize this Composition Definition as is but customize it with your own Azure resources, you can add them with two requirements. First, you need to add the annotation for the pricing:
```diff
apiVersion: compute.azure.com/v1api20220301
kind: VirtualMachine
metadata:
  name: {{ .Values.name }}
+ annotations: 
+   krateo-finops-focus-resource: '["{{ .Values.vmSize }}"]'
spec:
  hardwareProfile:
    vmSize: {{ .Values.vmSize }}
...
```
This annotation should be changed to the SKU that you want to download. For example, for an AKS cluster with two nodes `Standard_D2s_v3`, you should add:
```diff
apiVersion: containerservice.azure.com/v1api20240901
kind: ManagedCluster
metadata:
  name: managedcluster
+ annotations: 
+   krateo-finops-focus-resource: '["Standard_D2s_v3", "Standard_D2s_v3"]'
spec:
+ tags:
+   compositionId: {{ .Values.global.compositionId }}
  owner:
    name: managedcluster
  location: "northeurope"
  dnsPrefix: "aks"
  kubernetesVersion: 1.31.7
  agentPoolProfiles:
    - name: systempool
      count: 2
      vmSize: Standard_D2s_v3
      mode: System
  operatorSpec:
    secrets:
    adminCredentials:
      name: "managedcluster-kubeconfig"
      key: "kubeconfig"
  identity:
    type: SystemAssigned
```
Where two `Standard_D2s_v3` represent the pricing of two nodes. You should also add the tag with the composition id, standardizing the billing information.

The pricing composition will therefore become:
```yaml
apiVersion: composition.krateo.io/v0-1-0
kind: FocusDataPresentationAzure
metadata:
  name: standard-ds2v2-pricing
  namespace: azure-pricing-system
spec:
  annotationKey: krateo-finops-focus-resource
  filter: serviceName eq 'Virtual Machines' and armSkuName eq 'Standard_D2s_v3' and type eq 'Consumption' and armRegionName eq 'northeurope'
  operatorFocusNamespace: krateo-system
  scraperConfig:
    tableName: pricing_table
    pollingInterval: "1h"
    scraperDatabaseConfigRef: 
      name: finops-database-handler
      namespace: krateo-system
```

Second, you will need to gather the metrics, therefore you should create as many `ExporterScraperConfig` as you have created nodes, and adapt them slightly compared to what you have in this example composition. In our case, we will collect the cluster metrics, thus we still only need one. To lookup the cluster metrics, we need to modify the lookup, since you should now search for a `ManagedCluster`:
```diff
- {{- $vm := lookup "compute.azure.com/v1api20220301" "VirtualMachine" .Release.Namespace .Values.name }}
+ {{- $vm := lookup "containerservice.azure.com/v1api20240901" "ManagedCluster" .Release.Namespace .Values.name }}
```

Then, you need to change the metric type to `node_cpu_usage_percentage`, to get the average CPU usage across all cluster nodes:
```diff
metricExporter:
  timespan: "month" # one of day, month, year, see helper dates for customization
  interval: "PT15M"
- metricName: "Percentage CPU"
+ metricName: "node_cpu_usage_percentage"
  pollingInterval: "1h"
  scraperDatabaseConfigRef:
    name: finops-database-handler
    namespace: krateo-system
```
To get a list of all metrics available you can CURL (with a valid bearer token):
```sh
https://management.azure.com/<RESOURCE ID>/providers/microsoft.insights/metrics?api-version=2023-10-01&timespan=2025-06-04/2025-07-04&interval=PT15M
```

Assuming you used the YAML provided before, you can get the resource id with:
```sh
kubectl get -n azure-pricing-system managedclusters managedcluster -o jsonpath={'.status.id'}
```

To obtain the bearer token you can run:
```sh
curl -s -X POST -d 'grant_type=client_credentials&client_id=<YOUR CLIENT ID>&client_secret=<YOUR CLIENT SECRET>&resource=https%3A%2F%2Fmanagement.azure.com%2F' https://login.microsoftonline.com/<YOUR TENANT ID>/oauth2/token  | jq -r .access_token
```

Now you have configured the composition to install a `ManagedCluster` resource, show pricing and collect usage metrics. Since the metrics are percentage-based (i.e., `node_cpu_usage_percentage`), the optimization policy will work directly on this new resource. The billing will automatically update thanks to the one-shot configuration and this new resource, since it is tagged with the composition id, will be detected automatically.