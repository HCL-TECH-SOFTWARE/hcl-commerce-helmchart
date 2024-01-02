# HCL Commerce deployment on Kubernetes using Helmchart

## Introduction
HCL Commerce is a single, unified e-commerce platform that offers the ability to do business directly with consumers (B2C) or directly with businesses (B2B). It is also a customizable, scalable, distributed, and high availability solution that is built to use open standards. HCL Commerce uses cloud friendly technology to make deployment and operation both easy and efficient. It provides easy-to-use tools for business users to centrally manage a cross-channel strategy. Business users can create and manage precision marketing campaigns, promotions, catalog, and merchandising across all sales channels.

HCL Commerce Version 9 is full Docker-based release. For more information, see: [HCL Commerce Version 9](https://help.hcltechsw.com/commerce/9.1.0/admin/concepts/covoverall.html).

A complete HCL Commerce V9 environment compose with Auth environment and Live environment. Auth environment is for site administrator and business users. Live environment is for shoppers access. See [HCL Commerce V9 Runtime Overview](https://help.hcltechsw.com/commerce/9.1.0/install/refs/riginfrastructure.html)

Vault-Consul is a mandatory component that is used by default Certificate Agent to automatically issue certificates. It is also used by the Configuration Center to store environment-related data.

Note: The 9.1.15.0 Helm Chart can only be used to deploy HCL Commerce 9.1.15.0 Docker containers. This version of the Helm Chart cannot be used to deploy previous versions of HCL Commerce containers due to the inclusion of non-root user support.

## Prerequisites
1. You have a kubernetes cluster where you can deploy HCL Commerce. It could be on private or public cloud or even on a kubernetes cluster setup locally.
1. HCL Commerce supports several ways to configure application. The default configuration mode used by this helm chart is `Vault` configuration mode. Vault is also the recommended configuration mode for HCL Commerce as it was designed to store configuration data securely. HCL Commerce also uses Vault as Certificate Authority to issue certificate to each application to communicate with each other. Therefore, make sure you have a vault service available for HCL Commerce to access. For non-production environments, you can consider to use hcl-commerce-vaultconsul-helmchart to deploy and initialize vault for HCL Commerce as it could initialize the vault and populate data for HCL Commerce. However, that chart runs vault in development and non-HA mode and doesn't handle vault token securely, therefore it should not be used for production. You can read [Vault Concepts](https://www.vaultproject.io/docs/concepts) for all considerations to run vault on production. 
1. Vault token must be stored as a secret object, and the secret name is configured in helmchart values to allow HCL Commerce application to consume the vault token value. If you use hcl-commerce-vaultconsul-helmchart to deploy vault for development or non-production usage, a secret named `vault-token-secret` should have been created already in the commerce namespace. Otherwise, follow the steps below to create a secret for vault token.
	1. Get base64 encoded string of your vault token by running `echo -n $vault_token | base64`  
	1. Replace <VAULT_TOKEN> to value obtained above, and replace <NAME_SPACE> to `commerce` in following secret definition, and save it to a file `vault-secret.yaml` 
	```
    apiVersion: v1
    kind: Secret
    metadata:
      name: vault-token-secret
      namespace: <NAME_SPACE>
    type: Opaque
    data:
      VAULT_TOKEN: <VAULT_TOKEN>
	```
	1. Run `kubectl apply -f vault-secret.yaml` to create secret in commerce namespace.
1. See How to prepare data on vault in section `Custom Read All Data From Vault` below.
1. All docker images involved in the HCL Commerce deployment are loaded to a docker registry where your kubernetes cluster can access to. The default Docker images. Please find more details of HCL Commerce docker images on [HCL Commerce eAssemblies](https://help.hcltechsw.com/commerce/9.1.0/install/refs/rigbackuppak.html)
1. For quick exploring purpose, you can use the HCL Commerce sample DB2 docker image, which has the default schema and sample bootstrap data loaded, to explore HCL Commerce features and functionality. However, it is strongly recommended to setup your database on its dedicated server so that you can persist data and tune performance. See [Setup prerequisites](https://help.hcltechsw.com/commerce/9.1.0/install/tasks/tiginstallprereq.html) for more details of database setup.
1. Role Based Access Control (RBAC) must be created first and only once on the target namespace. The remaining steps in this document is assuming that HCL Commerce is deployed on "commerce" namespace. Perform the following steps as Cluster Admin.
   1. Create a namespace "commerce" by running `kubectl create namespace commerce`
   1. Modify `rbac.yaml` file by replacing `<namespace>` to `commerce`
   1. Run `kubectl apply -f rbac.yaml` to apply the rbac.

### PodSecurityPolicy Requirements
In some cloud platform, such as IBM Cloud, it requires a PodSecurityPolicy to be bound to the target namespace prior to installation.  Choose either a predefined PodSecurityPolicy or have your cluster administrator setup a custom PodSecurityPolicy for you:
* Predefined PodSecurityPolicy name: [`ibm-privileged-psp`](https://ibm.biz/cpkspec-psp)
* Custom PodSecurityPolicy definition:

> Note: This PodSecurityPolicy only needs to be created once. If it already exist, skip this step.

```
apiVersion: extensions/v1beta1
kind: PodSecurityPolicy
metadata:
  name: commerce-psp
spec:
  hostIPC: false
  allowPrivilegeEscalation: true
  readOnlyRootFilesystem: false
  allowedCapabilities:
  - CHOWN
  - DAC_OVERRIDE
  - FOWNER
  - FSETID
  - KILL
  - SETGID
  - SETUID
  - SETPCAP
  - NET_BIND_SERVICE
  - NET_RAW
  - SYS_CHROOT
  - MKNOD
  - AUDIT_WRITE
  - SETFCAP
  - SYS_RESOURCE
  - IPC_OWNER
  - SYS_NICE
  seLinux:
    rule: RunAsAny
  supplementalGroups:
    rule: RunAsAny
  runAsUser:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
  volumes:
  - configMap
  - emptyDir
  - persistentVolumeClaim
  - secret
  forbiddenSysctls:
  - '*'
```

* Custom ClusterRole for the custom PodSecurityPolicy:

```
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: commerce-psp-clusterrole
rules:
- apiGroups:
  - extensions
  resourceNames:
  - commerce-psp
  resources:
  - podsecuritypolicies
  verbs:
  - use

```

The cluster admin can either paste the above PSP and ClusterRole definitions into the create resource screen in the UI or run the following two commands:

- `kubectl create -f <PSP yaml file>`
- `kubectl create clusterrole commerce-psp-clusterrole --verb=use --resource=podsecuritypolicy --resource-name=commerce-psp`

In ICP 3.1, you also need to create the RoleBinding:

- `kubectl create rolebinding commerce-psp-rolebinding --clusterrole=commerce-psp-clusterrole --serviceaccount=<namespace>:default --namespace=<namespace>`

In ICP 3.1.1+, you need to create the RoleBinding:

- `kubectl create rolebinding ibm-psp-rolebinding --clusterrole=ibm-privileged-clusterrole --serviceaccount=<namespace>:default --namespace=<namespace>`

## Resources Required
By default, when you use the Helm Chart to deploy HCL Commerce Version 9, you start with the following number of Pods and required resources:

Component  | Replica | Request CPU | Limit CPU | Request Memory | Limit Memory
--------  | -----| -------------| -------------| -------------| -------------
ts-app | 1 | 500m |  2 | 5120Mi | 5120Mi
ts-db | 1 | 2 |  2 | 6144Mi | 6144Mi
ts-web| 1 | 500m |  2 | 2048Mi | 2048Mi
search-app-master | 1 | 500m |  2 | 4096Mi | 4096Mi
search-app-repeater ( live ) | 1 | 500m |  2 | 4096Mi | 4096Mi
search-app-slave ( live ) | 1 | 500m |  2 | 4096Mi | 4096Mi
crs-app | 1 | 500m |  2 | 4096Mi | 4096Mi
xc-app | 1 | 500m |  2 | 4096Mi | 4096Mi
tooling-web | 1 | 500m | 2 | 2048Mi | 2048Mi
store-web | 1 | 500m | 2 | 2048Mi | 2048Mi
nifi-app | 1 | 500m | 2 | 10240Mi | 10240Mi
registry-app | 1 | 500m | 2 | 2048Mi | 2048Mi
ingest-app | 1 | 500m | 2 | 4096Mi | 4096Mi
query-app | 1 | 500m | 2 | 4096Mi | 4096Mi
cache-app | 1 | 500m | 2 | 2048Mi | 2048Mi
graphql-app | 1 | 500m | 2 | 2048Mi | 2048Mi
mustgather-app | 1 | 500m | 1 | 4096Mi | 4096Mi
ts-utils | 1 | 500m | 2 | 4096Mi | 4096Mi
approval-app | 1 | 500m | 2 | 2048Mi | 2048Mi
nextjs-app | 1 | 500m | 2 | 2048Mi | 2048Mi


Note: Ensure that you have sufficient resources available on your worker nodes to support the HCL Commerce Version 9 deployment.


## Configuration
HCL Commerce 9.1 supports traditional solr based search application as search engine, and it also introduces a data platform with ingest and elasticsearch architecture to deliver enhanced search features. With the data platform, a modernized React JS store can be deployed to create the best shopping experience possible. This helmchart supports to deploy HCL Commerce with different combinations of the application stack. 

### All configurable values
The following tables lists the configurable parameters of the hcl-commerce-helmchart and their default values.

| Parameter                  | Description                                     | Default                                                    |
| -----------------------    | ---------------------------------------------   | ---------------------------------------------------------- |
| `license`             | HCL Commerce V9 license accept             | `not_accepted`                                                        |
| `common.vaultTokenSecret`  | Kubernetes secret object for vault token        | `vault-token-secret`                                                    |
| `common.dbType`         | database type           | `db2`    |
| `common.tenant`                |   tenant name                          | `demo`                                                   |
| `common.environmentName`       |   environment name | `qa`                                                |
| `common.environmentType`     |   environment type \[auth \| live \| share\]            | `auth`                                                       |
| `common.searchEngine`        |   Search type \[solr \| elastic\] | `elastic` |
| `common.imageRepo`      |   docker image registry             | `my-docker-registry.io:5000/`
| `common.spiUserName`          |  spiuser name for Commerce                     | `spiuser`                                                    |
| `common.spiUserPwdAes`        |  spiuser name password by encrypted with AES by wc_encrypt.sh. default plain text password is `QxV7uCk6RRiwvPVaa4wdD78jaHi2za8ssjneNMdu3vgqi`. With the default key, `cSG7n0iFVpt+Az2JUKeJQJGOXfDkZUUpIYCS1hJXL9hYK3yaSQ2ssVCoz/SKoaCH3g+g+9FGcLejkI/KpJLI5Q==` could be the sample value to match with the sample db2 container| `nil` |
| `common.spiUserPwdBase64`        | Base64 encoded value for `<spiuser>:<password>`. default plain text password is QxV7uCk6RRiwvPVaa4wdD78jaHi2za8ssjneNMdu3vgqi out of the box, and `c3BpdXNlcjpReFY3dUNrNlJSaXd2UFZhYTR3ZEQ3OGphSGkyemE4c3NqbmVOTWR1M3ZncWk=` as base64 encrypted value. This value can be obtained by running `echo -n <spiuser>:<password> \| base64`| `nil`
| `common.vaultUrl`        |  vault v1 api url | `http://vault-consul.vault.svc.cluster.local:8200/v1` (assuming hcl-commerce-vaultconsul-helmchart is used to deploy vault in vault namespace)
| `common.externalDomain`        | External Domain use to specify the service external domain name| `.mycompany.com`
| `common.bindingConfigMap`        | ConfigMap name which mount into each default container to expose as environment variables. keep it as blank if not using config map to pass configuration to each application. | `nil`
| `common.configureMode`        |  default container config mode \[Vault \| EnvVariables\] | `Vault`
| `common.runAsNonRoot.enabled`        |  Set to true would start all the pods as the non-root user (comuser) to improve overall security. However, if you are upgrading your existing env, be sure to check your existing customizations to make them compatible with the non-root user. If you still want to use the root user to start all the pods, then set to false would start all the pods as the root user. | `true`
| `common.runAsNonRoot.migrateAssetsPvcFromRootToNonroot`        |  When upgrading your existing env from using root user to non-root user for the first time. Enable this option to update the ownership of the files and directories stored for assetsPVC. This option will trigger a pre-upgrade job to update the ownership. | `true`
| `common.imagePullSecrets`        |  image pull secrets if docker registry requires authentication | `nil`
| `common.imagePullPolicy`        |  image pull policy \[IfNotPresent\|Always\] | `IfNotPresent`
| `common.serviceAccountName`        |  serviceAccount used for helm release  | `default`
| `common.dataIngressEnabled`        |  flag to control is ingress is created for data platform services. Production environment must have it disabled to avoid security impact.  | `false`
| `common.localStoreEnabled`        |  flag to enable local store specific ingress creation when deploying the migrated aurora type of store in transaction server.  | `false`
| `common.timezone`        |  timezone in ICANN TZ format, such as "America/Toronto", to set in all commerce containers as environment variable "TZ". If not set or empty, 'GMT' will be used in all of containers by defualt.<br>CAUTION: changing the timzone will impact on some business logics, such as marketing web activity and promotion start and end date/time, as they are set to the commerce server time and won't auto update based on this timezone setting. It is recommended to keep it empty if your commerce is already on production and never set it explicitly previously. | `nil`
| `common.ipv6Enabled`        |  When disbaled, commerce apps will add java.net.preferIPv4Stack=true jvm arg  | `false`
| `backwardCompatibility.selector`        |  pod selector labels defined in the existing deployment. This is required when you deployed Commerce using a different chart previously and want to use this chart to upgrade.  | `empty map`
| `backwardCompatibility.ingressFormatUpgrade.enabled`        |  Some of the Nginx and GKE ingress names got updated since V9.1.7.0. When upgrading from a version prior to V9.1.7.0 to a newer version, enable this flag to trigger an upgrade job to clean up the old ingress definitions to avoid conflicts during upgrade.  | `false`
| `hclCache.configMap`        |  config map for hcl cache definition  | see [values.yaml](./values.yaml) file for the default configuration
| `ingress.enabled`        |  ingress enablement. Make it disabled for SoFy deployment | `true`
| `ingress.ingressController`        |  ingress controller \[nginx \| gke \| emissary \| ambassador \]. Set it to "gke" when deploying on GKE with http(s) load balancing server as ingress controller. | `nginx`
| `ingress.enableToolingForReactStore`        |  this needs to be set to true when you are planning to allow sapphire store to launch B2B approval tooling. | `true`
| `ingress.enableManageApprovalPage`        |  this flag is able to enable the manage approval page for marketplace approval service, set to false by default for security. | `false`
| `ingress.emissaryIdsList`        |  ambassador ids list specifications for the emissary listener | nil
| `ingress.ingressSecret.autoCreate`        |  specify if need helm pre-install auto create ingress certification secret| `true`
| `ingress.ingressSecret.replaceExist`        |  specify if need to force replace exist ingress certification secret when deploy | `true`
| `vaultCA.enabled`        |  enable VaultCA configuration mode | `true`
| `metrics.enabled`        |  enable metrics for HCL Commerce  | `true`
| `metrics.serviceMonitor.enabled`        |  enable service monitor for HCL Commerce  | `false`
| `metrics.serviceMonitor.interval`        |  interval to let prometheus to hit HCL Commerce for service monitoring | `15s`
| `metrics.serviceMonitor.selector`        | labels for prometheus to match for service monitoring | see [values.yaml](./values.yaml) file for the default configuration
| `dx.enabled`        |  enable dx related configurations for HCL Commerce | `true`
| `dx.serviceName.auth`        |  auth dx routing service name | nil
| `dx.serviceName.live`        |  live dx routing service name | nil
| `dx.namespace.auth`        |  dx auth environment namespace, note this should be in the same cluster as commerce | nil
| `dx.namespace.live`        |  dx live environment namespace, note this should be in the same cluster as commerce | nil
| `searchIndexCreation`        |  detailed configuration for search index job  | see [values.yaml](./values.yaml) file for default configuration
| `logging.jsonLogging.enabled`        |  Global Logging configuration applies to all deployed app | `false`
| `assetsPVC.enabled`        |  Enable creating a persistent volume claim (PVC) for the assets tool. If set to true, a PVC with ReadWriteMany access mode would be created. | `false`
| `assetsPVC.storageClass`        |  The storage class name that is going to be used by the pvc for the assets tool. This resource provider should support ReadWriteMany access mode. | Default storage class for the cluster
| `assetsPVC.storage`        |  The persistent volume size assigned to the assets pvc. | `5Gi`
| `assetsPVC.accessMode`        |  The access mode of the pvc, it is required to be ReadWriteMany for the assets pvc. | `ReadWriteMany`
| `assetsPVC.existingClaim.auth`        |  If there is already an existed assets pvc for the authoring environment, you can put it here. | `nil`
| `assetsPVC.existingClaim.live`        |  If there is already an existed assets pvc for the live environment, you can put it here. | `nil`
| `openshiftDeployment.enabled`        |  Enable this feature for deployment using openshift. | `false`
| `openshiftDeployment.sccName`        |  The name of an SecurityContextConstraints resource the service account should have access to | `privileged`
| `openshiftDeployment.destinationCACertificate`        |  destinationCACertificate used to validate ssl certificate for commerce routes | `nil`
| `tsDb`        |  detailed configuration for tsDb deployment  | see [values.yaml](./values.yaml) file for default configuration
| `tsApp`        |  detailed configuration for tsApp deployment  | see [values.yaml](./values.yaml) file for default configuration
| `searchAppMaster`        |  detailed configuration for searchAppMaster deployment  | see [values.yaml](./values.yaml) file for default configuration
| `searchAppRepeater`        |  detailed configuration for searchAppRepeater deployment  | see [values.yaml](./values.yaml) file for default configuration
| `searchAppSlave`        |  detailed configuration for searchAppSlave deployment  | see [values.yaml](./values.yaml) file for default configuration
| `tsWeb`        |  detailed configuration for tsWeb deployment  | see [values.yaml](./values.yaml) file for default configuration
| `toolingWeb`        |  detailed configuration for toolingWeb deployment  | see [values.yaml](./values.yaml) file for default configuration
| `storeWeb`        |  detailed configuration for storeWeb deployment  | see [values.yaml](./values.yaml) file for default configuration
| `nextjsApp`        |  detailed configuration for nextjsApp deployment  | see [values.yaml](./values.yaml) file for default configuration
| `crsApp`        |  detailed configuration for crsApp deployment  | see [values.yaml](./values.yaml) file for default configuration
| `xcApp`        |  detailed configuration for xcApp deployment  | see [values.yaml](./values.yaml) file for default configuration
| `nifiApp`        |  detailed configuration for nifiApp deployment  | see [values.yaml](./values.yaml) file for default configuration
| `registryApp`        |  detailed configuration for registryApp deployment  | see [values.yaml](./values.yaml) file for default configuration
| `ingestApp`        |  detailed configuration for ingestApp deployment  | see [values.yaml](./values.yaml) file for default configuration
| `cacheApp`        |  detailed configuration for cacheApp deployment  | see [values.yaml](./values.yaml) file for default configuration
| `graphqlApp`        |  detailed configuration for graphqlApp deployment  | see [values.yaml](./values.yaml) file for default configuration
| `queryApp`        |  detailed configuration for queryApp deployment  | see [values.yaml](./values.yaml) file for default configuration
| `mustgatherApp`        |  detailed configuration for mustgatherApp deployment  | see [values.yaml](./values.yaml) file for default configuration
| `tsUtils`        |  detailed configuration for tsUtils deployment  | see [values.yaml](./values.yaml) file for default configuration
| `approvalApp`        |  detailed configuration for approvalApp deployment  | see [values.yaml](./values.yaml) file for default configuration
| `supportC.image`        |  supportcontainer docker image for initial container and helm pre-install / post-delete  | `commerce/supportcontainer`
| `supportC.tag`        |  supportcontainer docker tag  | `v9-latest`
| `test.image`        |  test docker image for helm test  | `docker.io/centos:latest`


### Common Configuration
It is strongly recommended to not modify the default [values.yaml](./values.yaml) file for your deployment, but instead copying it to your customized values file, e.g my-values.yaml file, to maintain your customized values for your future deployment and upgrade.

The following values should be modified in your my-values.yaml file to match to your environment and cluster configuration.
#### license
You must accept the license before you can deploy HCL Commerce. To view the license, please browse all files under LICENSES directory. To accept the license, set `license` to `accept`.

#### common.timezone
If specified it will add an environment variable to all the containers to specify the timezone to use in the format of: America/Toronto by following the ICANN TZ Database. If not specified, 'GMT' is used in all the containers by default.

CAUTION: changing the timzone will impact on some business logics, such as marketing web activity and promotion start and end date/time, as they are set to the commerce server time and won't auto update based on this timezone setting. It is recommended to keep it empty if your commerce is already on production and never set it explicitly previously.

#### common.tenant, common.environmentName and common.environmentType
Tenant can be your company name. You can have multiple environment under the same tenant. E.g the environment name could be dev, qa or production. For each commerce environment, it can be partitioned to 3 logical groups to hold different application. `auth` holds the commerce staging applications used by business users. `live` holds the production applications to serve the live traffic from shoppers. `share` holds the applications can be consumed by both auth and live, e.g data platform and new tooling are deployed in the share group. Tenant, environment name and environment type are used to form the path to lookup environment configuration values in vault as well. In general, these values should contain lower case characters only without space or any special characters.

#### common.vaultTokenSecret
The name of the secret object which contains the vault token. Refer to [Prerequisites](#Prerequisites) to understand how vault token is passed to HCL Commerce

#### common.dbType
The type of database the environment is using. Valid values are `db2` and `oracle`.

#### common.imageRepo
The docker registry repository with `<docker_registry_domain>[:port]/` format

#### common.spiUserName
The SPI user name used for basic authentication with server to server communication. `spiuser` is the default value comes out of the box.

#### common.spiUserPwdAes
The AES encrypted value of the spiuser password. `cSG7n0iFVpt+Az2JUKeJQJGOXfDkZUUpIYCS1hJXL9hYK3yaSQ2ssVCoz/SKoaCH3g+g+9FGcLejkI/KpJLI5Q==` can be used to match the value configured in the sample db2 container. This value can be obtained by running wcs_encrypt.sh utility from utility container. Visit [Setting the spiuser password](https://help.hcltechsw.com/commerce/9.1.0/install/tasks/tiginstall_definespi.html) to find more details.

#### common.spiUserPwdBase64
Base64 encoded value for `<spiuser>:<password>`. This value can be obtained by running `echo -n <spiuser>:<password> | base64`

#### common.vaultUrl
Vault V1 api url. If hcl-commerce-vaultconsul-helmchart is used to deploy development vault service in vault namespace, `http://vault-consul.vault.svc.cluster.local:8200/v1` can be used to hit the vault V1 API. Please correct this value to point to your production vault service for your production commerce.

#### common.externalDomain
External domain used for ingress and store preview URL. For example. in hostname store.demoqaauth.mycompany.com , `.mycompany.com` would be the External Domain name.

#### common.configureMode
Commerce supports Vault and EnvVariables configuration mode. Default is Vault which is also recommended configuration mode.

#### common.runAsNonRoot.enabled
MAJOR UPDATE IN COMMERCE HELM CHART VERSION 9.1.14.0. Set to true would start all the pods as the non-root user (comuser) to improve overall security. However, if you are upgrading your existing env, be sure to check your existing customizations to make them compatible with the non-root user. If you still want to use the root user to start all the pods, then set to false would start all the pods as the root user. Default value is set to true.

#### common.runAsNonRoot.migrateAssetsPvcFromRootToNonroot
When upgrading your existing env from using root user to non-root user for the first time. Enable this option to update the ownership of the files and directories stored for assetsPVC. This option will trigger a pre-upgrade job to update the ownership.

#### common.imagePullSecrets
The name of the secret name which contains the credential for pulling images from docker registry. leave it empty if docker registry if there is no authentication for your private docker registry.

#### common.imagePullPolicy
The policy to control when to pull docker images. Valid values are `IfNotPresent` and `Always`

#### common.serviceAccountName
The service account name which binds to the necessary roles to deploy commerce. `default` is used by default.

#### common.dataIngressEnabled
When dataIngressEnabled is set to true, it will create ingress to data platform services such as nifi, ingest and data query services for PD. You must keep it as false for production to avoid security impact. 

#### common.localStoreEnabled
When migrating from V7 or V8, there is an option to deploy the old Aurora based store in transaction server. In this case, set localStoreEnabled to be true to allow service and ingress to be configured properly. By default it is not enabled as the default Aurora store comes with V9 is remote, i.e. run on it's own server

#### common.ipv6Enabled
When disbaled, commerce apps will add `java.net.preferIPv4Stack=true` jvm arg

#### vaultCA.enabled
Flag to enable vault as Certificate Authority to issue certificate. Default is true.

#### ingressSecret.autoCreate and ingressSecret.replaceExist
IngressSecret is used to specify whether to auto-generate and replace the secret for ingress. Default to true for both.

### Metrics and Service monitor configuration
HCL Commerce is easy to enable metrics and use prometheus for service monitoring.

#### metrics.enabled
Flag to control if metrics are enabled for HCL Commerce applications. Default to true.

#### metrics.serviceMonitor.enabled
Flag to enable service monitoring with prometheus. Default is false
#### metrics.serviceMonitor.namespace
Specify a namespace in which to install the ServiceMonitor resource. Default to use the same release namespace where commerce is deployed to if namespace is not specified.
#### metrics.serviceMonitor.interval
Interval between service monitor requests. Default to 15 seconds
#### metrics.serviceMonitor.selector
selector labels to match prometheus. Defaults to what's used if you follow CoreOS [Prometheus Install Instructions](https://github.com/helm/charts/tree/master/stable/prometheus-operator#tldr), [Prometheus Selector Label](https://github.com/helm/charts/tree/master/stable/prometheus-operator#prometheus-operator-1), [Kube Prometheus Selector Label](https://github.com/helm/charts/tree/master/stable/prometheus-operator#exporters)

### HCL Cache configuration
The HCL Cache extends the capabilities of DynaCache by adding remote centralized caching with Redis, with additional operational and monitoring support. To learn how to config HCL Cache, visit [HCL Cache Configuration](https://help.hcltechsw.com/commerce/9.1.0/developer/concepts/chclcacheconfig.html)

Please note that the same configuration must be used to deploy auth, live and share. If you update this configmap, please make sure you re-deploy auth, live and share to have all commerce apps running with the same cache and redis configuration.

### DX configuration
Configurations here would enable commerce to integrate with the existed auth and live DX environments deployed in the same cluster as HCL Commerce. Note Nginx ingress has to be used to deploy HCL Commerce and GKE ingress is currently not supported. With these configurations, DX would be accessible with the same domain name as HCL Commerce.

#### dx.enabled
Flag to control if DX related configurations are enabled. Default to false.

#### dx.namespace.auth
Namespace used for DX auth environment. Note this should be in the same cluster as HCL Commerce.

#### dx.namespace.live
Namespace used for DX live environment. Note this should be in the same cluster as HCL Commerce.

### Search index job configuration
When elasticsearch based data platform is enabled, an optional search index job can be created at deployment time to trigger index build. Please note this job is for elasticsearch index only, but not for Solr search index. When job is created, it would monitor and wait for the required components, such as search-nifi and search-ingest, to get ready, and then trigger the build index for your specified stores. The job would also monitor the index status and wait for it to complete.

#### searchIndexCreation.enabled
A flag to enable the creation of the elasticsearch index creation job.

#### searchIndexCreation.pushToLiveEnabled
A flag to enable the push-to-live index connector run in the job.

#### searchIndexCreation.overalMaxDuration
The max duration time in seconds for the job to timeout. Please make this value reasonable depending on how many stores you want to index and the data size of each store. If the value is not big enough, the job would be killed before it completes all required tasks.

#### searchIndexCreation.indexMaxDuration
The max duration time in seconds for each index run to timeout.

#### searchIndexCreation.interval
The interval in seconds for index job to wait in between each readiness check for dependent components.

#### searchIndexCreation.maxRetry
The max retries for each index run in case the index fails.

#### searchIndexCreation.txnMaxDuration
The max duration time in seconds to wait for transaction server to be ready.

#### searchIndexCreation.nifiMaxDuration
The max duration time in seconds to wait for search nifi app to be ready.

#### searchIndexCreation.ingestMaxDuration
The max duration time in seconds to wait for search ingest server to be ready.

#### searchIndexCreation.storeIds
A list of store ids separated by comma to run index against.

#### searchIndexCreation.calculatePriceEnabled
A flag to enable the calculate price for B2B stores.

#### searchIndexCreation.calculatePriceStoreIds
A list of store ids separated by comma to run price calculation.

### Logging configuration
By default the commerce applications are not logging in json format, but in the format specified in each server. When aggregating in centralized logging system, such as EFK, it would be better and required to enable the json logging format.
#### logging.jsonLogging.enabled
A flag to enable the json logging globally to all commerce applications.

### Ingress Configuration
Ingress is generally used to allow external access to the apps deployed in kubernetes cluster. HCL Commerce helm chart defines the ingress to allow access to most commonly used services in commerce. You can use them directly or take them as reference and define your customized ingress based on your need.

#### ingress.enabled
A flag to enable the ingress creation. Please note in case you use ambassador as ingress solution, you will need to set it to false, and the ambassador mappings will be created directly instead of ingress in kubernetes.

#### ingress.apiVersion
use `networking.k8s.io/v1beta1` for kubernetes between 1.16 and 1.19 (exclusive).
use `networking.k8s.io/v1` for kubernetes 1.19 and above to avoid the api deprecation warning messages. see https://kubernetes.io/docs/reference/using-api/deprecation-guide/#ingress-v122 for details.

#### ingress.ingressController
The ingress controller to take the ingress requests. The supported ingress controllers are `nginx`, `gke`, and `ambassador`. When deploying on GKE and use the default GCE ingress, please specify it as `gke` for this value. In EKS, the only supported ingress controller is `nginx`.

#### ingress.ingressSecret.autoCreate
configuration to specify whether Helm needs to auto-generate the tls secret for ingress. This is a convenient way to generate the self-signed certificate for testing environment.

#### detailed ingress configuration for each service
HCL Commerce helm chart defined a list of commonly accessed services, such as `cmc`, `crs`, `reactstore`, etc. For each of these services, you can configure the `domain`, `ingressClass` and `tlsSecret` for auth and live.

### Assets tool persistent volume claim configuration
Assets tool in management center was available in v7 and v8 of commerce. Starting from Commerce v9, it has been removed. Starting from v9.1.8.0, it is re-enabled. With assets tool, you can manage files and attachment and make it accessible by stores. It means the files need to be shared across multiple micro service containers. To make the assets tool fully functioning and get the files persisted, ReadWriteMany type of storage is required. Check our knowledge centre: https://help.hcltechsw.com/commerce/9.1.0/install/tasks/tdeploykubern91-pre.html for more information about how to provision a ReadWriteMany type of persistent volume claim in Kubernetes.

#### assetsPVC.enabled
Enable creating a persistent volume claim (PVC) for the assets tool. If set to true, a PVC with ReadWriteMany access mode would be created.

#### assetsPVC.storageClass
The storage class name that is going to be used by the pvc for the assets tool. This resource provider should support ReadWriteMany access mode. 

#### assetsPVC.storage 
The persistent volume size assigned to the assets pvc.

#### assetsPVC.accessMode
The access mode of the pvc, it is required to be ReadWriteMany for the assets pvc. 

#### assetsPVC.existingClaim.auth
If there is already an existed assets pvc for the authoring environment, you can put it here. 

#### assetsPVC.existingClaim.live
If there is already an existed assets pvc for the live environment, you can put it here. 

### Openshift deployment
When deploying HCL Commerce on OCP, a few more configuration are needed, especially the security context and routes related.

#### openshiftDeployment.enabled
A flag to indicate the deployment is on openshift.

#### openshiftDeployment.sccName
The name of an SecurityContextConstraints resource the service account should have accesss to in order to make successful deployment on OCP.

#### openshiftDeployment.destinationCACertificate
In OCP deployment, the routes resources will be created directly instead of ingress. You will need to specify the CA certificate to allow the HAProxy to trust the certificate of commerce servers. The CA certificate is the one you specified in vault deployment.

### Commerce Deployment Configuration
#### Database
Database connection information is stored in vault. See [Configuration data in vault](#Custom-Read-All-Data-From-Vault).
For quickly deploying HCL Commerce to exploring the features, you can choose to use sample Db2 database image which has pre-loaded some sample data. To deploy this database, make sure the docker image has been uploaded to your private docker registry, and then set `tsDb.enabled` to `true`. Please note that this sample Db2 docker image does not designed to persist the data so it should not be used for your real business.

Please note that the sample Db2 has contract price support for the new react stores in 9.1. This impacts Aurora store using Solr search, and you will see "Price pending" in Aurora. Please do the following if you are using sample Db2 container and running Aurora store with Solr Search and not using Contract Price:

1. Wait for deployment to complete.
1. Update DB with:
    ```
    update storeconf set VALUE='0' where  NAME='wc.search.priceMode.compatiblePriceIndex';
    ```
1. In WC Admin Console --> Configuration --> Registry --> Update All
    or Restarting TS


#### Deploy with traditional solr based search
By setting `common.searchEngine` to `solr`, it enabled HCL Commerce deployment with solr based search engine. In this deployment, it will deploy search master in auth group, and search repeater and slave in live group. It will not deploy the elastic search based data platform. Please note that with solr based search engine, the new react js store can not be deployed as the new react js store requires elastic search query services to work properly.

#### Deploy with Elastic Search data platform
By setting `common.searchEngine` to `elastic`, it enables HCL Commerce deployment with elastic based search engine. In this deployment, it will deploy elastic search based data platform (nifi, registry, ingest and data-query) in share group, and deploy query service in auth and live group. It will not deploy solr based search app with this configuration.

Elastic search based data platform requires elastic search, zookeeper and redis service which are not included in HCL Commerce helm chart. You can deploy elastic search, zookeeper and redis easily by using their official helmchart. See [Elasticsearch, zookeeper and redis deployment] (#Elasticsearch-zookeeper-and-redis-deployment) for examples.

#### Deploy Aurora Store
If you migrate commerce from V7 or V8 to V9 and want to deploy the existing store, you would have to deploy the migrated store in transaction server, i.e. local aurora store. In this case, set `crsApp.enabled` to `false` as the commerce remote store (CRS) server is not required. Otherwise, if your store is using remote aurora type of programming model, the store is running with crs-app, and set `crsApp.enabled` to `true` to allow crs-app in deployment. Please note that remote aurora is supported to use elastic search engine as well, so it can also be co-exist with the new react js store in case you are operating multiple stores in Commerce and they are using different programming models (i.e. Aurora and React JS)

#### Deploy with React JS store
React JS store is a headless store purely on front end, and it is running in store-web docker container. Set `storeWeb.enabled` to `true` would enable react js store deployment. Please note that `common.searchEngine` has to be set to `elastic` for store-web to deploy as it depends on the elastic search query service. For traditional solr based search engine, set `storeWeb.enabled` to `false`.

#### Docker image configuration
Under each app definition (such as tsApp, tsWeb, etc.), `image` defines the image path relative to the `common.imageRepo`, and `tag` defines the image tag. Go through each app and make sure the image and tag are set correctly based on the actual images stored in your private docker registry.

#### Replica and Resource allocation
under each app definition (such as tsApp, tsWeb, etc), `replica` is set to 1 by default, meaning only one pod is deployed per application. To increase the performance and processing power, you can increase `replica` for some application such as tsApp. You can also customize the resource (CPU and MEM) allocation by modifying the `resources` definition for each app.

#### Persist data for search
It is strongly recommended to mount persistent volume for following app to persist data. Otherwise, search index will be stored inside of container will gone when container be killed.
* solr search
  - searchAppMaster
  - searchAppRepeater
* elastic search
  - nifiApp

To mount a volume
1. Create a persistent volume claim in Kubernetes 
    1. save following to a yaml file, e.g pvc.yaml
    ```
      apiVersion: v1
      kind: PersistentVolumeClaim
      metadata:
        name: <pvc name, e.g demoqa-nifi-pvc>
        namespace: <namespace, e.g commerce>
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 10Gi
        storageClassName: <storage class name, e.g standard for gke>
    ```
    2. Use `kubectl apply -f pvc.yaml` to create pvc
1. configure `persistentVolumeClaim` with the PVC name under `searchAppMaster`, `searchAppRepeater` or `nifiApp`

#### Upgrade Commerce from 9.0.x to 9.1+
In previous helmchart for Commerce 9.0.x.x, the deployment matches the following labels to select pods
- app (WCSV9)
- chart ({{ .Chart.Name }}, e.g ibm-websphere-commerce)
- release ({{ .Release.Name }}, e.g demo-qa-auth)
- heritage ({{ .Release.Service }}, e.g Helm)
- component ({{ .Values.common.tenant }}{{ .Values.common.environmentName}}{{ .Values.common.environmentType }}{{.Values.xxApp.name}}, 
              e.g demoqaauthcrs-app)
- group ({{ .Values.common.tenant }}{{ .Values.common.environmentName}}{{ .Values.common.environmentType }}, e.g demoqaauth)

In this helmchart, the app and chart values are updated. This would cause helm upgrade fail as the LabelSelector is immutable. To upgrade v9.0.x.x deployment to v9.1.x.x using this chart without downtime, specify the `backwardCompatibility.selector` to match the existing deployment. e.g
```
backwardCompatibility:
  selector:
    ## In V9.0.x.x helmchart, app is specified as WCSV9 by default
    app: WCSV9

    ## In V9.0.x.x helmchart, chart is specified as ibm-websphere-commerce by default 
    chart: ibm-websphere-commerce
```

For new deployment, keep `backwardCompatibility.selector` as the empty map. i.e.
```
backwardCompatibility:
  selector: {}
```

#### Upgrade Commerce to 9.1.14.0+
In 9.1.14+, HCL Commerce container images are built to be run as a non-root user by default. HCL Commerce images are generally built on top of Red Hat Universal Base Image (UBI) 8 images and have a non-root user named ‘comuser’ with UID 1000, and a user group named ‘comuser’ with GID 1000 created during image built1. HCL Commerce Containers are run by ‘comuser’ by default. HCL Commerce helm chart is also updated to run containers in Kubernetes pods as ‘comuser’ or UID 1000.

By enable `common.runAsNonRoot.enabled` in the helm chart, all the pods would as the non-root user (comuser). If you still want to use the root user to start all the pods, then set to false would start all the pods as the root user. Default value is set to true. 

One thing to notice is Persistent Volumes and external files at runtime. We need to make sure the files are set with the proper ownership or permissions to be accessed by comuser within the container. Otherwise, it may fail to read or write the files mounted from the host volume.  

ReadWriteOnce type of persistent volumes provisioned by the cloud storage class are normally mounted with the root user as the owner user previous to 9.1.14, and fsGroup has been set to 1000 in helm chart files starting from 9.1.14. In theory any files even created by root user previously should still be readable and writeable by non-root user. 

However, for readWriteMany type of persistent volumes, e.g the one required by HCL Commerce Assets tool, can be provisioned by a different provider, such as NFS Provisioner, and in this case, the fsGroup specified in helm chart won’t influence on the existing files in the volumes and it will require the file permission migration. In helm chart, a pre-upgrade job will be used to set the file ownership before deploying a new pod, you can enable this by setting `common.runAsNonRoot.migrateAssetsPvcFromRootToNonroot` to true. There is a chance that some new files are produced in the volume by the old pod during the helm upgrade and the files are not with the proper file ownership or permission. Therefore, it is recommended to manually kick off a Kubernetes job after helm upgrade is completed. The sample job yaml file `nonroot-ownership-update.yaml` can be found in the upgrade folder under stable/hcl-commerce, please update the file accordingly like the namespace, name, and presistent volume claim name fields. Use `kubectl apply -f nonroot-ownership-update.yaml` command to create the job. This manual job will not be auto deleted, if you want to trigger the same job again without any changes to the job name, then need to delete the existed job first.


## Use helm to deploy HCL Commerce
Once you finish the configuration in your my-values.yaml file and meet the [prerequisite] (#Prerequisites) requirement. You are ready to deploy HCL Commerce by using helm command.
To install the chart (first time deployment)
1. Deploy share group with release name `demo-qa-share` in commerce namespace.
  ```
  helm install demo-qa-share <path to hcl-commerce-helmchart> -f my-values.yaml --set common.environmentType=share -n commerce
  ```
2. Deploy auth group with release name `demo-qa-auth` in commerce namespace.
  ```
  helm install demo-qa-auth <path to hcl-commerce-helmchart> -f my-values.yaml --set common.environmentType=auth -n commerce
  ```
3. Deploy live group with release name `demo-qa-live` in commerce namespace.
  ```
  helm install demo-qa-live <path to hcl-commerce-helmchart> -f my-values.yaml --set common.environmentType=live -n commerce
  ```

Once the commerce app are deployed, if you have configuration changes or image update, you can use helm upgrade command to update the deployment.

When you install or update, HCL Commerce Version 9 Container startup must follow this sequence. The initContainer will automatically control it. The whole deploy process can take on average of 8-10 mins, depending on the capacity of the Kubernetes worker node.

When you check the deployment status, the following values can be seen in the Status column:
```
– Running: This container is started.
– Init: 0/1: This container is pending on another container to start.
```
You may see the following values in the Ready column:
```
– 0/1: This container is started but the application is not yet ready.
– 1/1: This application is ready to use.
```

Run the following command to make sure there are no errors in the log file:
```
kubectl logs -f <pod_name>
```

## Uninstalling the Chart
To uninstall/delete the release deployment:
```
$ helm delete <release-name>
```

## Access Environment
By default, the Helm Chart uses the default value (tenant / env / envtype ). If you change those values, update your variable value to replace demoqaauth with following steps.

1. Check ingress server IP address.
  ```
  kubectl get ingress -n <namespace>
  ```

2. Create the ingress server IP and hostname mapping on your server by editing your local hosts file.

For auth environment:
  ```
  <Ingress_IP>  store.demoqaauth.mycompany.com www.demoqaauth.mycompany.com cmc.demoqaauth.mycompany.com tsapp.demoqaauth.mycompany.com search.demoqaauth.mycompany.com
  ```

For live environment:
  ```
  <Ingress_IP>  store.demoqalive.mycompany.com www.demoqalive.mycompany.com cmc.demoqalive.mycompany.com tsapp.demoqalive.mycompany.com searchrepeater.demoqalive.mycompany.com
  ```

Note: search.demoqaauth.mycompany.com use to expose search master service.  searchrepeater.demoqalive.mycompany.com use to expose search repeater sericve on live for trigger index replica.

3. Access the environment with following URLs:

      Aurora Store Front:
      https://store.demoqaauth.mycompany.com/wcs/shop/en/auroraesite

      Emerald Store Front (A sample React JS Store):
      https://www.demoqaauth.mycompany.com/Emerald

      Management Center:
      https://cmc.demoqaauth.mycompany.com/lobtools/cmc/ManagementCenter

## Build Search Index
### Build Search index for solr based search app
1. Trigger the Build Index with default master catalog ID ( default spisuer name is spiuser, default spiuser password is QxV7uCk6RRiwvPVaa4wdD78jaHi2za8ssjneNMdu3vgqi, default masterCatalogID with sample data is 10001 ).

    curl -X POST -u spiuser:QxV7uCk6RRiwvPVaa4wdD78jaHi2za8ssjneNMdu3vgqi https://tsapp.demoqaauth.mycompany.com/wcs/resources/admin/index/dataImport/build?masterCatalogId=10001 -k

    You should get a response with a jobStatusId. e.g 1001

2. Check the Build Index Status ( default spisuer name is spiuser, default spiuser password is QxV7uCk6RRiwvPVaa4wdD78jaHi2za8ssjneNMdu3vgqi )

    curl -X GET -u spiuser:QxV7uCk6RRiwvPVaa4wdD78jaHi2za8ssjneNMdu3vgqi https://tsapp.demoqaauth.mycompany.com/wcs/resources/admin/index/dataImport/status?jobStatusId=1001 -k

### Build Search index for elastic based data platform
1. Create a connector
In HCL Commerce 9.1.0.0, the connectors is not created by default. In order to build index, you need to call ingest service to create a connector. Therefore, it will require you to deploy Commerce with `common.dataIngressEnabled` set to `true`
    1. Create the ingress server IP and hostname mapping on your server by editing your local hosts file.
        ```
        <Ingress_IP>  ingest.demoqa.mycompany.com nifi.demoqa.mycompany.com
        ```
    2. Access the ingest swagger API http://ingest.demoqa.mycompany.com/swagger-ui/index.html?url=/v3/api-docs&validatorUrl=#/Create%20Connector%20Configuration/createConnector
    3. Click "Try it out" for POST /connectors, and paste the content from auth-reindex-connector.json (available in [Creating an Ingest service connector](https://help.hcltechsw.com/commerce/9.1.0/search/tasks/tsdconnector_create.html)) as request body. Creating connector usually takes a long time to complete and you would get a HTTP 504 due to the ingress controller timeout before the actual request gets completed on the ingest server. In this case, it is safe to ignore the HTTP 504 from this REST service call. HCL Commerce Development team is working on a better solution to handle the connector creation, and it will be addressed properly in a future Fixpack.
    4. Monitor the connector creation in nifi UI (http://nifi.demoqa.mycompany.com/nifi/), and when you see all reindex related process are created and no stopped components show up, it is ready to run the connector. It may take 10 min to fully create the connector.
    5. delete the data ingress by `kubectl delete ingress demoqadata-ingress -n commerce` to avoid any unexpected access to it.
    6. disable the `common.dataIngressEnabled` by setting it to `false` to prevent future deployment create data ingress.

For details about creating a connector, see [Creating an Ingest service connector](https://help.hcltechsw.com/commerce/9.1.0/search/tasks/tsdconnector_create.html)

2. Run connector
    1. Trigger the build index
    curl -X POST -k -u spiuser:QxV7uCk6RRiwvPVaa4wdD78jaHi2za8ssjneNMdu3vgqi "https://tsapp.demoqaauth.mycompany.com/wcs/resources/admin/index/dataImport/build?connectorId=auth.reindex&storeId=1"
    You should get a response with a jobStatusId. e.g 1001
    2. Check the Build Index Status ( default spisuer name is spiuser, default spiuser password is QxV7uCk6RRiwvPVaa4wdD78jaHi2za8ssjneNMdu3vgqi )
    curl -X GET -k -u spiuser:QxV7uCk6RRiwvPVaa4wdD78jaHi2za8ssjneNMdu3vgqi "https://tsapp.demoqaauth.mycompany.com/wcs/resources/admin/index/dataImport/status?jobStatusId=1001"

3. Repeat above steps to create and run url-connector to create SEO for Emerald (Sample B2C react js store ), and price-connector for contract price. See [Creating an Ingest service connector](https://help.hcltechsw.com/commerce/9.1.0/search/tasks/tsdconnector_create.html) for details.


## Custom Read All Data From Vault ####
Refer to [Environment data structure in Consul/Vault](https://help.hcltechsw.com/commerce/9.1.0/install/refs/rigvaultmetadata.html) and [retrieving parameters from Vault](https://help.hcltechsw.com/commerce/9.1.0/install/refs/rigstart_vault.html) for details


## Elasticsearch zookeeper and redis deployment
Elasticsearch and zookeeper are required to deploy elastic search data platform. You can use the official helmchart to deploy. Below are some example steps.
The deployments of Elasticsearch, Zookeeper, and Redis require specific versions of their Helm Charts. These versions are compatible with the sample values bundled in HCL Commerce Helm Chart Git project. The specific version values are referenced in the hcl-commerce-helmchart/stable/hcl-commerce/Chart.yaml Helm Chart, from the cloned HCL Commerce Helm Chart Git project. Ensure that the versions specified in the following commands with the version parameter are aligned with the values that are referenced in this file.

### Deploy Elasticsearch
1. Create a namespace
    ```
    kubectl create ns elastic
    ```
2. Add helm repo
    ```
    helm repo add elastic https://helm.elastic.co
    ```
3. Deploy elasticsearch using a local elasticsearch-values.yaml file (available in sample_values directory)
    ```
    helm install elasticsearch elastic/elasticsearch -n elastic -f elasticsearch-values.yaml --version "elasticsearch-chart-version"
    ```
4. Monitor deployment until all pods are healthy
For details please see [Elasticsearch Helm Chart](https://github.com/elastic/helm-charts/tree/master/elasticsearch)

### Deploy Zookeeper
1. Create a namespace
    ```
    kubectl create ns zookeeper
    ```
2. Add helm repo
    ```
    helm repo add bitnami https://charts.bitnami.com/bitnami
    ```
3. Deploy Zookeeper using a local zookeeper-values.yaml file (available in sample_values directory)
    ```
    helm install my-zookeeper bitnami/zookeeper -n zookeeper -f zookeeper-values.yaml --version "zookeeper-chart-version"
    ```
4. Monitor deployment until all pods are healthy

For details see [ZooKeeper helm Chart](https://github.com/bitnami/charts/tree/master/bitnami/zookeeper) 


### Deploy Redis
1. Create a namespace
    ```
    kubectl create ns redis
    ```
2. Add helm repo
    ```
    helm repo add bitnami https://charts.bitnami.com/bitnami
    ```
3. Deploy Redis using a local redis-values.yaml file (available in sample_values directory)
    ```
    helm install my-redis bitnami/redis -n redis -f redis-values.yaml --version "redis-chart-version"
    ```
4. Monitor deployment until all pods are healthy

For details see [Redis helm Chart](https://github.com/bitnami/charts/tree/master/bitnami/redis) 
