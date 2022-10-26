# Azure Reference Platform for Kubernetes: Application with Secure Data Services

![Upbound Overview](docs/media/upbound.png)

This repository contains a reference Azure Platform
Configuration to build, run, and operate your own internal cloud. It provides platform APIs to provision
fully configured Azure AKS clusters, with secure networking and stateful cloud
services (Azure Database for MariaDB) designed to securely connect to the nodes in the AKS cluster, 
with an application (Wordpress) consuming the infrastructure --
all composed using cloud service primitives from the [Upbound Azure
Provider](https://marketplace.upbound.io/providers/upbound/provider-azure/latest).

## Contents

* [Build Your Own Internal Cloud Platform](#build-your-own-internal-cloud-platform)
* [Quick Start](#quick-start)
  * [Create Upbound Cloud Managed UXP Control Plane](#Create-Upbound-Cloud-Managed-UXP-Control-Plane)
  * [Install the Platform Configuration](#Install-the-Platform-Configuration)
  * [Provision Resources](#Provision-Resources)
  * [Cleanup](#Cleanup)
* [Learn More](#learn-more)


You can eliminate infrastructure bottlenecks, security pitfalls, and
deliver apps faster by providing your teams with self-service APIs that
encapsulate your best practices and security policies, so they can quickly
provision the infrastructure they need using a custom cloud console, `kubectl`,
or deployment pipelines and GitOps workflows -- all without writing code.

[Upbound Cloud](https://upbound.io) enables you, powered by the
open source [Upbound Universal Crossplane](https://www.upbound.io/uxp/) project.

With the open source [Upbound Universal Crossplane](https://www.upbound.io/uxp/) project,
consistent self-service APIs can be provided across dev, staging, and
production environments. Making it easy for app teams to get the infrastructure
they need using vetted infrastructure configurations that meet the standards
of your organization.

## Build Your Own Internal Cloud Platform

App teams can provision the infrastructure they need with a single YAML file
alongside `Deployments` and `Services` using existing tools and workflows
including tools like `kubectl` and gitops platforms to consume your platform's self-service
APIs.

The Platform `Configuration` defines the self-service APIs and
classes-of-service for each API:

* `CompositeResourceDefinitions` (XRDs) define the platform's self-service
   APIs as Kubernetes CRDs, referred to as Composite Resource Claim and Composite Resource.
* `Compositions` are selected by a Composite Resources and create composed resources.

Crossplane `Providers` include the cloud service primitives (AWS, Azure, GCP,
etc.) used in a `Composition`.

Learn more about these concepts in the [Crossplane
Docs](https://crossplane.io/docs/).

## Quick Start

At a high-level, this reference platform results in the following architecture.

![](docs/media/ref-architecture.png)

Three Claims create a Resource Group, Virtual Network with Private Endpoint for Azure Database Service, three Subnets, AKS Cluster attached to the Virtual Network, Azure Database Service with MariaDB engine, Helm install of Prometheus, and a Helm install of Wordpress that create dedicated external database instance connected over Private Endpoint to the AKS cluster network.

The Database Services could be consolidated with the EKS Claim, but it has been kept separate to show modularity in applying Compositions.

In this quick start, you will install Upbound UXP, and use a Crossplane Configuration Package to deploy this configutation in your Azure cloud environment.

### 1. Create an Upbound.io user account and Organization

_Note: If you haven't already, create a local clone of this repo, paths to files in this quick start relative to the root of the repo._

Create an account and an Organization in [Upbound Cloud](https://accounts.upbound.io/register)

### 2. Download and install the Upbound `up` command-line

```console
curl -sL "https://cli.upbound.io" | sh
mv up /usr/local/bin/
```

_Note: official providers only support up command-line versions v0.13.0 or later._


### 3. Install Upbound Universal Crossplane with the Up command-line

```console
$ up uxp install
```

Verify the UXP pods are running with `kubectl get pods -n upbound-system`

```console
$ kubectl get pods -n upbound-system
NAME                                        READY   STATUS    RESTARTS      AGE
crossplane-7fdfbd897c-pmrml                 1/1     Running   0             68m
crossplane-rbac-manager-7d6867bc4d-v7wpb    1/1     Running   0             68m
upbound-bootstrapper-5f47977d54-t8kvk       1/1     Running   0             68m
xgql-7c4b74c458-5bf2q                       1/1     Running   3 (67m ago)   68m
```

### 4. Log in with the Up command-line

Use up login to authenticate to the Upbound Marketplace.

It's important to use `-a <your organization>` when logging in. Only accounts belonging to organizations can use official providers.

```console
$ up login -a my-org
username: my-user
password: *********
```

### 5. Create an Upbound robot account

Upbound robots are identities used for authentication that are independent from a single user and aren’t tied to specific usernames or passwords.

Creating a robot account allows Kubernetes to install an official provider.

Use `up robot create <robot account name>` to create a new robot account.

_Note: only users logged into an organization can create robot accounts._

```console
$ up robot create my-robot
my-org/my-robot created
```

### 6. Create an Upbound robot account token

The token associates with a specific robot account and acts as a username and password for authentication.

Generate a token using `up robot token create <robot account> <token name> --output=<file>`.

```console
$ up robot token create my-robot my-token --output=token.json
my-org/my-robot/my-token created
```

The output file is a JSON file containing the robot token's accessId and token. The accessId is the username and token is the password for the token.

_Note: you can't recover a lost robot token. You must delete and recreate the token._

### 7. Create a Kubernetes pull secret

Downloading and installing official providers requires Kubernetes to authenticate to the Upbound Marketplace using a Kubernetes secret object.

Using the `up controlplane pull-secret create <secret name> -f <robot token file>` command creates an Upbound robot account image pull secret.

Provide a name for your Kubernetes secret and the robot token JSON file.

_Note: robot accounts are independent from your account. Your account information is never stored in Kubernetes._

_Note: you must provide the robot token file or you can't authenticate to install an official provider._

```console
$ up controlplane pull-secret create my-upbound-secret -f token.json
my-org/my-upbound-secret created
```

Up creates the secret in the upbound-system namespace.

```console
$ kubectl get secret -n upbound-system
NAME                                         TYPE                             DATA   AGE
my-upbound-secret                            kubernetes.io/dockerconfigjson   1      8m46s
sh.helm.release.v1.universal-crossplane.v1   helm.sh/release.v1               1      21m
upbound-agent-tls                            Opaque                           3      21m
uxp-ca                                       Opaque                           3      21m
xgql-tls                                     Opaque                           3      21m
```

### 8. Install the official Azure provider

Install the official provider into the Kubernetes cluster with a Kubernetes configuration file.

```console
kubectl apply -f examples/provider-azure.yaml
```

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Provider
metadata:
  name: provider-azure
spec:
  package: xpkg.upbound.io/upbound/provider-azure:v0.12.0
  packagePullSecrets:
    - name: my-secret
```

_Note: the name of the packagePullSecrets must be the same as the name of the Kubernetes secret just created._

Apply this configuration with `kubectl apply -f`.

After installing the provider, verify the install with kubectl get providers.

```console
$ kubectl get provider
NAME             INSTALLED   HEALTHY   PACKAGE                                          AGE
provider-azure   True        True      xpkg.upbound.io/upbound/provider-azure:v0.12.0   58s
```

It may take up to 5 minutes to report `HEALTHY`.

If the packagePullSecrets is incorrect the provider returns a 401 Unauthorized error. View the status and error with kubectl describe provider.

```console
$ kubectl describe provider
Name:         provider-azure
API Version:  pkg.crossplane.io/v1
Kind:         Provider
# Output truncated
Events:
  Type     Reason         Age                 From                                 Message
  ----     ------         ----                ----                                 -------
  Warning  UnpackPackage  34s (x7 over 100s)  packages/provider.pkg.crossplane.io  cannot unpack package: failed to fetch package digest from remote: HEAD https://xpkg.upbound.io/v2/upbound/provider-azure/manifests/v0.5.1: unexpected status code 401 Unauthorized (HEAD responses have no body, use GET for details)
```

### 9. Create Provider credentials as a Kubernetes secret

The provider requires credentials to create and manage Azure resources.

Generating an authentication file requires the Azure command-line. Follow the documentation from Microsoft to Download and install the Azure command-line.

**Create an Azure service principal and configure permissions**

Follow the Azure documentation to find your Subscription ID from the Azure Portal.

Log in to the Azure command-line.

```console
az login
```

Provide your Azure Subscription ID to create a service principal and authentication file.

```console
az ad sp create-for-rbac --sdk-auth --role Owner --scopes /subscriptions/<Subscription ID> --name platform-ref-azure > azure-credentials.json
```

The command generates a JSON file like this:

```json
{
  "clientId": "5d73973c-1933-4621-9f6a-9642db949768",
  "clientSecret": "24O8Q~db2DFJ123MBpB25hdESvV3Zy8bfeGYGcSd",
  "subscriptionId": "c02e2b27-21ef-48e3-96b9-a91305e9e010",
  "tenantId": "7060afec-1db7-4b6f-a44f-82c9c6d8762a",
  "activeDirectoryEndpointUrl": "https://login.microsoftonline.com",
  "resourceManagerEndpointUrl": "https://management.azure.com/",
  "activeDirectoryGraphResourceId": "https://graph.windows.net/",
  "sqlManagementEndpointUrl": "https://management.core.windows.net:8443/",
  "galleryEndpointUrl": "https://gallery.azure.com/",
  "managementEndpointUrl": "https://management.core.windows.net/"
}
```

Take note of the `clientID` value from the JSON file we just created, and save it to an environment variable:

```console
export AZURE_CLIENT_ID=<clientId value from json file>
```

Now add and grant the required permissions to the service principal that will allow it to manage the necessary resources in Azure:

```console
# add required Azure Active Directory permissions
az ad app permission add --id ${AZURE_CLIENT_ID} --api 00000002-0000-0000-c000-000000000000 --api-permissions 1cda74f2-2616-4834-b122-5cb1b07f8a59=Role 78c8a3c8-a07e-4b9e-af1b-b5ccab50a175=Role

# grant (activate) the permissions
az ad app permission grant --id ${AZURE_CLIENT_ID} --api 00000002-0000-0000-c000-000000000000 --expires never
```

You might see an error similar to the following, but that is OK, the permissions should have gone through still:

_Operation failed with status: 'Conflict'. Details: 409 Client Error: Conflict for url: https://graph.windows.net/e7985bc4-a3b3-4f37-b9d2-fa256023b1ae/oauth2PermissionGrants?api-version=1.6_

Finally, you need to grant admin permissions on the Azure Active Directory to the service principal because it will need to create other service principals for your AKSCluster:

```console
az ad app permission admin-consent --id "${AZURE_CLIENT_ID}"
```

_Note: You might need Global Administrator role to Grant admin consent for Default Directory. Please contact the administrator of your Azure subscription. To check your role, go to Azure Active Directory -> Roles and administrators. You can find your role(s) by clicking on Your Role (Preview)_

**Create a Kubernetes secret with the Azure credentials JSON file**

Use `kubectl create secret -n upbound-system` to generate the Kubernetes secret object inside the Kubernetes cluster.

```console
kubectl create secret generic azure-secret -n upbound-system --from-file=creds=./azure-credentials.json
```

### 10. Create a ProviderConfig

Create a ProviderConfig Kubernetes resource manifest file to and link the Azure credentials to the installed official provider.

```console
kubectl apply -f examples/providerconfig-azure.yaml
```

```yaml
apiVersion: azure.upbound.io/v1beta1
metadata:
  name: default
kind: ProviderConfig
spec:
  credentials:
    source: Secret
    secretRef:
      namespace: upbound-system
      name: azure-secret
      key: creds
```

Apply this configuration with `kubectl apply -f`.

Verify the ProviderConfig with `kubectl describe providerconfigs`.

```console
$ kubectl describe providerconfigs
Name:         default
Namespace:
API Version:  azure.upbound.io/v1beta1
Kind:         ProviderConfig
# Output truncated
Spec:
  Credentials:
    Secret Ref:
      Key:        creds
      Name:       azure-secret
      Namespace:  upbound-system
    Source:       Secret
```

##  Create infrastrucutre and apps

### 1. Install Configuation

```console
kubectl apply -f examples/configuration.yaml
```

```yaml
apiVersion: pkg.crossplane.io/v1
kind: Configuration
metadata:
  name: cfg-pkg-platform-ref-azure
spec:
  ignoreCrossplaneConstraints: false
  package: xpkg.upbound.io/plat-ref-azure:v0.0.1
  revisionActivationPolicy: Automatic
  revisionHistoryLimit: 1
  skipDependencyResolution: false
  ```

### 2. Create resources:

```console
kubectl create -f examples/cluster-claim.yaml

kubectl create -f examples/db-claim.yaml

kubectl create -f examples/wp-chart-claim.yaml
```

```console
watch kubectl get managed
```

Wait for all resources to become `Ready`, then use `ctrl-c` to return to console prompt.

### 3. View resources in Azure console and connect to app




##  Cleanup

#### 1. Delete applications

Delete resources created through the `Control Plane` Configurations menu:

```console
kubectl delete -f examples/wp-chart-claim.yaml
```
>Wait until the Wordpress Release resource is completely removed before proceeding.

```console
kubectl get managed
```

#### 2. Delete database server and cluster

>Once the Wordpress Release deletion is completed, proceed.

```console
kubectl delete -f examples/db-claim.yaml

kubectl delete -f examples/cluster-claim.yaml
```

Verify all underlying resources have been cleanly deleted:

```console
kubectl get managed
```

#### 3. Uninstall Provider & Platform Configuration

```console
kubectl delete configuration.pkg.crossplane.io upbound-platform-ref-azure

kubectl delete provider.pkg.crossplane.io crossplane-provider-azure

kubectl delete provider.pkg.crossplane.io crossplane-provider-helm
```

#### 4. Uninstall Azure App Registration

>_Note: If you plan to continue testing with the Azure provider, perform this cleanup step later_

```console
AZ_APP_ID=$(az ad sp list --display-name platform-ref-azure)

az ad sp delete --id $AZ_APP_ID
```

## Learn More

The Azure cloud service primitives that can be used in a `Composition` today are
listed in the [Crossplane Azure Jet Provider
Docs](https://doc.crds.dev/github.com/crossplane-contrib/provider-jet-azure).

To learn more about creating and publishing your own Configuration Packages, see [Configuration
Packages](https://crossplane.io/docs/v1.7/concepts/packages.html).

### What's Next

If you're interested in building your own reference platform for your company,
we'd love to hear from you and chat. You can setup some time with us at
info@upbound.io.
