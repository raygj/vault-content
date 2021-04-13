# Vault AppRole Auth Walkthrough
Given that automating orchestration tasks using tools like Terraform or Nomad creates a challenge in security that is quite difficult to solve. The problem becomes, how do you safely and securely get the first secret (credential) onto the machine without manual intervention? The first secret is incredibly sensitive as it’s generally a token or certificate used by the machine to pull down all the other secrets needed by the services running on that host like database credentials.

Solving this challenge generally requires a modern secrets management tool that can integrate and scale with the orchestration tooling you’re using to automate. A common way people get around actually solving this is to just bake the first secret into the host image, insecurely pass it in at runtime, or derive the credentials using information available on the host. If an attacker gains access to a machine or the orchestration tool, they can use those credentials to pull the rest of that machines secrets which can widen the attack surface.

It is common for operators to push the first secret up the stack, attempt to hide it, or encrypt it with another key that’s just stored elsewhere. This isn’t solving the problem, it’s just masking it - see the “Turtles all the way down” expression.

This challenge is commonly referred to as the “bootstrapping”, “chicken and egg”, “secret zero”, or “secure introduction” problem.

HashiCorp’s Vault provides a number of clever ways to solve the secure introduction problem through a number of authentication backends.

## Reference Material
- [Official Learn Guide](https://learn.hashicorp.com/tutorials/vault/approle)
- [AppRole Secret backend docs](https://www.vaultproject.io/docs/auth/approle.html)
- [Secure Introduction at scale video](https://www.youtube.com/watch?v=R-jJXm3QGLQ&t=1s)
- [ECS & Vault: Shhhhh… I have a secret…](https://kickstarter.engineering/ecs-vault-shhhhh-i-have-a-secret-40e41af42c28)

## personas

- client: most likely a non-interactive machine process, that needs authentication material to access Vault
- operator: Vault administrator
- image builder: a process or human that creates VM images and will embedded the AppRole, Role ID into the image
- orechestrator: a process or human that deploys VMs, from image builder's repo, and will inject the AppRole Secret ID into the VM once it is instantiated

## build: prepare vault (operator persona)

- log into Vault with a user that is assigned an admin policy

### define the authZ token policy for client persona

- this policy will be assigned to all AppRole tokens
- the policy can be used on a single or multiple Secret Engine mount points
- update the policy to point to a demo KV path (or other Vault path) used in other test cases or demos, or create a KV path now

- create the policy that is tightly scoped to a single path, no wildcard used

```
tee app-1-read-only.hcl <<EOF
path "demo/app-1" {
  capabilities = ["read", "list"]
}
EOF
```

- apply the policy

`vault policy write app-1-read-only app-1-read-only.hcl`

- verify

`vault policy read app-1-read-only`

#### demo KV data

```
vault secrets enable -path=demo kv

vault kv put demo/app-1/ \
current_password=tH1si3ecure \
last_password=Sup3rSecret

vault kv get demo/app-1
```

### enable secret engine

- enable AppRole at a specific path

`vault auth enable -description="Demo AppRole auth method" -path approle-orch approle`

- verify

`vault auth list -detailed`

- to remove a mount and its config, disable it

`vault auth disable approle-orch`

### configure the AppRole auth method

- define TTL values and bind the policy created in the previous step

```
vault write auth/approle-orch/role/app-1 policies="app-1-read-only" \
        secret_id_ttl=30m token_num_uses=10 token_ttl=60m token_max_ttl=90m secret_id_num_uses=40
```

- verify config

`vault read auth/approle-orch/role/app-1`

| Levelset |

- at this point the foundation is set:

1. a secret path **demo/app-1**
2. a policy that grants RO access to that KV for all AppRole tokens created on the path we enabled
3. an AppRole auth instance mounted at **approle-orch**

| Next |

- use these components to create authN material for our client

## demo

### Fetch Role ID

Now that we have a Role setup, we can grab the RoleName and it’s unique identifier, the RoleID.

The RoleName is less sensitive as you can only use it to generate the other half credential needed to authenticate with Vault (the SecretID). This will be leveraged in the next step.

The RoleID is a bit more sensitive than the RoleName as it is part of the credential. Generally operators will bake the RoleID iinto an image to be provisioned (AMI, ISO, etc.) or deployed (tar.gz, Docker image, binary, etc.). The RoleID is only known to the build orchestration system, while the SecretID (generated in the next step using the RoleName) is only available to the deploy orchestration system.

You can think about the RoleID as an email address and the Secret ID as your password. You of course don’t want to give your email address out to just anyone, but they would need your password to be able to get anywhere.

- generate the RoleID Identifier

`vault read auth/approle-orch/role/app-1/role-id`

> output

```
Key        Value
---        -----
role_id    9018d320-630e-5824-cfd1-64f4ab9678b2
```

### Fetch Secret ID

Now we’ll want to take the RoleName from the last step and use it to generate the SecretID. The SecretID is the other half of a credential that can be used to authenticate to Vault. In our email analogy, the SecretID is the password and the RoleID is the username.

The reason this is a critical step to understand is that neither system ever had access to both parts of the credential (both RoleID & SecretID). We were able to get around this by only needing to give the runtime orchestration system the RoleName, which by itself is useless for authentication, but can be used to create a dynamic “password” (SecretID) tied to it’s “username” (RoleID).

If our build system has the RoleID and our runtime orchestration system has the RoleName it uses to generate the SecretID, the end application is the only entity that posses both parts of the credential, and thus is the only entity that’s able to authenticate to Vault. This is how you can securely introduce credentials using automation.

- generate a new SecretID

`vault write -f auth/approle-orch/role/app-1/secret-id`

> output

```
Key                   Value
---                   -----
secret_id             724e00c5-545e-033f-54d9-a59e3dff1954
secret_id_accessor    271dd2a4-813c-f76c-a0b8-28f948f5d11d
secret_id_ttl         10m
```

### Login with AppRole...to get a Vault Token
When the end application is deployed, it’s init process will be configured to get it’s RoleID from the host at the location it was baked into the image, and it’s SecretID will have been deployed along with it. It will use these 2 credentials to authenticate (login) to Vault to receive a Vault token.

This Vault token can then be used by the application thereafter to retrieve secrets from Vault based on the scope of the policy the Role was configured with.

### CLI Login

- using Roled ID (static) and Secret ID (dynamic) fetched above

`vault write auth/approle-orch/login role_id=9018d320-630e-5824-cfd1-64f4ab9678b2 secret_id=1ae56a4c-c3fa-ca96-5ddd-bbf27fed04c9`

- attempt to read the demo KV path

`vault kv get demo/app-1`

**success?**

- attempt to delete the demo KV value

`vault kv delete demo/app-1`

**fail?**

### API Login

`export VAULT_ADDR=https://vault-ent-node-1:8200`

```
curl -X POST \
 -d '{"role_id":"9018d320-630e-5824-cfd1-64f4ab9678b2","secret_id":"1ae56a4c-c3fa-ca96-5ddd-bbf27fed04c9"}' \
 $VAULT_ADDR/v1/auth/approle-orch/login | jq
```
- login and export the client_token value as an environment variable

```
export VAULT_TOKEN=$(curl -X POST \
 -d '{"role_id":"9018d320-630e-5824-cfd1-64f4ab9678b2","secret_id":"1ae56a4c-c3fa-ca96-5ddd-bbf27fed04c9"}' \
 $VAULT_ADDR/v1/auth/approle-orch/login | jq -r '.auth.client_token')
```

- attempt to read the demo KV path

```
curl \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  $VAULT_ADDR/v1/demo/app-1 | jq
```

**success?**

- attempt to delete the demo KV value

```
curl \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --request DELETE \
  $VAULT_ADDR/v1/demo/app-1 | jq
```

**fail?**
