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

_minikube can be install as a part of the manual Ubuntu installation, this guide assumes that was the case and it must be install post deployment_

[official guide](https://kubernetes.io/docs/tasks/tools/install-minikube/)

