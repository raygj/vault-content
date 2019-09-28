# Vault Agent with Kubernetes Walkthrough

## Summary

Learn Kubernetes and Vault integration by using the Kubernetes auth method to authenticate clients using a Kubernetes Service Account Token, and then having Vault Agent manage the lifecycle of the Vault tokens.

[HashiCorp Source](https://learn.hashicorp.com/vault/identity-access-management/vault-agent-k8s)

## Vault Agent Overview

![diagram](/use-cases/vault-agent-kubernetes/images/overview-vault-agent.png)

# Lab Environment

Running on local VMware ESXi environment managed with the community [Terraform ESXi provider](https://github.com/josenk/terraform-provider-esxi)...I wrote a [walkthrough here](https://github.com/raygj/terraform-content/blob/master/esxi/terraform%20esxi%20provider%20walkthrough.md). The [HashiCorp Vault Guides Repo](https://github.com/hashicorp/vault-guides/tree/master/identity/vault-agent-k8s-demo) contains Terraform configs and info to run on AKS or GKE.

![diagram](/use-cases/vault-agent-kubernetes/images/vault-agent-k8s-lab.png)

# Bootstrap Environment

Ubuntu VM running minikube
Vault server, with KV store mounted at `/secret`


## Ubuntu MiniKube Host

Ubuntu 18.04.3 LTS

### Install Minikube

Minikube is a single-node Kubernetes cluster that functions as a sandbox for dev, ops, or integration testing.

_minikube can be install as a part of the manual Ubuntu installation, this guide assumes that was the case and it must be install post deployment_

The [official guide](https://kubernetes.io/docs/tasks/tools/install-minikube/) walks you through prerequisites for your environment such using a hypervisor (virtualbox, vmwarefusion, kvm2, etc.) or using Docker.

1. Check if minikube is already installed

`minikube start`

if you receive the error "Command `minikube` not found...", then you are ready to proceed ;-)

2. Check if Docker is installed, if not install it

if `sudo systemctl status docker` returns 'unit docker.service could not be found.", then:

`sudo apt install docker.io`

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

Examples of using minikube [here](https://minikube.sigs.k8s.io/docs/examples/)

- stop minikube: `sudo minikube stop`
- delete cluster: `sudo minikube delete`

# Vault Bootstraping

You can follow the [Vault Getting Start Guide](https://learn.hashicorp.com/vault/getting-started/install) to standup an instance of Vault or use [Terraform to deploy Vault on AWS](https://github.com/raygj/vault-content/tree/master/vault-aws-demo-instance)...tons of options, all of which will work for this walkthrough assuming your Minikube environment can talk to Vault.

In my case, I have an existing Vault cluster running locally that I will be using.

The other prerequisite is that the KV secret engine is mounted at `secret/` this is not a hard requirement, but would require all subsequent commands to reflect the actual mount point, if you do not use this default.

# Prepare Kubernetes

## Download Demo Assets

```

cd ~/home

git clone https://github.com/hashicorp/vault-guides/tree/master/identity/vault-agent-k8s-demo

