# Vault Agent with Kubernetes Walkthrough

## Summary

Learn Kubernetes and Vault integration by using the Kubernetes auth method to authenticate clients using a Kubernetes Service Account Token, use a read-only Vault policy to access secrets, and then having Vault Agent manage the lifecycle of the Vault tokens.

[HashiCorp Source](https://learn.hashicorp.com/vault/identity-access-management/vault-agent-k8s)

## Vault Agent Overview

![diagram](/use-cases/vault-agent-kubernetes/images/overview-vault-agent.png)

# Lab Environment

Running on local VMware ESXi environment managed with the community [Terraform ESXi provider](https://github.com/josenk/terraform-provider-esxi)...I wrote a [walkthrough here](https://github.com/raygj/terraform-content/blob/master/esxi/terraform%20esxi%20provider%20walkthrough.md). The [HashiCorp Vault Guides Repo](https://github.com/hashicorp/vault-guides/tree/master/identity/vault-agent-k8s-demo) contains Terraform configs and info to run on AKS or GKE.

![diagram](/use-cases/vault-agent-kubernetes/images/vault-agent-k8s-lab.png)

# Bootstrap Environment

Ubuntu VM running minikube
Vault server, with KV store mounted at `/secret`


## Ubuntu Minikube Host

Ubuntu 18.04.3 LTS
6G  RAM
8  vCPU
16G HDD (do not try to run on SATA HDD, SSD is a requirement)

### Install Minikube

Minikube is a single-node Kubernetes cluster that functions as a sandbox for dev, ops, or integration testing.

_minikube can be install as a part of the manual Ubuntu installation, this guide assumes that was the case and it must be install post deployment_

The [official guide](https://kubernetes.io/docs/tasks/tools/install-minikube/) walks you through prerequisites for your environment such using a hypervisor (virtualbox, vmwarefusion, kvm2, etc.) or using Docker.

1. Check if minikube is already installed

`minikube start`

if you receive the error "Command `minikube` not found...", then you are ready to proceed ;-)

2. Check if Docker is installed, if not install it

if `sudo systemctl status docker` returns 'unit docker.service could not be found.", then:

`sudo apt install docker.io -y`

and go to the next step.

**NOTE** on snap-installed Docker:

if Docker was installed via snap, then you may encounter a buggy situation where minikube cannot use a snap-installed version of Docker. in which case, remove the snap-installed version of Docker and install via apt in Step 3.

`sudo snap remove docker`

return to Step 2

3. Minikube installation

```

cd /usr/local/bin

sudo curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_1.4.0.deb \
 && sudo dpkg -i minikube_1.4.0.deb

```

4. hypervisor setup

run this command:

`egrep -q 'vmx|svm' /proc/cpuinfo && echo yes || echo no`

if the output is "no," then you need to configure minikube to use the proper vm driver when starting Minikube, go to step 5.



5. Start Minikube

this command assumes you are starting Minikube without a vm-driver (treats your VM as a bare metal environment rather than using a VM inside VM environment). If this scenario does not match your environment, see the [install guide](https://minikube.sigs.k8s.io/docs/start/linux/) for more info.

`sudo minikube start --vm-driver=none`

assuming minikube starts OK, then you can set "none" as your default vm-driver:

`sudo minikube config set vm-driver none`

for this setting to take effect, you must stop minikube...delete the existing cluster...then start a new cluster, but this time you can just use:

`sudo minikube start`

Examples of using minikube [here](https://minikube.sigs.k8s.io/docs/examples/)

- stop minikube: `sudo minikube stop`
- delete cluster: `sudo minikube delete`

6. Install kubectl

kubectl is the Kubernetes command-line tool used to config and manage Kubernetes, it must be installed [separately](https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-on-linux).

```

cd /usr/local/bin

sudo curl -LO https://storage.googleapis.com/kubernetes-release/release/` \
curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl

sudo chmod +x ./kubectl

```

test to make sure kubectl is operational:

`sudo kubectl version`


# Vault Bootstraping

You can follow the [Vault Getting Start Guide](https://learn.hashicorp.com/vault/getting-started/install) to standup an instance of Vault or use [Terraform to deploy Vault on AWS](https://github.com/raygj/vault-content/tree/master/vault-aws-demo-instance)...tons of options, all of which will work for this walkthrough assuming your Minikube environment can talk to Vault.

In my case, I have an existing Vault cluster running locally that I will be using.

The other prerequisite is that the KV secret engine is mounted at `secret/` this is not a hard requirement, but would require all subsequent commands to reflect the actual mount point, if you do not use this default.

## Setup KV Engine

the guide would like secrets engine KV version 1, to make sure this is setup correctly execute the following:

```

vault secrets disable secret

vault secrets enable -path=secret -version=1 kv

```

# Configure Kubernetes, Vault, and then Test

## Download Demo Assets and Set Working Directory

```

cd ~/.

git clone https://github.com/hashicorp/vault-guides.git

cd ~/vault-guides/identity/vault-agent-k8s-demo

```


## Prepare Service Account

In Kubernetes, a service account provides an identity for processes that run in a Pod. A dedicated Service Account will be created to be used by Vault (this is a privileged user like any other Vault secret engine configuration).

See the provided `vault-auth-service-account.yml` file for the service account definition to be used for this guide:

`cat vault-auth-service-account.yml`

1. create service account

`sudo kubectl create serviceaccount vault-auth`

2. update the vault-auth service account with the service account definition `vault-auth-service-account.yml`

`sudo kubectl apply --filename vault-auth-service-account.yml`

# Configure Vault

1. Create Policy

```

tee myapp-kv-ro.hcl <<EOF
# If working with K/V v1
path "secret/*" {
    capabilities = ["read", "list"]
}
EOF

```

2. Apply Policy

`vault policy write myapp-kv-ro myapp-kv-ro.hcl`

3. Create a Secret

```

vault kv put secret/myapp/config username='appuser' \
        password='suP3rsec(et!' \
        ttl='30s'
        
```

4. Create a Test Read-Only User

this is a Vault user account that will use to test the policy you just created

- enable userpass auth method

`vault auth enable userpass`

- create a user name "test-user" bound to myapp-kv-ro policy

```

vault write auth/userpass/users/test-user \
        password=training \
        policies=myapp-kv-ro

```

5. Test Read-Only User

open another terminal session to the Vault server or use the UI to test the user's access...before proceeding

6. Set Environment Variables on Vault Server

if your minikube and Vault VM are the same, then you can use the referenced in the [official guide](https://learn.hashicorp.com/vault/identity-access-management/vault-agent-k8s#step-2-configure-kubernetes-auth-method) which sets environment variables from the output of each `kubectl` command. then go to the next section to Configure Vault Auth Method.

if your minikube and Vault VM are not colocated, go to step 7

7. Collect info required to configure Vault auth method

go through each section on the minikube VM and collect output of the commands into a text file

- collect the service account token for the vault-auth service account created earlier (save this off in a text file as you'll need it in the Test section)

`sudo kubectl get sa vault-auth -o jsonpath="{.secrets[*]['name']}"`

then, set an environment variable so you can call this value in the next couple of commands:

`export VAULT_SA_NAME=$"< insert your service account token value >"`

- collect the JWT token value associated with the vault-auth service account, this is used to access the TokenReview API

`sudo kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo`

- collect the PEM encoded CA cert used to talk to Kubernetes API

`sudo kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo`

- collect the private IP address of the minikube VM accessible by the Vault server (Vault will hit the 

`ip addr`

## Configure Vault Auth Method

back on the Vault server, and using the data you collect in Step 7 of the previous section you will now configure Vault

1. export the value JWT and cert you collect in Step 7 (there may be more elegant ways of doing this, but done is better than perfect)

**note** the JWT is like any other auth token, treat is as a secret and do not leave in a text file on the server or post it to GitHub along with your cluster IP address ;-)

```

cd /tmp


export SA_JWT_TOKEN=$"< your really long JWT string>"

export SA_CA_CRT=$"< your cert in PEM format >"

export K8S_HOST=$"< ip addr of minikube host >"

```

for example:

`export SA_JWT_TOKEN=$"eyJhbGciOiJSUzI1NiIsImtpZCI6IncwNndTQk1rcld0Sjg2MzVfQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6InZhdWx0LWF1dGgtdG9rZW4tNTZ0bHciLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC5uYW1lIjoidmF1bHQtYXV0aCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6IjUzY2RjM2Y1LWViNGUtNDA4MS04ZDEzLTRhMmM1MDc4OTcxYyIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDpkZWZhdWx0OnZhdWx0LWF1dGgifQ.7d5dOmNzqhvb2lBuiE5f0tX7rLOYPMmbX_24zT6ydJc5aDoJSFxrzY5ds0SdZG8e8osbJSyXmEcp-Np7BqgRWxoi0p2JOOeJHJBFTeVqxtZmC7BCQMm8V3qbTj571pcXRxInRaWYxrZFg9GyM5cv4tVpRnJ4vtemQwhiEL12sWpinmFMbpfT8CXGRX7Eb6qfXW_nGEfEHKfa6E3aP6CpQXReer26GLoMAzx8Bj7E5iiaXH-m5pGS0X6EI1EsMkDkqeyWY4OoPtTzPzhPudc69--hrz_TW6gFGly8gtl4F9e7XUT1ghRmLdtWGm3yU2FmGIIyw-44bc6pxQ2ciQP7QQ"`

```

export SA_CA_CRT=$"-----BEGIN CERTIFICATE-----
MIIC5zCCAc+gAwIBAgIBATANBgkqhkiG9w0BAQsFADAVMRMwEQYDVQQDEwptaW5p
a3ViZUNBMB4XDTE5MDkyODAxMjI1N1oXDTI5MDkyNjAxMjI1N1owFTETMBEGA1UE
AxMKbWluaWt1YmVDQTCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAONr
d5J1ChVfTbLAFvChashicorprocks!!!//BU8BzqNrgoH1udexin/4vbKLauF7k+
OqiYBZ6CyaXYxQ+MBv1+ZZ6SD4e03kSsKjf6Q4113P39KeT4dT0ya6h8OFg/Qxw0
VbMjFxh2y93RD3CbwjrZf78ml+RS2MslKy2fX2T3joGC+NRoN7mpFNGgxUhgMb2r
ZYFnyMH1VrMHu/kAq1gMF/Rd+P1sDT1StmeLHumhKplWeETKooC1/S+q2e6q4bH5
Ztt9lh6salt9XDxYcc7qewrwerwerwerwererrrddr2FLA3OtTXIYdDJcPV+hmd9
m+J0CAQsEz5ZzJwPy/cCAwEAAaNCMEAwDgYDVR0PAQH/BAQDAgKkMB0GA1UdJQQW
MBQGCCsGAQUFBwMCBggrBgEFBQcDATAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3
DQEBCwUAA4IBAQDYGc55t9SW13ppW7CzDov6km2CsZ69/88ZNu7HbGMj7XF9OBbL
q+ZPDN6X0lzWXnz+Xu9snrhrC+M3GbIlCgfXrZFdA8B68SIRpeEDqZX0l5GGBbEk
VWZ+J+w37/t8ymesvbyHGx8iWZUq0u/23jTD5WcaYicXyHatY9Y8e31gdAhmqauA
4zYmwGZ48aZraKvfPnZMapbPMTIMiEeeKYI2Sgz2x5tB3UUDGDZXe+A9Y4UveJhE
wjoZbcflGWuH1O+GtL9UKKG9ofTTAjF79wWzYN5ZHCnDVCm+lXJaSwc/0HlP1LCn
3p3pqiapO67H4k0a0SrvnWBOuzjWxITlFN4q
-----END CERTIFICATE-----"

```

```

export K8S_HOST=$"192.168.1.205"

```

2. enable the Kubernetes auth method at the default path ("auth/kubernetes")

`vault auth enable kubernetes`

3. tell Vault how to communicate with the Kubernetes (Minikube) cluster

```

vault write auth/kubernetes/config \
        token_reviewer_jwt="$SA_JWT_TOKEN" \
        kubernetes_host="https://$K8S_HOST:8443" \
        kubernetes_ca_cert="$SA_CA_CERT"

```

use this command to validate the settings:

`vault read auth/kubernetes/config`

if all values look OK, then move on

4. Create a role named, 'example' to map Kubernetes Service Account to Vault policies and default token TTL

```

vault write auth/kubernetes/role/example \
        bound_service_account_names=vault-auth \
        bound_service_account_namespaces=default \
        policies=myapp-kv-ro \
        ttl=24h

```

## Test

1. use alpine to test connectivity and auth, start the container as such:

`sudo kubectl run --generator=run-pod/v1 tmp --rm -i --tty --serviceaccount=vault-auth --image alpine:3.7`

2. once the container is started you will see a `/#` command prompt, install cURL and jq tools:

```

apk update

apk add curl jq

```
 
3. set environment variable for VAULT_ADDR:

`VAULT_ADDR=http://< IP of your Vault server or localhost >:8200`

4. use the /sys/health endpoint to test the connection:

`curl -s $VAULT_ADDR/v1/sys/health | jq`

5. set environment variable for KUBE_TOKEN to the service token value collected in the last section or collect it again:

collect service token value:

`sudo kubectl get sa vault-auth -o jsonpath="{.secrets[*]['name']}"`

set environment variable:

`KUBE_TOKEN=$(cat /var/run/secrets/kubernetes.io/serviceaccount/token)`

verify it was set:

`echo $KUBE_TOKEN`

6. now, authenticate against Vault

```

curl --request POST \
        --data '{"jwt": "'"$KUBE_TOKEN"'", "role": "example"}' \
        $VAULT_ADDR/v1/auth/kubernetes/login | jq

```

Success, should look like this:

```
"request_id": "74b1a4e5-12e7-f761-8301-dea8782606f4",
"lease_id": "",
"renewable": false,
"lease_duration": 0,
"data": null,
"wrap_info": null,
"warnings": null1,
"auth": {
"client_token": "s.g9AVD1WzYILqCbBGwdpbJASc",
"accessor": "fIMeYG3bxzWThe875XtuH4jP",
"policies": [
 "default",
 "myapp-kv-ro"-
],
"token_policies": [
 "default",
 "myapp-kv-ro"
],
"metadata": {
 "role": "example",
 "service_account_name": "vault-auth",
 "service_account_namespace": "default",
 "service_account_secret_name": "vault-auth-token-56tlw",
 "service_account_uid": "53cdc3f5-eb4e-4081-8d13-4a2c5078971c"
},
"lease_duration": 86400,
"renewable": true,
"entity_id": "27fd1a66-3ab5-1630-03e2-914ad9ebc734",
"token_type": "service",
"orphan": true

```

values such as policies, role, service_account_name, and service_account_secret_name should all look familiar.

exit out of the alpine environment and continue

`exit`

# Vault Agent Auto-Auth with Consul Template

Now that you have verified that the Kubernetes auth method has been configured on the Vault server, it is time to spin up a client Pod which leverages Vault Agent to automatically authenticate with Vault and retrieve a client token.

For info on Vault Agent, [view the docs](https://www.vaultproject.io/docs/agent/index.html)or check out this [demo walkthrough](https://github.com/raygj/vault-content/blob/master/use-cases/vault-agent-auto-auth/vault_agent_auto-auth.md)

For info on Consul Template, [view this guide](https://learn.hashicorp.com/vault/developer/sm-app-integration)

1. browse to the demo assets and view the Vault Agent configuration

`more ~/vault-guides/identity/vault-agent-k8s-demo/configs-k8s/vault-agent-config.hcl`

take note of the `auto_auth` method and role being used...also, the sink path

2. view the Consul Template configuration

`more ~/vault-guides/identity/vault-agent-k8s-demo/configs-k8s/consul-template-config.hcl`

3. create a config map

In Kubernetes, ConfigMaps allow you to decouple configuration artifacts from image content to keep containerized applications portable. 

- create a ConfigMap named, `example-vault-agent-config` pulling files from `configs-k8s` directory.

`cd ~/vault-guides/identity/vault-agent-k8s-demo/`

`sudo kubectl create configmap example-vault-agent-config --from-file=./configs-k8s/`

- view the created ConfigMap

`sudo kubectl get configmap example-vault-agent-config -o yaml`


