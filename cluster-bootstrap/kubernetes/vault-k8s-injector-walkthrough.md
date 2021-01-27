# Vault Kubernetes Auth and Sidecar Injector Walkthrough

_bulding off the previous K8S auth method configuration and testing, use Vault Agent Injector pod as an intermediary between Vault server and a consuming service in another pod that will have no knowledge of Vault_

[reference](https://learn.hashicorp.com/tutorials/vault/kubernetes-sidecar?in=vault/kubernetes)

**notes**

- the default injector definition in the Helm chart grants access to all namespaces by default
  - use the `injector.namespaceSelector.matchLabels.injection:"enabled"` attribute to match namespaces with the tab **injection**
- in an injector-only config, the Service Account can be automatically created
- this walkthrough assumes Vault, the Injector, and workload are in the same Namespace for simplicity

## 1. Configure Kubernetes

### 1a: service accounts

1. define a unique service account `internal-app` that was used for the app deployments

```
cat << EOF > ./service-account-internal-app.yml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: int-app-sa
  labels:
    app: internal-app
EOF
```

1b. apply the definition to create the account

`kubectl -n vault apply --filename ./service-account-internal-app.yml`

2. if it does not already exist, create a service account to be used to bind Vault and Kubernetes with the role-tokenreview-binding that will allow this SA to validate other SAs (JWTs) that are used to auth to Vault

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
  namespace: vault //update to reflect the namespace where Vault was deployed
EOF
```

**notes**

- ClusterRoleBinding is cluster-wide and does not respect namespaces, so one SA with this role is sufficient per cluster.
- each app or client container/pod can be deployed in the same or a different namespace, each app deployment will have a distinct SA asssigned and tagged to that app, that SA role is basic and does not need special privileges

2a. create the Token Review SA

`kubectl -n vault apply --filename service-account-vault-auth.yml
`
- success

`clusterrolebinding.rbac.authorization.k8s.io/role-tokenreview-binding configured`

- verify

`kubectl -n vault get serviceaccounts`

## 2. Prepare Vault

0. ensure connectivity between a vault client host or the access vault directly through an exec session

`curl http://localhost:8200/healthz`

- status `* Connected to localhost (127.0.0.1) port 8200 (#0)`

- connectivity
  - terminal 2: `kubectl -n vault  port-forward vault-0 8200:8200`
  - terminal 1:

```
export VAULT_ADDR=http://localhost:8200

vault login s.2qKJYnV8mAczIuDgcF2B8Vsd

```

- or exec: `kubectl -n vault exec -it vault-0 -- /bin/sh`

1. setup Vault demo data

```
vault secrets enable -path=injector-demo kv

vault kv put injector-demo/secret vault=rocks
```

- verify

vault kv get injector-demo/secret

1a. create a Vault policy for this auth role

```
vault policy write int-app-ro - <<EOF
path "injector-demo/secret" {
  capabilities = ["read"]
}
EOF
```

- verify

`vault policy list`

`vault policy read int-app-ro`

#### 2a. K8S configurations

1. set the SA_JWT_TOKEN environment variable value to the service account JWT used to access the TokenReview API **note** update `-n` to the target namespace

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

- use kubectl to grab cluster address

`kubectl config view --minify | grep server | cut -f 2- -d ":" | tr -d " "`

`export K8S_HOST=$kubectl config view --minify | grep server | cut -f 2- -d ":" | tr -d " "`

2. enable and mount k8s auth engine on a different mount point

`vault auth enable -path=k8s_injector kubernetes`

3. Vault configuration pulling in details from the env vars we just set

```
vault write auth/k8s_injector/config \
token_reviewer_jwt="$SA_JWT_TOKEN" \
kubernetes_host="https://$K8S_HOST:8443" \
kubernetes_ca_cert="$SA_CA_CRT"
```

- success

`Success! Data written to: auth/k8s_injector/config`

- view config

`vault read auth/k8s_injector/config`

- example

```
Key                       Value
---                       -----
disable_iss_validation    false
disable_local_ca_jwt      false
issuer                    n/a
kubernetes_ca_cert        -----BEGIN CERTIFICATE-----
MIIDBjCCAe6gAwIBAgIBATANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDEwptaW5p
+Vj8YB6Funyg7IQW0vfqYCEkndnGMGd7a6n52X6/YtClu+rSNre8RcJ7bWyEMZ0T
xE4f/d3XHv9Fqg==
-----END CERTIFICATE-----
kubernetes_host           https://192.168.1.234:8443
pem_keys                  []
```

4. create an auth role binding the service account of the **app** deployment, K8S namespace, and Vault policy

```
vault write auth/k8s_injector/role/int-app-v_role \
    bound_service_account_names=int-app-sa \
    bound_service_account_namespaces=vault \
    policies=int-app-ro \
    ttl=24h
```
- view config

`vault read auth/k8s_injector/role/int-app-v_role`


**note** the role defined here in Vault `int-app-v_role` is used when defining the Vault annotations of the Injector "patch" file listed below

4a. exit exec shell/move on

## 3. deploy demo app and test

1. create the sample app definition

```
cat << EOF > ./deployment-dev-fin-srv-app.yml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dev-fin-service
  labels:
    app: vault-inject-secrets-demo
spec:
  selector:
    matchLabels:
      app: vault-inject-secrets-demo
  replicas: 1
  template:
    metadata:
      annotations:
      labels:
        app: vault-inject-secrets-demo
    spec:
      shareProcessNamespace: true
      serviceAccountName: int-app-sa
      containers:
        - name: app
          image: jweissig/app:0.0.1
          env:
          - name: APP_SECRET_PATH
            value: "/vault/secrets/database-config.txt"
          - name: VAULT_ADDR
            value: "http://172.17.0.3:8200"
EOF
```

alternative image: paulbouwer/hello-kubernetes:1.8

**notes**
- `shareProcessNamespace` [cross-NS support, see docs](https://kubernetes.io/docs/tasks/configure-pod-container/share-process-namespace/) can be used to inject secrets across NS or to attach a troubleshooting container
- `serviceAccountName` as defined in step 0 of the Kubernetes > Service Account section above
- `VAULT_ADDR` is a K8S service director/gw/loadbalancer that is accessible from containers in the target pod; this var can be referenced in the pod, but more importantly for the Injector workflow is the use of the
- `APP_SECRET_PATH` is a target path where secret "database-config.txt" will be written by the Vault Agent Injector; there is a corresponding annotation in the ``


2. deploy the sample app

`kubectl -n vault apply --filename ./deployment-dev-fin-srv-app.yml`

- validate

`kubectl -n vault get pods`

- success

```
kubectl -n vault get pods
NAME                                    READY   STATUS    RESTARTS   AGE
dev-fin-service-85d9769869-55lvh        1/1     Running   0          14s
vault-0                                 1/1     Running   0          9h
vault-1                                 1/1     Running   0          9h
vault-2                                 1/1     Running   0          9h
vault-agent-injector-685f8f78db-rgntg   1/1     Running   0          9h
```

2a. if there is a problem, delete the deployment

`kubectl -n vault delete deployment dev-fin-service`

3. verify there are no secrets in the newly created pod

_The Vault-Agent injector looks for deployments that define specific annotations. None of these annotations exist within the current deployment. This means that no secrets are present on the "dev-fin-service" container within the "app" pod._

`kubectl -n vault describe pods dev-fin-service`

- note the environment variables that were set
- note the k8s secret mount specifying the SA name defined by the deployment and bound to the Vault role:

`serviceaccount from int-app-sa-token-.... (ro)`

- this command is supposed to read the value at /vault/secrets in the newly created container. it is not working at the moment.
```
kubectl -n vault exec \
    $(kubectl -n vault get pod -l app=dev-fin-service -o jsonpath="{.items[0].metadata.name}") \
    --container app -- ls /vault/secrets
```

kubectl exec \
    $(kubectl get pod -l app=app -o jsonpath="{.items[0].metadata.name}") \
    --container dev-fin-service -- ls /vault/secrets

- success/expected output

```
ls: /vault/secrets: No such file or directory
command terminated with exit code 1
```
3a. workaround

get the conainter name from "get pods" and exec in

`kubectl -n vault exec -it dev-fin-service-7fb57ccbfb-ptxb9 -- /bin/sh`

`ls /vault/secrets`

- expected output

```
/app # ls /vault/secrets
ls: /vault/secrets: No such file or directory
```

- while we are here, try pinging the value set in the env var `VAULT_ADDR` within the app deployment spec

```
/app # echo $VAULT_ADDR
http://192.168.1.234:8200

/app #  ping 192.168.1.234
PING 192.168.1.234 (192.168.1.234): 56 data bytes
64 bytes from 192.168.1.234: seq=0 ttl=64 time=0.059 ms
64 bytes from 192.168.1.234: seq=1 ttl=64 time=0.096 ms
```

- exit and move on

4. inject secrets into the pod

[reference with detailed explanation of annotations](https://learn.hashicorp.com/tutorials/vault/kubernetes-sidecar?in=vault/kubernetes#inject-secrets-into-the-pod)

4a. create an updated sample app spec that includes the injector annotations (demonstrate migrating an existing pod to the injector workflow)

```
cat << EOF > ./patch-deployment-dev-fin-srv-app.yml
---
spec:
  template:
    metadata:
      annotations:
        # AGENT INJECTOR SETTINGS
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/agent-inject-secret-database-config.txt: "injector-demo/secret"
        vault.hashicorp.com/role: "int-app-v_role"
        vault.hashicorp.com/auth-path: "auth/k8s_injector"
        vault.hashicorp.com/log-level: "debug"
EOF
```

**notes**

- include the annotation `vault.hashicorp.com/auth-path: "auth/k8s_injector"` if you mounted your Kubernetes auth method to a custom path; by default the injector will look to `auth/kubernetes`
- include the annotation `vault.hashicorp.com/agent-inject-status: "update"` and patch the deployment to trigger a re-injection of values; helpful when including templating
- this configuration tells the injector service to retrieve the KV `config` secret from ` internal/data/database/config`, write it to `database-config`, bound to the Vault role `internal-app` that we created om the Vault server
- agent-inject-secret-FILEPATH prefixes the path of the file, database-config.txt written to the /vault/secrets directory on the container. The value is the path to the secret defined in Vault, which should match the KV path we have used in this walkthrough
- the annotation `vault.hashicorp.com/log-level` defaults to `info` logs can be viewed by access target pod and either `vault-agent-init` if there is an init problem or `vault-agent` if init completes and you need to troubleshoot the app container

4b. patch the existing deployment of the sample app

`kubectl -n vault patch deployment dev-fin-service --patch "$(cat ./patch-deployment-dev-fin-srv-app.yml)"`

_A new pod starts alongside the existing pod. When the init is complete, the original terminates and removes itself from the list of active pods._

5. verify

`kubectl -n vault get pods`

```
kubectl -n vault get pods
NAME                                    READY   STATUS     RESTARTS   AGE
dev-fin-service-7d558997f8-s5c8b        0/2     Init:0/1   0          16s
dev-fin-service-d555555db-7ghtv         1/1     Running    0          6m34s
vault-0                                 1/1     Running    0          10h
vault-1                                 1/1     Running    0          10h
vault-2                                 1/1     Running    0          10h
vault-agent-injector-685f8f78db-rgntg   1/1     Running    0          10h

```
if the init process does not complete, start troubleshooting there with a focus on connectivity to vault and logs from the init container - look for values being set by the injector that may be wrong or contain a typo




5a. check pod details

`kubectl -n vault describe pods dev-fin-service`

- note the available mounts

```
    Mounts:
      /home/vault from home-sidecar (rw)
      /var/run/secrets/kubernetes.io/serviceaccount from int-app-sa-token-9822g (ro)
      /vault/secrets from vault-secrets (rw)
```
**note** if the patched deployment and secret injection completes, the original container should be removed

5a. display the logs of the `vault-agent` container (that exists after the init completes) in the new `dev-fin-service` pod

```
kubectl -n vault logs \
    $(kubectl -n vault get pod -l app=dev-fin-service -o jsonpath="{.items[0].metadata.name}") \
    --container vault-agent
```

5b. display the secret written to `dev-fin-service` container

`kubectl -n vault exec -it dev-fin-service-7457f8489d-62xlm -- /bin/sh`

`cat /vault/secrets/database-config.txt`

6. Vault Agent Injector Examples

https://www.vaultproject.io/docs/platform/k8s/injector/examples

## Troubleshooting

### init failures, proving the components of the workflow

1. assuming your init is failing, exec into an "unpatched" pod

`kubectl -n vault exec -it dev-fin-service-7457f8489d-62xlm -- /bin/sh`

2. install test tools to an Alpine or other compatible image

```
apk update
apk add curl jq
```

3. validate connectivity to Vault based on the environment (K8S service selector, Consul service sync, etc.)

- get active services

`kubectl -n vault get services`

```
NAME                       TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)             AGE
vault                      ClusterIP   10.103.16.9     <none>        8200/TCP,8201/TCP   23h
vault-active               ClusterIP   10.103.56.118   <none>        8200/TCP,8201/TCP   23h
vault-agent-injector-svc   ClusterIP   10.105.73.132   <none>        443/TCP             23h
vault-internal             ClusterIP   None            <none>        8200/TCP,8201/TCP   23h
vault-standby              ClusterIP   10.110.161.71   <none>        8200/TCP,8201/TCP   23h
```

- curl to Vault's unauthenticated "status" endpoint via K8S service discovery

`export VAULT_ADDR=http://vault-internal:8200`

`curl $VAULT_ADDR/v1/sys/seal-status | jq`


### test K8S auth from an "unpatched" app container or VM outside of K8S

- fetch the SA JWT token for the SA bound to the "app" pod

`export JWT=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)`

- convert the above into curl commands; update Vault role and auth path

`curl --request POST --data "{\"jwt\": \"$JWT\", \"role\": \"< vault role >\"}" -s -k $VAULT_ADDR/v1/auth/< mount point >/login | jq`

  - example

`curl --request POST --data "{\"jwt\": \"$JWT\", \"role\": \"int-app-v_role\"}" -s -k $VAULT_ADDR/v1/auth/k8s_injector/login | jq`

- read the KV path

```
curl \
--header "X-Vault-Token: $VAULT_TOKEN" \
$VAULT_ADDR/v1/injector-demo/secret | jq
```

### test from a VM outside of K8S

_assumes Vault binary is available and in the path_

- fetch the JWT of the SA bound to the **application** container (to ensure we are grabbing the right SA JWT!)

`cat /var/run/secrets/kubernetes.io/serviceaccount/token`

- or fetch it from the controller

1. `kubectl -n vault describe serviceaccount int-app-sa`

```
Name:                int-app-sa
Namespace:           vault
Labels:              app=internal-app
Annotations:         <none>
Image pull secrets:  <none>
Mountable secrets:   int-app-sa-token-9822g
Tokens:              int-app-sa-token-9822g
Events:              <none>
```

2. `kubectl -n vault get secret int-app-sa-token-9822g  -o jsonpath='{.data.token}'`

```
ZXlKaGJHY2lPaUpTVXpJ...lEclhmUXllNU5B
```

3. `kubectl -n vault get secret int-app-sa-token-9822g -o jsonpath='{.data.token}' | base64 --decode`

_ output is Base64-encoded, so just pipe the output_

```
eyJhbGciOiJSUzI1NiIsImtp...v6xweFV9DrXfQye5NA
```

- set an env vars

`export JWT=< token >`

`export VAULT_ADDR=`

`vault status`

- test auth

`vault write auth/k8s_injector/login role=int-app-v_role jwt=$JWT`

- test access to KV using token from successful K8S auth

`export VAULT_TOKEN=`

`vault kv get injector-demo/secret`

### Vault Specific

- validate key configuration items where `auth/kubernetes` is the mount point of your K8S auth method

```
vault read auth/kubernetes/config

vault list auth/kubernetes/role

vault read auth/kubernetes/role/internal-app
```

### K8S Specific

- exec into the vault-agent-init container to troubleshoot connectivity to the vault address, etc.

`kubectl -n vault exec -ti dev-fin-service-548956c846-2hbjd -c vault-agent-init  -- /bin/sh`

- pull logs from vault init container

`kubectl -n vault logs dev-fin-service-8dbd868d8-42kzg -c vault-agent-init  --tail 1 --follow`

- sample output with errors:

```
URL: PUT http://vault.vault.svc:8200/v1/auth/kubernetes/login
Code: 400. Errors:

* invalid role name "int-app-v_role"" backoff=1.88824477
2021-01-26T16:57:54.896Z [INFO]  auth.handler: authenticating
2021-01-26T16:57:54.900Z [ERROR] auth.handler: error authenticating: error="Error making API request.

URL: PUT http://vault.vault.svc:8200/v1/auth/kubernetes/login
```

**note** the resolution to this error was a bit of a red herring; the role name was actually correct, the Vault URL is correct (relying on K8S service discovery), the actual issue was the auth path; the method was not mounted on the default /auth/kubernetes path, but on /auth/k8s-injector (vault injector annotation value `vault.hashicorp.com/auth-path: "auth/k8s_injector"`)

### app deployment that includes injector annotations

_no patch deployment step required_

```
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: dev-fin-service
  labels:
    app: vault-inject-secrets-demo
spec:
  selector:
    matchLabels:
      app: vault-inject-secrets-demo
  replicas: 1
  template:
    metadata:
      annotations:
        # AGENT INJECTOR SETTINGS
        vault.hashicorp.com/agent-inject: "true"
        vault.hashicorp.com/agent-inject-secret-database-config.txt: "injector-demo/secret"
        vault.hashicorp.com/role: "int-app-v_role"
        vault.hashicorp.com/auth-path: "auth/k8s_injector"
        vault.hashicorp.com/log-level: "debug"
      labels:
        app: vault-inject-secrets-demo
    spec:
      shareProcessNamespace: true
      serviceAccountName: int-app-sa
      containers:
        - name: app
          image: jweissig/app:0.0.1
          env:
          - name: APP_SECRET_PATH
            value: "/vault/secrets/database-config.txt"
          - name: VAULT_ADDR
            value: "http://172.17.0.3:8200"
```
