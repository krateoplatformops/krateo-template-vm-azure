# Krateo Composable FinOps Template for an Azure Virtual Machine
This repository contains a Composition Definition for Krateo that leverages the Krateo Composable FinOps components to integrate resources created through the Azure Operator, the pricing visualization flow, the cost and usages collections and optimization. The composition creates a Virtual Machine on Azure through the Azure operator, visualizing it in the frontend through a card widget and custom form. The widget shows the pricing information retrieved through the FinOps module. Inside the composition page, the FinOps tab allows to see costs and usages of the virtual machine.

It achieves so through the following components:
 - [finops-composition-definition-parser](https://github.com/krateoplatformops/finops-composition-definition-parser): this component parses the annotations contained in this chart, with the name `focus-resource-name`;
 - [azure-pricing-rest-dynamic-controller-plugin](https://github.com/krateoplatformops/azure-pricing-rest-dynamic-controller-plugin): plugin for the operator generator to gather data from the Azure pricing API;
 - [focus-data-presentation-azure](https://github.com/krateoplatformops/focus-data-presentation-azure): this composition definition integrates a custom resource for the generator operator that fetches data from the Azure pricing API and the custom resource for the FOCUS operator, which allows the fetched pricing information to be stored into the database.
 - [composition-portal-starter-finops](https://github.com/krateoplatformops/composition-portal-starter-finops): this frontend extension allows to show a breakdown of the costs of the composition and the usage metrics.
 - all other components from Krateo Composable FinOps: [finops-operator-exporter](https://github.com/krateoplatformops/finops-operator-exporter), [finops-operator-scraper](https://github.com/krateoplatformops/finops-operator-scraper), [finops-operator-focus](https://github.com/krateoplatformops/finops-operator-focus) and [finops-database-handler](https://github.com/krateoplatformops/finops-database-handler)

For `Krateo 2.4.3`, install [this composition](https://github.com/krateoplatformops/krateo-v2-template-finops-example-pricing-vm-azure) with version `0.1.4`. For `Krateo 2.5.0`, install this composition. The composition for Krateo 2.4.3 **omits** Open Policy Agent and its policies, thus removing the optimization components.

Checkout the [cheatsheet](cheatsheet.md) for an in-depth guide to Krateo Composable FinOps integration.

## Summary

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Examples](#examples)
4. [Installation](#Installation)
5. [Cost and Usage Metrics](#cost-and-usage-metrics)

## Architecture
This composition definition uses the components from the following architecture:

<p align="center">
<img src="/_diagrams/architecture.png" width="800">
</p>

## Examples
The following figure shows an example of the pricing information retrieved from the Azure Pricing API, placed inside the side menu:
<p align="center">
<img src="/_diagrams/pricing_frontend.png" width="800">
</p>

<sub>Note: The `1 GB/Month` expenditure has been added through the API as an example of multiple values and will not appear when installing the composition.</sub>

The FinOps tab will look like this when populated with metrics:
<p align="center">
<img src="/_diagrams/metrics_frontend.png" width="800">
</p>

> [!NOTE]
> Do not put "_" in the virtual machine or resource group names, because it is used by Azure to differentiate between name and resource name for dependencies of the virtual machine (e.g., disks).

## Installation
Install the [krateo-template-finops-azure-configuration](https://github.com/krateoplatformops/krateo-template-finops-azure-configuration) and configure Azure for Krateo Composable FinOps.

Install the [azure-pricing-rest-dynamic-controller-plugin](https://github.com/krateoplatformops/azure-pricing-rest-dynamic-controller-plugin):
```sh
helm install azure-pricing-rest-dynamic-controller-plugin krateo/azure-pricing-rest-dynamic-controller-plugin -n azure-pricing-system
```

Install the [focus-data-presentation-azure](https://github.com/krateoplatformops/focus-data-presentation-azure) composition definition:
```sh
cat <<EOF | kubectl apply -f -
apiVersion: core.krateo.io/v1alpha1
kind: CompositionDefinition
metadata:
  annotations:
     "krateo.io/connector-verbose": "true"
  name: focus-data-presentation-azure
  namespace: azure-pricing-system
spec:
  chart:
    repo: focus-data-presentation-azure
    url: https://charts.krateo.io
    version: "0.1.0"
EOF
```

Install the composition for the [focus-data-presentation-azure](https://github.com/krateoplatformops/focus-data-presentation-azure), which creates the `DataPresentationAzure` resource, managed by the [rest-dynamic-controller](https://github.com/krateoplatformops/rest-dynamic-controller). Then, the [composition-dynamic-controller](https://github.com/krateoplatformops/composition-dynamic-controller) will install the FocusConfig for the [finops-operator-focus](https://github.com/krateoplatformops/finops-operator-focus), which will start the exporter/scraper flow.
```sh
cat <<EOF | kubectl apply -f -
apiVersion: composition.krateo.io/v0-1-0
kind: FocusDataPresentationAzure
metadata:
  name: finops-example-azure-vm-pricing
  namespace: azure-pricing-system
spec:
  annotationKey: krateo-finops-focus-resource
  filter: serviceName eq 'Virtual Machines' and armSkuName eq 'Standard_B2s' and type eq 'Consumption'
  operatorFocusNamespace: krateo-system
  scraperConfig:
    tableName: pricing_table
    pollingInterval: "1h"
    scraperDatabaseConfigRef: 
      name: finops-database-handler
      namespace: krateo-system
EOF
```

Install the composition definition for this component:
```sh
cat <<EOF | kubectl apply -f -
apiVersion: core.krateo.io/v1alpha1
kind: CompositionDefinition
metadata:
  annotations:
     "krateo.io/connector-verbose": "true"
  name: vm-azure
  namespace: azure-pricing-system
spec:
  chart:
    repo: vm-azure
    url: https://charts.krateo.io
    version: "0.1.0"
EOF
```

Install the resources for the frontend: 
```sh
kubectl apply -f ./portal/
```

Install the [finops-moving-window-microservice](https://github.com/krateoplatformops/finops-moving-window-microservice) with Helm:
```
helm install -n azure-pricing-system finops-moving-window-microservice krateo/finops-moving-window-microservice
```

# Billing, Cost and Usage Metrics
This section will cover how to configure the Krateo Composable FinOps to collect cost and usage metrics from the virtual machine just created on Azure.

## Billing and Cost
If you installed [krateo-template-finops-azure-configuration](https://github.com/krateoplatformops/krateo-template-finops-azure-configuration), they are automatically gathered.

## Usage Metrics
No additional setup is required to obtain usage metrics from Azure.
The Helm chart already includes an `exporterscraperconfig.yaml` file among its templates, which contains the configuration for the exporters and scrapers related to usage metrics of the virtual machine created through the composition.

The specified `timespan` is computed through the helper file `_dates.tpl`. It can be used as is with the following ranges:
- Day
- Month
- Year

It can also be customized to include additional ranges. The file already accounts for leap years. The usage example can be found in the template of the ExporterScraperConfig:
```yaml
{{- $currentDate := now }} # Where now is, for example, the 15th of June 2025
{{- $backupRange := list .Values.metricExporter.timespan $currentDate.Year $currentDate.Month $currentDate.Day | include "dates.dateRange" }} # .Values.metricExporter.timespan is "month"
# backupRange value is 2024-06-15/2025-06-15
```

## Optimizations (Krateo 2.5.0)
The optimizations rely on Open Policy Agent (OPA). The instances of this composition definition will install the hook automatically through the [finops-webhook-template-chart](https://github.com/krateoplatformops/finops-webhook-template-chart), which is imported as a dependency. The template checks whether the webhook already exists, if it does not then it creates it, otherwise it does nothing. If you have a custom installation of OPA that uses https, you will need to manually configure the certificates, otherwise, if you installed OPA through the Krateo Installer, it is done automatically.

The fields:
```yaml
policyAdditionalValues:
  optimizationServiceEndpointRef:
    name: finops-moving-window-microservice-endpoint
    namespace: azure-pricing-system
```
are used by the [finops-moving-window-policy](https://github.com/krateoplatformops/finops-moving-window-policy) in OPA and point to the endpoint of the [finops-moving-window-optimization-microservice](https://github.com/krateoplatformops/finops-moving-window-microservice). The policy parses all the data from the cluster (e.g., secrets) and serves the complete request to the microservice, which then queries the [finops-database-handler](https://github.com/krateoplatformops/finops-database-handler) for the timeseries data to calculate the optimization. Finally, it returns the optimization to the policy. The policy mutates the composition through the [finops-webhook-template](https://github.com/krateoplatformops/finops-webhook-template) to add the optimization to the field `spec.optimization`, which is then displayed in the frontend.

The policy is triggered by a `CronJob` running periodically (every day by default) that labels the Composition resource with a label `optimization` that has as the value the timestamp with the last optimization request.

# Composition Creation and Krateo Namespace
> [!NOTE] 
> This FinOps composition example only works when Krateo is installed in `krateo-system`. If Krateo is installed in a different namespace, you **must** configure the variable `krateoNamespace`, in the `values.yaml` file `.global.krateoNamespace`, to the correct namespace when instantiating a composition. 