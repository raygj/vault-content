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

# Walkthrough - Platform Integration - AWS

## Vault AWS Deployment

For an example of quick-start Terraform code for deploying a single-node Vault cluster and a bare EC2 instance on which to test, please see [this repo](https://github.com/raygj/vault-content/tree/master/vault-aws-demo-instance).

**NOTES:**

The example Terraform code in the above repository is not suitable for production use.

Update the `security-groups.tf` to reflect the ip address of your workstation so as to avoid 0.0.0.0/0 rules

Set `VAULT_ADDR` environment variable (or update your path statement) to point to the public IP address of the Vault Server - this will allow you to send Vault commands directly from a terminal on your workstation, rather than SSH'ing into the EC2 instance


### Part 1: Configure the AWS IAM Auth Method

In this section, we'll write some dummy data/policies and configure Vault to allow AWS IAM authentication from specifies IAM roles.

1. [From the Vault **Server**] If you haven't done so already, perform a `vault operator init`. Make sure to note down your unseal keys and initial root token in a safe place. You will need these in the following steps (in production, you would secure these in a much better way, or use auto-unseal).

2. [From the Vault **Server**] If your Vault server is sealed, perform the `vault operator unseal` operation 1 key shard (this a demo environment!).

3. [From the Vault **Server**] Login using your initial root token (or other administrative login that you might have already configured).

`vault login <root or admin token>

4. [From the Vault **Server**] Create a read-only policy for our clients:

```

vault policy write myapp-kv-ro - <<EOF
path "kv/myapp/*" {
capabilities = ["read", "list"]
}
EOF

```

4a. Check that KV secrets engine is enabled, if not, enable it:

`vault secrets list`

`vault secrets enable kv`

4b. Create dummy data:

```

vault kv put kv/myapp/config \
username='appuser' \
password='suP3rsec(et!'

```

5. Enable the aws auth method:

`vault auth enable aws`

6. [From the Vault **Server**] Next, configure the AWS credentials that Vault will use to verify login requests from AWS clients:
   
`vault write -force auth/aws/config/client`

***NOTES:***

In the above example, I'm relying on an instance profile to provide credentials to Vault. 

See [here](https://www.vaultproject.io/docs/auth/aws.html#recommended-vault-iam-policy) for an example IAM policy to give Vault in order for it to handle AWS IAM auth.

You can also pass in explicit credentials as such:

`vault write auth/aws/config/client secret_key=AWS_SECRET_ACCESS_KEY access_key=AWS_ACCESS_KEY_ID`

7. Identify the IAM instance profile role associated with the client instance that you intend to authenticate from.
   
If you're using the sample repo linked above in the intro, you'll have a `"${var.environment_name}-vault-client"` instance created for you with an instance profile role of `"${var.environment_name}-vault-client-role"`.

If you're provisioning your own examples, spin up an EC2 instance and assign it any instance profile, the IAM role policy is not important from Vault's perspective. What *is* important is the fact that a `vault login` operation from the client instance can use the attached instance profile as a way to identify itself to Vault.

[From the Vault **Server**] Configure a **Vault** role under the AWS authentication method that we configured in the previous step. A Vault auth role maps an AWS IAM role to a set of Vault policies (I'll reference the dummy policy created in step #4):
   
```
vault write auth/aws/role/dev-role-iam auth_type=iam \
bound_iam_principal_arn=arn:aws:iam::<AWS_ACCOUNT_NUMBER>:role/<IAM role> \
policies=myapp-kv-ro \
ttl=15m

```
***NOTE:*** To get your IAM role ARN, you'll need to go to the AWS console and find the `IAM role` and `Owner` associated with the instance profile that you want to use as a source of authentication. If you're following along with the quick-start repo, the instance will have the AWS CLI installed and you can simply run the following to obtain information about the IAM role:

`aws iam get-role --role-name [VAR_ENVIRONMENT_NAME]-vault-client-role`

examnple:

```
vault write auth/aws/role/dev-role-iam auth_type=iam \
bound_iam_principal_arn=arn:aws:iam::753646501470:role/jray-vault-demo-vault-client-role \
policies=myapp-kv-ro \
ttl=15m

```

# Walkthrough - Trusted Orchestrator - Terraform AppRole