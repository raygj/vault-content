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

[courtesy of tdsacilowski](https://github.com/tdsacilowski/vault-agent-guide)

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

### Part 2: Login Manually From the Client Instance

Now that we've configured the appropriate AWS IAM auth method on our Vault server, let's SSH into our **client** instance and verify that we're able to successfully utilize the instance profile to login to Vault.

1. [From the Vault **Client**] Open a terminal on your client instance. If using the quick-start repo, the Vault binary should already be installed and configured to talk to your Vault server. You can check this by typing in `vault status`:

`vault status`

If following with your own examples, make sure you've downloaded the appropriate [Vault binary](https://releases.hashicorp.com/vault/) and set your VAULT_ADDR environment variable, for example:

`export VAULT_ADDR=http://<private IP of Vault Server>:8200`

2. [From the Vault **Client**] Using the Vault CLI, test the `login` operation:

`vault login -method=aws role=dev-role-iam`

If all components are configured accurately up to this point, then you will recieve a **success** message, similar to the follow:

```

Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                                Value
---                                -----
token                              s.ylLSNKH...
token_accessor                     ppps6JVO8xTR15OHb8d9Nhzi
token_duration                     15m
token_renewable                    true
token_policies                     ["default" "myapp-kv-ro"]
identity_policies                  []
policies                           ["default" "myapp-kv-ro"]
token_meta_inferred_entity_id      n/a
token_meta_role_id                 <your token meta role ID>
token_meta_canonical_arn           arn:aws:iam::<your aws account number>:role/jray-vault-demo-vault-client-role
token_meta_client_arn              arn:aws:sts::<your aws account number>:assumed-role/jray-vault-demo-vault-client-role/i-09a...
token_meta_client_user_id          <you client user ID>
token_meta_inferred_aws_region     n/a
token_meta_inferred_entity_type    n/a
token_meta_account_id              <you aws account number>
token_meta_auth_type               iam

```

3. [From the Vault **Client**] We can also check to make sure that the token has the appropriate permissions to read our secrets:

`vault kv get kv/myapp/config`

### Part 3: Using Vault Agent Auto-Auth on the Client Instance

In this section we'll take everything we've done so far and apply it to the Vault Agent Auto-Auth method and write out a token to an arbitrary location on disk.

1. [From the Vault **Client**] First, we'll create a configuration file for the Vault Agent to use:

```
tee /home/ubuntu/auto-auth-conf.hcl <<EOF
exit_after_auth = true
pid_file = "./pidfile"

auto_auth {
	method "aws" {
    	mount_path = "auth/aws"
        	config = {
            	type = "iam"
				role = "dev-role-iam"
            }
        }

sink "file" {
	config = {
		path = "/home/ubuntu/vault-token-via-agent"
            }
        }
    }
EOF

```

In this file, we're telling Vault Agent to use the `aws` auth method, located at the path `auth/aws` on our Vault server, authenticating against the IAM role `dev-role-iam`.

We're also identifying a location on disk where we want to place this token. The `sink` block can be configured multiple times if we want Vault Agent to place the token into multiple locations.

2. [From the Vault **Client**] Now we'll run the Vault Agent with the above config:

`vault agent -config=/home/ubuntu/auto-auth-conf.hcl -log-level=debug`

***NOTES:*** 

In this example, because our `auto-auth-conf.hcl` configuration file contained the line `exit_after_auth = true`, Vault Agent simply authenticated and retrieved a token once, wrote it to the defined sink, and exited. 

Vault Agent can also run in daemon mode where it will continuously renew the retrieved token, and attempt to re-authenticate if that token becomes invalid.


3. [From the Vault **Client**] Let's try an API call using the token that Vault Agent pulled for us to test:

```
curl \
--header "X-Vault-Token: $(cat /home/ubuntu/vault-token-via-agent)" \
$VAULT_ADDR/v1/kv/myapp/config | jq

```

#### Response Wrapping

4. [From the Vault **Client**] In addition to pulling a token and writing it to a location in plaintext, Vault Agent supports response-wrapping of the token, which provides an additional layer of protection for the token. Tokens can be wrapped by either the auth method or by the sink configuration, with each approach solving for different challenges, as described [here](https://www.vaultproject.io/docs/agent/autoauth/index.html#response-wrapping-tokens). In the following example, we will use the sink method.

Let's update our `auto-auth-conf.hcl` file to indicate that we want the Vault token to be response-wrapped when written to the defined sink:

```
tee /home/ubuntu/auto-auth-conf.hcl <<EOF
exit_after_auth = true
pid_file = "./pidfile"

auto_auth {
	method "aws" {
    	mount_path = "auth/aws"
        	config = {
            	type = "iam"
				role = "dev-role-iam"
            }
        }

sink "file" {
	wrap_ttl = "10m"
		config = {
			path = "/home/ubuntu/vault-token-via-agent"
            }
        }
    }
EOF

```

5. [From the Vault **Client**] Let's run the Vault Agent and inspect the output:

`vault agent -config=/home/ubuntu/auto-auth-conf.hcl -log-level=debug`

5a. Inspect the contents of the file written to the sink:

`cat /home/ubuntu/vault-token-via-agent | jq`

Here we see that instead of a simple token value, we have a JSON object containing a response-wrapped token as well as some additional metadata. In order to get to the true token, we need to first perform an unwrap operation.

6. [From the Vault **Client**] Let's unwrap the response-wrapped token and save it to a `VAULT_TOKEN` env var that other applications can use:

`export VAULT_TOKEN=$(vault unwrap -field=token $(jq -r '.token' /home/ubuntu/vault-token-via-agent))`

`echo $VAULT_TOKEN`

Notice that the value saved to the `VAULT_TOKEN` is not the same as the `token` value in the file `/home/ubuntu/vault-token-via-agent`. The value in `VAULT_TOKEN` is the unwrapped token retrieved by Vault Agent. Additionally, note that if we try to unwrap that same value again, we get an error:

`export VAULT_TOKEN=$(vault unwrap -field=token $(jq -r '.token' /home/ubuntu/vault-token-via-agent))`

```
Error unwrapping: Error making API request.

URL: PUT http://<your Vault server IP>:8200/v1/sys/wrapping/unwrap
Code: 400. Errors:

* wrapping token is not valid or does not exist

```
### Summary

In the previous section, we:

- enabled AWS auth method using IAM role
- created a RO policy and attached it to the AWS role
- used the auto-login capability of the Vault Agent to log into Vault using the IAM policy
- requested a response-wrapped token, then unwrapped it and exported the previously wrapped token to an env var

# Katacoda Demo Environment

[Vault Agent with AppRole](https://www.katacoda.com/hashicorp/scenarios/vault-agent)

# Walkthrough - Trusted Orchestrator - AppRole

https://github.com/raygj/vault-content/tree/master/use-cases/jenkins
