# Vault Kubernetes Scenarios and Walkthroughs
- lab environment: Ubuntu 18.04, minikube 1.17 , helm 3.5.0
- target environment: Vault OSS 3-node Raft cluster, no TLS Walkthrough
- Vault Server and Client co-located on a single cluster, single namespace
- Vault Agent Injector Service with Kubernetes Auth-Authentication and "hello world" service
- [reference](https://www.vaultproject.io/docs/platform/k8s/helm/examples/ha-with-raft)

## prepare Kubernetes

- [minikube ubunut bootstrap](https://github.com/raygj/vault-content/blob/master/cluster-bootstrap/kubernetes/vm_bootstrap.sh)

- check environment

minikube status

- option; create a namespace for Vault resources

kubectl create namespace vault

- add the HashiCorp public helm repo

helm repo add hashicorp https://helm.releases.hashicorp.com

helm repo update

- view Vault versions (helm release vs vault release)

helm search repo vault --versions

## deploy Vault

[documentation with examples and all configuration values](https://www.vaultproject.io/docs/platform/k8s/helm/configuration)
- use Helm `--dry-run` option and verify computed annotations before committing
- use Helm CLI options to name Helm release <vault> and target namespace <vault> must match

0. Any K8S platform; OSS dev mode in default namespace

`helm install vault hashicorp/vault --set "server.dev.enabled=true"`

1. Any K8S platform; default OSS install includes **server and client pods**, enable HA and required Raft storage

```
helm install vault hashicorp/vault \
  --namespace vault \
  --set='server.ha.enabled=true' \
  --set='server.ha.raft.enabled=true'
```

```
helm install --dry-run vault hashicorp/vault \
  --namespace vault \
  --set='server.ha.enabled=true' \
  --set='server.ha.raft.enabled=true'
```

1a. minikube; affinity=null for single node K8S cluster

```
helm install vault hashicorp/vault \
  --namespace vault \
  --set='server.ha.enabled=true' \
  --set='server.ha.raft.enabled=true' \
  --set='server.affinity=null'
```

3. minikube; affinity=null for single node K8S cluster; Enterprise install **server only**, enable HA and required Raft

`kubectl create namespace vault-enterprise`

```
helm install vault-enterprise hashicorp/vault \
  --namespace vault-enterprise \
  --set='server.image.repository=hashicorp/vault-enterprise' \
  --set='server.image.tag=1.6.1_ent' \
  --set='server.ha.enabled=true' \
  --set='server.ha.raft.enabled=true' \
  --set='server.affinity=null' \
  --set='injector.enabled=false'
```

4. minikube; affinity=null for single node K8S cluster **server only**

```
helm install vault hashicorp/vault \
  --namespace vault \
  --set='server.ha.enabled=true' \
  --set='server.ha.raft.enabled=true' \
  --set='server.affinity=null' \
  --set='injector.enabled=false'
```

5. Any K8S (should work on minikube w/o affinity=null) platform; Vault Agent injector only

```
helm install vault hashicorp/vault \
  --namespace vault \
  --set='server.ha.enabled=true' \
  --set='server.ha.raft.enabled=true' \
  --set='injector.enabled=true'
```

5a. Any k8s platform; Vault Agent injector only, creates default SA for identity binding, external Vault server

**WIP** injector options: https://www.vaultproject.io/docs/platform/k8s/helm/configuration#externalvaultaddr

```
helm install vault hashicorp/vault \
  --namespace vault \
  --set='injector.externalVaultAddr="http://some.fqdn.com:8200"'
  --set='injector.server.serviceAccount.create="true"'
  --set='server.affinity=null' \
  --set='injector.enabled=true'
```

**note** setting "externalVaultAddr" disables server deployment and makes this an agent injector only deploy

- check status

kubectl -n vault-enterprise describe pods vault-enterprise-0

- clean up

helm uninstall vault-enterprise -n vault-enterprise

- **WIP**: UI configuration with NodePort to avoid need for port-forward?

```
--set='ui.serviceType=NodePort'
--set='ui.serviceNodePort=192.168.1.xxx:8200'
```

** WIP note**
use "use service entry" in K8S to direct internal and external traffic to Vault?
https://learn.hashicorp.com/tutorials/vault/kubernetes-external-vault?in=vault/kubernetes#deploy-service-and-endpoints-to-address-an-external-vault

_always run Helm with --dry-run before any install or upgrade to verify changes_

### validate deployment

- check the status of the Helm deployment

helm status vault

- view all pods

kubectl -n vault get pods

- check status of node-0 pod

kubectl -n vault describe pods vault-0

### cleanup deployment

helm uninstall vault -n vault

kubectl delete ns vault

## initialize Vault on node-0

`kubectl -n vault exec -ti vault-0 -- vault operator init -key-shares=1 -key-threshold=1`

**note** this is a non-prod approach of using a single key share to ease unsealing operations in a sandbox

- capture unseal key and initial root token

```
Unseal Key 1: 23h2k34...

Initial Root Token: s.YkRyPlFVGuwePKsXgiby78CU
```

### set environment vars

```
export VAULT_UNSEAL_KEY=D3O2vkRWcoEklJ8r8ZfUBLCpy6pC+3FbVEuTPNKMqwM=
export VAULT_TOKEN=s.YkRyPlFVGuwePKsXgiby78CU
```

### unseal vault on node-0

`kubectl -n vault exec -ti vault-0 -- vault operator unseal $VAULT_UNSEAL_KEY`

- at this point you initialized Vault on Node 0 and have the start of a functional cluster, next steps are to join the other two nodes to this one using the `raft join` command and then unseal that node using the same unseal key from Node 0
- depending on your target environment and its resources, spinning up all pods may take 1-5 mins to complete

## join node-1 to node-0, then unseal

`kubectl -n vault exec -ti vault-1 -- vault operator raft join http://vault-0.vault-internal:8200`

- output

```
Key       Value
---       -----
Joined    true
```

`kubectl -n vault exec -ti vault-1 -- vault operator unseal $VAULT_UNSEAL_KEY`

## join node-2 to node-0, then unseal

```
kubectl -n vault exec -ti vault-2 -- vault operator raft join http://vault-0.vault-internal:8200

kubectl -n vault exec -ti vault-2 -- vault operator unseal $VAULT_UNSEAL_KEY
```

## log in to vault on node-0 with default root token

`kubectl -n vault exec -ti vault-0 -- vault login $VAULT_TOKEN`

- verify all 3 nodes are healthy Raft peers

`kubectl -n vault exec -ti vault-0 -- vault operator raft list-peers`

- output

```
Node                                    Address                        State       Voter
----                                    -------                        -----       -----
734ecf5b-eb45-8ca7-9386-3e98cd262a3b    vault-0.vault-internal:8201    leader      true
52eb593d-3c2b-8d2f-6a49-2611c74c2545    vault-1.vault-internal:8201    follower    true
1b86afcf-5c8c-ceec-2b22-75b89ca74ab1    vault-2.vault-internal:8201    follower    true
```

###at this point you should have a functional 3-node Vault cluster

`kubectl -n vault exec -ti vault-0 -- vault status`

```
Key                     Value
---                     -----
Seal Type               shamir
Initialized             true
Sealed                  false
Total Shares            1
Threshold               1
Version                 1.6.1
Storage Type            raft
Cluster Name            vault-cluster-15acc648
Cluster ID              d13a654b-ccbc-d516-0213-67c08bb10e66
HA Enabled              true
HA Cluster              https://vault-0.vault-internal:8201
HA Mode                 active
Raft Committed Index    36
Raft Applied Index      36
```

## apply enterprise license

`kubectl -n vault exec -ti vault-enterprise -- vault login < root token >`

`kubectl -n vault exec -ti -- < primary node > vault write sys/license text=02M...`

## port-forward Vault UI and API traffic

- this forwards traffic from the Vault pod to the localhost, additional forwarding or techniques may be required to reach "public" clients

`kubectl -n vault port-forward < primary pod > 8200:8200`

e.g.,

`kubectl -n vault  port-forward vault-0 8200:8200`

`export VAULT_ADDR=http://localhost:8200`

# Kubernetes Auth Test Cases

## prepare an Ubuntu Vault client

```
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -

sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

sudo apt-get update && sudo apt-get install vault
```

## Kubernetes prep

- create service account used to bind Vault and Kubernetes

`kubectl -n vault create serviceaccount vault-auth`

  - validate

`kubectl -n vault get serviceaccounts`

- create and assign custom policy to the service account

```
cat << EOF > ./service-account-vault-auth.yml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: role-tokenreview-binding
  namespace: default
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:auth-delegator
subjects:
- kind: ServiceAccount
  name: vault-auth
  namespace: default
EOF
```

**notes**

- ClusterRoleBinding is cluster-wide and does not respect namespaces
  - there is a default role, it can be used, or you can create one as described since this SA identity will be incorporated into the Vault configuration
  - tagging the SA the Vault namespace enables tracking of the dependent resources
  - one SA with this role is sufficient per cluster or identity domain

- each app or client container/pod can be deployed in the same or a different namespace, each app deployment will have a distinct SA assigned and tagged to that app, that SA role is basic and does not need special privileges

`kubectl -n vault apply --filename service-account-vault-auth.yml`

- success

`clusterrolebinding.rbac.authorization.k8s.io/role-tokenreview-binding configured`

- verify

`kubectl -n vault describe sa vault-auth`

`kubectl -n vault get serviceaccounts`

## configure K8S auth method

[reference](https://learn.hashicorp.com/tutorials/vault/agent-kubernetes?in=vault/kubernetes#step-1-create-a-service-account)

### prep Vault

_host with access to K8S control plane; requires the ability to execute `kubectl` commands and set environment variables_

0. login with root token or user with sudo and "admin policy"

`vault login < token >`

1. create RO policy to bind to K8S authenticated clients

```
vault policy write myapp-kv-ro - <<EOF
path "secret/*" {
capabilities = ["read", "list"]
}
EOF
```

2. create test data

```
vault secrets enable -path=secret kv

vault kv put secret/data/myapp/config username='appuser' password='suP3rsecret'
```

- validate

`vault kv get secret/data/myapp/config/`

4. set the SA_JWT_TOKEN environment variable value to the service account JWT used to access the TokenReview API **note** update `-n` to the target namespace

```
export VAULT_SA_NAME=$(kubectl -n vault get sa vault-auth \
    -o jsonpath="{.secrets[*]['name']}")
```

5. set the SA_CA_CRT environment variable value to the PEM encoded CA cert used to talk to Kubernetes API **note** update `-n` to the target namespace

```
export SA_CA_CRT=$(kubectl -n vault get secret $VAULT_SA_NAME \
    -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)
```

6. set the K8S_HOST environment variable value to the public IP address of K8S/minikube.

- minikube example; or specify IP address

```
export K8S_HOST=$(minikube ip)

export K8S_HOST=< address that is accessible to Vault nodes >
```

**note** minikube defaults to TCP 8443 for the API server endpoint; non-minikube K8S deployment typically use standard TCP 443 (HTTPS) **note**

### k8s auth config

_prep from a host with access to Vault_

0. login with root token or user with sudo and "admin policy"

`vault login < token >`

1. enable the Kubernetes auth method at the default path ("auth/kubernetes")

`vault auth enable kubernetes`

2. tell Vault how to communicate with the Kubernetes (Minikube) cluster

```
vault write auth/kubernetes/config \
token_reviewer_jwt="$SA_JWT_TOKEN" \
kubernetes_host="https://$K8S_HOST:8443" \
kubernetes_ca_cert="$SA_CA_CRT"
```

3. create a role named, "example" to map Kubernetes Service Account to Vault policies and default token TTL **note** update `bound_service_account_namespaces` to the target ns where Vault is deployed

```
vault write auth/kubernetes/role/example \
bound_service_account_names=vault-auth \
bound_service_account_namespaces=vault \
policies=myapp-kv-ro \
ttl=24h
```

### determine Vault public address

A service bound to all networks on the host (how Vault is deployed by default) is addressable by pods within the cluster by sending requests to the gateway address of the Kubernetes cluster.

1. view pod service information

`kubectl -n vault get service | grep "vault-active"`

- output

```
vault-active               ClusterIP   10.103.56.118     <none>        8200/TCP,8201/TCP   139m
```

2. verify ClusterIP is accessible from the host you are on

`curl -s http://10.103.56.118:8200/v1/sys/seal-status | jq`

- output

```
{
  "type": "shamir",
  "initialized": true,
  "sealed": false,
  "t": 1,
  "n": 1,
  "progress": 0,
  "nonce": "",
  "version": "1.6.1",
...
```

3. set environment variable with public "external" Vault address from the previous step

`set EXTERNAL_VAULT_ADDR="http://10.103.56.118"`

- at this point any client that needs to access Vault on this cluster should use $EXTERNAL_VAULT_ADDR to route requests to the active_node

#### validate k8s auth

1. run Alpine pod and exec into it

```
kubectl -n vault run --generator=run-pod/v1 tmp --rm -i --tty \
      --serviceaccount=vault-auth --image alpine:3.7
```

**note**

2. install test tools

```
apk update
apk add curl jq
```

3. set KUBE_TOEN env var to the serviceaccount token value and EXTERNAL_VAULT_ADDR

```
KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

EXTERNAL_VAULT_ADDR="http://10.103.56.118"
```

4. verify token was set

```
echo $KUBE_TOKEN

echo $EXTERNAL_VAULT_ADDR
```

5. auth to Vault

```
curl --request POST \
--data '{"jwt": "'"$KUBE_TOKEN"'", "role": "example"}' \
$EXTERNAL_VAULT_ADDR/v1/auth/kubernetes/login | jq
```
- success

```
  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
  0     0    0     0    0     0      0      0 --:--:-- --:--:-- --:--:--     0{
  "request_id": "24731572-1598-e91d-9b00-6e67b5837088",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 0,
  "data": null,
  "wrap_info": null,
  "warnings": null,
  "auth": {
    "client_token": "s.r1BMhnesnPl3X0D8irqGfIaU",
    "accessor": "8crwMXGYBg28FR5bEZ0jufgK",
    "policies": [
      "default",
      "myapp-kv-ro"
    ],
    "token_policies": [
      "default",
      "myapp-kv-ro"
    ],
    "metadata": {
      "role": "example",
      "service_account_name": "vault-auth",
      "service_account_namespace": "vault",
```

5a. validate RO access

- auth to Vault and write returned token to an environment variable

```
VAULT_TOKEN=$( curl --request POST \
--data '{"jwt": "'"$KUBE_TOKEN"'", "role": "example"}' \
$EXTERNAL_VAULT_ADDR/v1/auth/kubernetes/login \
| jq -r ".auth.client_token" )
```

echo $VAULT_TOKEN

- read the KV at /secret/...

```
curl \
--header "X-Vault-Token: $VAULT_TOKEN" \
$EXTERNAL_VAULT_ADDR/v1/secret/data/myapp/config | jq
```

- attempt to delete KV at /secret/

```
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request DELETE \
    $EXTERNAL_VAULT_ADDR/v1/secret/data/myapp/config | jq
```

6. `exit` the Alpine session

**status check** at this point we have a functional Vault cluster and K8S auth method configuration bound to a specific ServiceAccount and namespace in the Kubernetes cluster. This configuration can now be leveraged as-is or incorporated into the injector sidecar config with auto-authentication.


#cleanup

this [script](https://github.com/jasonodonnell/vault-agent-demo/blob/master/cleanup.sh) will clear all resources from various namespaces and remove traces of vault-agent-injector

#Troubleshooting

1. Connectivity?
2. Binding SA is valid?
3. Namespace?
4. K8S vs non-K8S server cluster; K8S-based server will have access to env vars and other control plane endpoints
5. Cert and CA are valid? True PKI vs K8S only considerations
6. Helm status commands, K8S status commands
7. Vault audit logs

- if a configuration has been changed or you are unsure of the state of a configuration, delete the pod and it will be rescheduled

kubectl -n vault delete pod < pod name >

- use helm --dry-run to view manifest and check computed values vs user inputs

- pod deployment or status issues root cause is usually a bad Helm configuration value

kubectl describe pods < pod name >

## Connectivity test from a Vault node

- exec into the vault

kubectl -n vault exec -it vault-0 -- /bin/sh

export VAULT_ADDR=http://localhost:8200

apk update
apk add curl jq

_test k8s auth from a Vault node to validate configuration, and eliminate K8S (and other variables) that could impact connectivity...if this works from vault, then test the same from the "app" pod_

- export the token from the POD into a variable

export JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)

or

export JWT=$(kubectl exec -ti < app pod name > -- cat /var/run/secrets/kubernetes.io/serviceaccount/token;echo)

for exmaple:

export JWT=$(kubectl exec -ti webapp-576b786bfb-6cxcm -- cat /var/run/secrets/kubernetes.io/serviceaccount/token;echo)

- create the K8-auth-role for the app-pods. Example role here is "example"

vault write auth/kubernetes/login role=example jwt=$JWT

- test if the role/auth works

curl --request POST --data "{\"jwt\": \"$JWT\", \"role\": \"webapp\"}" -s -k $VAULT_ADDR/v1/auth/< mount point for K8S auth engine>/login

for example:

curl --request POST --data "{\"jwt\": \"$JWT\", \"role\": \"webapp\"}" -s -k $VAULT_ADDR/v1/auth/kubernetes/login

note- we are ignoring the secure connection using "-k" option above


## helm

- view helm releases, per namespace

helm ls --all --short --namespace < namespace >

- view all helm releases, all namespaces

helm ls -A

- delete release in a specific namespace

helm uninstall release_name -n release_namespace

## vault policy

- when testing a restrictive policy it is helpful to have two sessions to the Vault server open, this allows a RW/admin session to configure and validate settings, while logging into Vault in the other terminal as the restricted client.
- in the case of the K8S auth, fetch the `auth.client_token` value from a success auth within the K8S pod and issue a `vault login < token value >` command from that second terminal - you are now logged into Vault with the same authorization policy as the K8S client.
