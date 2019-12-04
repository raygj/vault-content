# Vault Enterprise Namespaces Demo

simple walkthrough illustrating Namespace feature of Vault Enterprise to support multitenancy

[reference to learn.hashicorp](https://learn.hashicorp.com/vault/operations/namespaces) guide that includes Entity feature and non-root policies.

## Configure Vault

using a root token (non-prod) or with a non-root token with sufficient [sysadm privileges](https://learn.hashicorp.com/vault/operations/namespaces#step-2-write-policies)

### Create a “finance” and an “education” namespace

`vault namespace create finance`

`vault namespace create education`

### now create child namespaces within Education namespace

`vault namespace create -namespace=education training`

`vault namespace create -namespace=education certification`

### list namespaces

`vault namespace list`

- output

```

education/
finance/

```

### list child namespaces of Education namespace

`vault namespace list -namespace=education`

- output

```
certification/
training/
```

## Demo Setup

- author the Finance namespace admin policy file

```

cat << EOF > /tmp/finance-admins.hcl
# Full permissions on the finance path
path "finance/*" {
   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF

```

- create the policy in Vault for Finance-Admin users

`vault policy write finance-admins finance-admins.hcl`


- generate a token associated with this policy 

**note** this policy with any other authentication method.

`vault token create -policy=finance-admins`

- output

```

Key                  Value
---                  -----
token                s.XhDAWO93Zjpb5AQtw77mQIIQ
token_accessor       9n4Q093MZcj2cikTRavCbxcY
token_duration       768h
token_renewable      true
token_policies       ["default" "finance-admins"]
identity_policies    []
policies             ["default" "finance-admins"]

```

## Demo - Namespace Management

Now let’s work as if we were a finance-admins administrator. The task is to create a policy to allow a _third user_ to only create, read, update, delete and list secrets in the path `finance/secret/app1/`

- login in using the token created under the finance-admin policy

`vault login < token with finance-admin privilege >`

- first create a policy that limits access to 

```

cat << EOF > /tmp/finance-app1.hcl
# Full permissions on the finance path
path "secret/app1/*" {
   capabilities = ["create", "read", "update", "delete", "list"]
}
EOF

```

- create the policy in Vault granting access to `/secret/app1` within the Finance namespace

`vault policy write -namespace=finance finance-app1 finance-app1.hcl`

**note** this is considered the "identity" approach where policies do not include the namespace, but rather are applied at the namespace level. this allows the policies to be consistent, fewer versions to track.

If you try to write the policy outside the assigned namespace, you will get an error:

`vault policy write finance-app1 finance-app1.hcl`

```

Error uploading policy: Error making API request.

URL: PUT http://127.0.0.1:8200/v1/sys/policies/acl/finance-app1
Code: 403. Errors:

* 1 error occurred:
	* permission denied

```

this demonstrates that a namespace admin can only manage users and policies of their assigned namespace

## Demo - Namespace Secret Engine

- let’s mount a secret engine within the Finance namespace

`vault secrets enable -namespace=finance -path=secret kv`

- let’s create a token associate with the `app1` policy; once again, this policy could be associated with any authentication method

`vault token create -namespace=finance -policy=finance-app1`

- output

```

Key                  Value
---                  -----
token                s.kQVjtoPR6f4Ra5H3dwUw98rW.KYK0T
token_accessor       uhAc2FBQPxkDaVRAM2GSxXZw.KYK0T
token_duration       768h
token_renewable      true
token_policies       ["default" "finance-app1"]
identity_policies    []
policies             ["default" "finance-app1"]

```

### KV secret engine V2

- now we can login into Vault as the app1 user, and validate that this user can only work within the specified constraints of the `finanice-app1` policy

`vault login < token with finance-app1 privilege >`

- set the default namespace for the CLI session

`export VAULT_NAMESPACE=finance`

- try writing a secret to `secret/app1`

`vault kv put secret/app1 value=test`

**success!**

- try to read a secret from `secret/app1`

`vault kv get secret/app1`

**success!**

- try to write a secret to the education namespace

`export VAULT_NAMESPACE=education`

`vault kv put secret/app1 value=test`

### KV secret engine V1

- now we can login into Vault as the app1 user, and validate that this user can only work within the specified constraints of the `finanice-app1` policy

`vault login < token with finance-app1 privilege >`

- try writing a secret to `secret/app1`

`vault write -namespace=finance secret/app1/test value=test`

**success!**

- try to read a secret from `secret/app1`

`vault read -namespace=finance secret/app1/test`

**success!**

- try to write a secret to the education namespace

`vault write -namespace=education secret/app1/test value=test`

```

Error writing data to secret/app1/test: Error making API request.

URL: PUT http://127.0.0.1:8200/v1/secret/app1/test
Code: 403. Errors:

* 1 error occurred:
	* permission denied

```

## API walkthrough

- pass the target namespace in the X-Vault-Namespace header:

```

curl --header "X-Vault-Token: ..." \
--header "X-Vault-Namespace: <namespace>" \
--request GET \ https://127.0.0.1:8200/v1/sys/mounts

```

- or, make the namespace as a part of the API endpoint:

```

curl --header "X-Vault-Token: ..." \ --request GET \
https://127.0.0.1:8200/v1/<namespace>/sys/mounts

```

- to check the KV secrets engine version, use the sys/mounts endpoint:

`export VAULT_TOKEN= < root or token with priveleges >`

```

curl --header "X-Vault-Token: $VAULT_TOKEN" \
       http://127.0.0.1:8200/v1/sys/mounts | jq

```       

- enable KV secrets engine v1 at kv-v1/

```

curl --header "X-Vault-Token: $VAULT_TOKEN" \
       --request POST \
       --data '{ "type": "kv" }' \
       http://127.0.0.1:8200/v1/sys/mounts/kv-v1

```

**note** production should use HTTPS

### write a secret

- create the payload file

```

cat << EOF > /tmp/kv_write.json
{
  "options": {
      "cas": 0
  },
  "data": {
      "foo": "bar",
      "zip": "zap"
    }
}
EOF

```

- send the API request to write the payload

`export VAULT_TOKEN=< token with finance-app1 role >`

```

curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data @kv_write.json \
    http://127.0.0.1:8200/v1/secret/data/my-secret

```

**note** production should use HTTPS