# HCL Commerce Vault Deployment
## Important Notice
Starting from version 2.1.0, consul is no longer deployed as it has not been playing significant role. However, to make values and deployment backward compatible, consul keyword is still used in values and some of the deployment resources.

## Introduction
Vault is used to store commerce environment configuration and secret, and is also used as  certification authority (CA) to issue certificate to commerce servers to allow them communicate with SSL.

This chart deploys Vault for HCL Commerce V9 as the remote configuration center, which stores environment data and acts as the certificate authority to issue certificate to each HCL Commerce app server based on unique service name.  Vault is required before you deploy HCL Commerce V9 application if you plan to use the `Vault` configuration mode.  It needs to be deployed only once and the service can be available to multiple Commerce environments. After the vault is started, it can run scripts to enable mount the tenant secret path and load commerce environment configuration data as you specified in values.yaml, and also it can enable and configure PKI backend to issue certificate if you enable the `vaultConsul.vaultLoadData` in values.yaml.

## Chart Details
This Helm Chart is only for testing and development purpose. It does not persist data or handle vault root token securely. However, for development and testing purpose, the data stored in the values.yaml can be used as a master copy and re-load the data every time when vault is redeployed or restarted.  Please refer [guide](
https://www.vaultproject.io/guides/operations/vault-ha-consul.html) of Vault to setup cluster to support production environment.

## Prerequisites
### Docker images
This Helm Chart attempts to pull Vault  Docker Image from DockerHub. If you use the default settings,
ensure that your environment can connect to internet. Or you can pull those Docker images to a private Docker Image Repository and update following values

Name |   Default Value | Usage
------------- | -------------| -------------
vaultConsul.imageRepo | docker.io/ | container registry for vault images
vaultConsul.vaultImageName | vault | Vault Docker Image name
vaultConsul.vaultImageTag | 1.13.4 | Vault Docker Image tag
supportC.imageRepo | my-docker-registry.io:5000/ | container registry for commerce support container image
supportC.image | commerce/supportcontainer | full path to the support container image
supportC.tag | v9-latest | image tag for commerce support container image
test.image |  docker.io/centos:latest | Helm Test command uses Centos Docker Image

> **Note**
vault:1.13.4 has been tested.  There is no guarantee that other tags for those docker images will work as expected.

### CA certificate
This helm chart deploy vault in development mode to by pass the unseal process. In this mode the data will be stored in memory only. The configuration data is defined in helm values file so they will be re-loaded everytime when vault is re-deployed / re-started. However, the root CA certificate stored in CA can not be persisted unless it is defined and persisted in a secret. This helm chart allows either specifying CA certificate by a tls secret name, or let this helm chart auto-generate one and persist it in the tls secret during the install time. 

#### Let vault helm chart to automatically generate and persist the CA certificate
To let vault helm chart auto create a CA certificate and create a TLS secret, please configure `externalCA.enabled` and `externalCA.autoCreate` to true in values. Also, this auto creation logic requires support container image which is configured in `supportC.imageRepo`, `supportC.image` and `supportC.tag`.

Please note that CA certificate auto generation is only done in the vault chart install time, i.e. `helm install`, but not `helm upgrade`. So if you have deployed the vault using the previous version of the chart, you will need to delete and re-install it.

#### Generate and specify your CA certificate manually
You can use the following steps to create a self-signed CA certificate and configure it to use in vault deployment.
1. create a private key
```
openssl genrsa -out private.key 2048
```

2. create a CA certificate
```
openssl req -x509 -new -nodes -key private.key -days 365 -out ca.pem -config req.conf
```
req.conf content
```
[ req ]
prompt=no
distinguished_name=dn
x509_extensions=ext

[ dn ]
CN=My Company CA

[ ext ]
basicConstraints=CA:TRUE
```

3. create a tls secret with kubectl
```
kubectl create secret tls my-vault-ca --cert=ca.pem --key=private.key -n vault
```

4. create override values file my-values.yaml for vault deployment with following content
```
common:
  externalCA:
    enabled: true
    existingSecretName: 'my-vault-ca'
    autoCreate: false
```

5. Deploy vault with helm install command
```
helm install my-vault <path-to-vault-chart> -n vault -f my-values.yaml
```

## Resources Required
The resource limitation is not defined for Vault-Consul, since it's used as the associate service to support HCL Commerce Version 9 deployment and will not handle high traffic volumes.

## Plan and Configure Values for vault deployment
Before deploying vault, you need to plan how you are going to deploy commerce, and then modify the data accordingly as the data specified in your values yaml file will be loaded to the vault as postStart action. In vault, a tenant name will be used as a secret mount path, this secret path will contain one or more environments, and each environment contains the key-value (KV) pairs. The environment level KVs will be under environment path directly, while auth and live instance specific KVs are under auth or live. E.g
```
	/Demo                                                        # tenant path
		/qa                                                      # env path
			internalDomainName: commerce.svc.cluster.local       # environment level properties
			…
			/auth                                                # auth instance path
				dbHost: myDb.com                                 # auth instance level properties
				…
			/live                                                # live instance path
				dbHost: myLiveDb.com                             # live instance level properties
```

It is strongly recommended to not modify the default [values.yaml](./values.yaml) file for your deployment, but instead copying it to your customized values file, e.g `my-values.yaml` file, to maintain your customized values for your future deployment and upgrade.

### Modify configuration in my-values.yaml file
#### common:
1. Change the tenant if you want to name it differently. Note, if you change the tenant name here, you will also need to change the tenant in commerce helm chart values to match the same name.
1. By default it does not create ingress for vault service. If you want to create an ingress to access vault ui, set `enableIngress` to `true`. Also, based on your environments, update the configurations for `ingressController` and `ingressApiVersion`.
1. Starting from Commerce 9.1.14.0, vault is started by the non-root user (vault) by default, check `runAsNonRoot` section for more details. Set it to true would start vault as the non-root user (vault) to improve overall security, if you still want to use the root user to start vault, then set the option to false.
1. As part of the vault deployment, it will create a vault token secret in the `commerce` namespace, so that the commerce application can get the vault token from that secret. It requires the commerce namespace existed before you can deploy this vault. If `commerce` namespace has not been created, you can create it now with `kubectl create ns commerce`. If you plan to deploy commerce in other name spaces, you need to create those names spaces now (kubectl create ns <namespace>), and list all of the namespaces in commerceNameSpaces. E.g if I want to deploy 2 commerce environments 'dev' and 'qa' in 'commerce-dev' and 'commerce-qa' name spaces, you would need to:
	1. kubectl create ns commerce-dev
	1. kubectl create ns commerce-qa
	1. Config `commerceNameSpaces` to following:
		```
		commerceNameSpaces: 
			- commerce-dev
			- commerce-qa
		```
#### vaultConsul:
1. Update `vaultImageTag` if you want to test different images
1. Update `vaultToken` to the one you want to use. 
1. If you change the `vaultToken` value, you will need to run `echo -n new_token | base64` and update `vaultTokenBase64` with this value
1. Enable and update the `vaultLoadDataWithSecret` section to improve your data security (ensure `vaultLoadData` is also enabled in order to load data). With this option enabled, you can ignore the `vaultData` section below. If you choose this method then need to manually create a secret, and put the secret name in `secretName`. A sample yaml file could be found under the sample_secret directory, and make sure you are following the right format.
1. Update the data under `vaultData`. E.g update the db information. See above [Plan and Configure Values for vault deployment](#Plan-and-Configure-Values-for-vault-deployment) for details of the data hierarchy in vault.


## Installing the Chart
It is recommended to deploy vault in a separate namespace, such as `vault` and serve for all commerce environments. If you don't `vault` namespace, you can create it by `kubectl create ns vault`. Following command is to use helm (v3) to deploy this chart in `vault` namespace.
```
$ helm install my-vault ./hcl-commerce-vaultconsul -f my-values.yaml -n vault
```

Note: `my-vault` is the release name, and `./hcl-commerce-vaultconsul` is the local path to the chart, and `vault` is the namespace where this chart deploys to.

Once vault is deployed, run "kubectl get pods -n vault" to make sure vault-xxxx has 2/2 in READY column

Also list the secret in your commerce namespace to make sure the secret has been created.
```
$ kubectl get secret vault-token-secret -n commerce
NAME                 TYPE     DATA   AGE
vault-token-secret   Opaque   1      7m44s
```

## Upgrade the deployment
When you need to update vault values, you can update configuration values in `vaultData`, and then re-deploy vault using a command similar to following
```
helm upgrade my-vault ./hcl-commerce-vaultconsul -f my-values.yaml -n vault
```

Note if you choose to enable `vaultLoadDataWithSecret` to load data, then you can use the following way to update vault values (You can ignore this if you are not using `vaultLoadDataWithSecret` to load data):
1. Update the data secret and then delete the existed vault pod to force a restart to update the vault values.

## Uninstalling the Chart
```
$ helm delete my-vault -n vault
```
## Documentation
* [Learn more about Vault](https://www.vaultproject.io/)
* [Learm more about PKI in Vault](https://www.vaultproject.io/docs/secrets/pki/index.html)
* [Learn more about Key-Value management in Vault](https://www.vaultproject.io/docs/secrets/kv/index.html)
* [How to setup Vault/Consul HA](https://www.vaultproject.io/guides/operations/vault-ha-consul.html)
