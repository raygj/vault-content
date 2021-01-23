#Vault Kubernetes Scenarios and Walkthroughs
- lab environment: Ubuntu 18.04, minikube 1.17 , helm 3.5.0
- target environment: Vault OSS 3-node Raft cluster, no TLS Walkthrough
- Vault Server and Client co-located on a single cluster, single namespace
- Vault Agent Injector Service with Kubernetes Auth-Authentication and "hello world" service
- [reference](https://www.vaultproject.io/docs/platform/k8s/helm/examples/ha-with-raft)

##prepare Kubernetes

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

##deploy Vault

- use Helm CLI options to name Helm release <vault>, target namespace <vault>, enable HA and required Raft storage

```
helm install vault hashicorp/vault \
  --namespace vault \
  --set='server.ha.enabled=true' \
  --set='server.ha.raft.enabled=true' \
  --set='affinity=null'
```

- clean up

helm uninstall vault -n vault

- minikube deployment

```
helm install vault hashicorp/vault \
  --namespace vault \
  --set='server.ha.enabled=true' \
  --set='server.ha.raft.enabled=true' \
  --set='server.affinity=null'
```

- clean up

helm uninstall vault -n vault

- minikube enterprise

kubectl create namespace vault-enterprise

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

- check status

kubectl -n vault-enterprise describe pods vault-enterprise-0

- clean up

helm uninstall vault-enterprise -n vault-enterprise

- other tags that may be useful

repository: "hashicorp/vault-enterprise"
tag: "1.6.1_ent"


ui:
  enabled: true
  serviceType: "ClusterIP"
  serviceNodePort: null
  externalPort: 8200

**note** this deploy will include the Vault Agent Injector pod as well, disable with `--set='injector.enabled=false'`

- check the status of the Helm deployment

helm status vault

- check status of node-0 pod

kubectl -n vault describe pods vault-0

##initialize Vault on node-0

kubectl -n vault exec -ti vault-0 -- vault operator init -key-shares=1 -key-threshold=1

**note** this is a non-prod approach of using a single key share to ease unsealing operations in a sandbox

- unseal key and initial root token

```
Unseal Key 1: fjN...

Initial Root Token: s...
```

###unseal vault on node-0

kubectl -n vault exec -ti vault-0 -- vault operator unseal < unseal key 1 >

##join node-1 to node-0, then unseal

kubectl -n vault exec -ti vault-1 -- vault operator raft join http://vault-0.vault-internal:8200

kubectl -n vault exec -ti vault-1 -- vault operator unseal

##join node-2 to node-0, then unseal

kubectl -n vault exec -ti vault-2 -- vault operator raft join http://vault-0.vault-internal:8200

kubectl -n vault exec -ti vault-2 -- vault operator unseal

##log in to vault on node-0 with default root token

kubectl -n vault exec -ti vault-0 -- vault login < root token >

export VAULT_TOKEN= < root token >

- verify all 3 nodes are healthy Raft peers

kubectl -n vault exec -ti vault-0 -- vault operator raft list-peers

###at this point you should have a functional 3-node Vault cluster

kubectl -n vault exec -ti vault-0 -- vault status

##apply enterprise license

kubectl -n vault exec -ti vault-enterprise -- vault login

kubectl -n vault exec -ti -- < primary node > vault write sys/license text=02M...

##port-forward Vault UI and API traffic

kubectl port-forward < primary pod > 8200:8200

#Kubernetes Auth Configuration

pickup here on 1/23

#Troubleshooting

- pod deployment or status issues

kubectl describe pods < pod name >

##helm

- view helm releases, per namespace

helm ls --all --short --namespace < namespace >

- view all helm releases, all namespaces

helm ls -A

- delete release in a specific namespace

helm uninstall release_name -n release_namespace
