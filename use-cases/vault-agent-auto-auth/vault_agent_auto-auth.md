# Secure Introduction Using Vault Agent

Vault Agent can be used with platform integration or trusted orchestrator approaches for Secure Introduction.

## Platform Integration

In the Platform Integration model, Vault trusts the underlying platform (e.g. AliCloud, AWS, Azure, GCP) which assigns a token or cryptographic identity (such as IAM token, signed JWT) to virtual machine, container, or serverless function.

### AWS Example

For example, suppose we have an application running on a virtual machine in AWS EC2. When that instance is started, an IAM token is provided via the machine local metadata URL. That IAM token is provided to Vault, as part of the AWS Auth Method, to login and authenticate the client. Vault uses that token to query the AWS API and verify the token validity and fetch additional metadata about the instance (Account ID, VPC ID, AMI, Region, etc). These properties are used to determine the identity of the client and to distinguish between different roles (e.g. a Web server versus an API server).

## Trusted Orchestrator

In the Trusted Orchestrator model, you have an orchestrator which is already authenticated against Vault with privileged permissions. The orchestrator launches new applications and inject a mechanism they can use to authenticate (e.g. AppRole, PKI cert, token, etc) with Vault.

### Terraform Example

For example, suppose Terraform is being used as a trusted orchestrator. This means Terraform already has a Vault token, with enough capabilities to generate new tokens or create new mechanisms to authenticate such as an AppRole. Terraform can interact with platforms such as VMware to provision new virtual machines. VMware does not provide a cryptographic identity, so a platform integration isn't possible. Instead, Terraform can provision a new AppRole credential, and SSH into the new machine to inject the credentials.

# Vault Agent Auto-Auth

[Allows Vault Agent to auth in a wide variety of environments](https://www.vaultproject.io/docs/agent/autoauth/index.html)

- automatically authenticates to Vault for those supported auth methods
- keeps token renewed (re-authenticates as needed) until the renewal is no longer allowed
- designed with robustness and fault tolerance

## Overview

Two parts to auto-auth: method (which auth method will be used) and sink (one or more, locations where agent should write a token (any time the current token value has changed).

When the Vault Agent is started with auto-auth enabled:

- the agent will attempt to acquire a Vault token using the configured *method*
- on failure, the agent will retry after a short period and included randomness (to avoid thundering herd scenario)
- on success, the agent will keep the resulting token (unless wrap is configured) renewed until renewal is no longer allowed or fails, at which point it will attempt to re-auth

## Advanced Functionality

Sinks support advanced features such as writing encrypted or [response-wrapped](https://www.vaultproject.io/docs/concepts/response-wrapping.html) values. Both mechanisms can be used concurrently; if both are used, then the response will be response-wrapped, then encrypted.

### Methods

```
AliCloud
AppRole
AWS
Azure
Certificate
GCP
JWT
Kubernetes
PCF
```
### Sinks

The file sink writes tokens (optionally response-wrapped or encrypted) to a file:

- this may be a local file or a file mapped via some other process (NFS, Gluster, CIFS, etc.)
- the file is currently always written with *0640* (read-write-exec) permissions.
- once the token is written to file, it is up to the client (not Vault Agent) to control lifecycle; guidance is to delete the token as soon as it is seen/consumed

## Agent Caching Implications

https://www.vaultproject.io/docs/agent/caching/index.html#vault-agent-caching

- using `use_auto_auth_token` configuration of the Vault Agent, clients *will not be required* to provide a Vault token in the requests made to the Vault Agent
- when this configuration is set, if the request doesn't already bear a token, then the auto-auth token will be used to forward the request to the Vault server.
- this configuration will be overridden if the request already has a token attached, in which case, the token present in the request will be used to forward the request to the Vault server.

# Walkthrough

## Platform Integration



## Trusted Orchestrator