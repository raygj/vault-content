# Terraform Cloud Secret Engine Walkthrough

[Reference Doc](https://www.vaultproject.io/docs/secrets/terraform)

[Reference API](https://www.vaultproject.io/api/secret/terraform)

**definitions**:

- TFC = Terraform Cloud platform, HashiCorp-hosted
- TFE = Terraform Enterprise, self-hosted version of TFC
- Vault = Vault Enterprise or OSS 1.7.0 or later

## scope and prep

- initial release of secret engine includes the ability to generate API tokens for TFC Organizations, Teams, and Users
- a "binding" TFC token is required by Vault to support the communications between Vault and the target TFC Organization(s); based on the use case, an Organization, Team, or User token from your TFC/TFE installation may be required
- communication from Vault to TFC/TFE


## prep: gather details

### Terraform Creds

- two User tokens are required for this workflow;

1. a TFC bind User token that will be used to bind Vault to TFC within the identity context of a new or existing TFC user that has some access privilege within an organization. This token must have the needed permissions to manage all Organization, Team, and User tokens desired for this mount.
2. a TFC workflow User token that will be used by the actual workflow; in this case, a TFC API demo script that will reach out to TFC using the TFC User token that Vault is managing.

### gather "bind" user token

- create a TFC User account within the TFC Organization [TFC API token reference](https://www.terraform.io/docs/cloud/users-teams-organizations/api-tokens.html), copy token to a working file

```
NaV3kqh6jV3NzA.atlasv1.yi4tHAu...
```

### gather "workflow" user token

- if needed, create a new User account within the TFC Organization [TFC API token reference](https://www.terraform.io/docs/cloud/users-teams-organizations/api-tokens.html), copy token to a working file

```
Srj201qtjJflIQ.atlasv1.HOWJALz...
```

- in order to interact with the TFC API, Vault will need to be configured with the internal user ID of the "workflow" user
- the following command assumes that the current user logged into TFC is the "workflow" user, if that is not correct, then you will need to use an alternative [API command](https://www.terraform.io/docs/cloud/api/account.html)

- set the env variable $TFC_TOKEN with the value of the workflow user

`export TFC_TOKEN=Srj201qtjJflIQ.atlasv1.HOWJALz...`

```
curl \
  --header "Authorization: Bearer $TFC_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request GET \
  https://app.terraform.io/api/v2/account/details | jq
```
- output, copy the value for the **id** key

```
{
  "data": {
    "id": "user-qybB2BG1dEaiV45M",
    "type": "users",
    "attributes": {
      "username": "jray",
      "is-service-account": false,
```

## build: prepare Vault

### prep

- log into Vault with a user that is assigned an admin policy

### enable secret engine

`vault secrets enable terraform`

### configure secret engine

`vault write terraform/config token=<vault bind TFC token>`

- verify config

`vault read terraform/config`

**note** the `address` attribute is used to modify the default TFC/TFE server address

### configure the User role

- the secret engine supports all 3 TFC token types, however, only one can be bound per Vault role
- each request to this specific path will result in Vault providing a TTL-backed API token for the "workflow" user we defined above

`vault write terraform/roles/tfcuser user_id=user-qybB2BG1dEaiV45M`


- API payload.json:

```
{
    "name": "tfcuser",
    "user_id": "user-qybB2BG1dEaiV45M",
    "ttl": "4h",
    "max_ttl": "8h"
}
```

- API command:

```
export VAULT_TOKEN=s.tZ0k...
export VAULT_ADDR=https://vault-ent-node-1:8200

curl \
    --request POST \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --data @payload.json \
    $VAULT_ADDR/v1/terraform/role/tfcuser
```

- if no errors are returned, proceed

## test: "workfow" User token

### create token CLI

- log in as a Vault admin user
- manually rotate the User token to ensure all the components are working properly

`vault read terraform/creds/tfcuser`

- output:

```
Key                Value
---                -----
lease_id           terraform/creds/tfcuser/IFf3gAMuF...rqj4oDunj2
lease_duration     4h
lease_renewable    true
token              c555Mm9ejbzLpA.atlasv1.ncpz...
token_id           at-4W2T...UACtJy
```

### create token API

```
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    $VAULT_ADDR/v1/terraform/creds/tfcuser \ jq
```

- output:

```
{
  "request_id": "cbee8eb6-7e46-715e-0d29-8d37e4c85622",
  "lease_id": "terraform/creds/tfcuser/JnuxQy18Rt7favWAvlZmcSEr",
  "renewable": true,
  "lease_duration": 14400,
  "data": {
    "token": "qQLSC9S8HqaPZw.atlasv1.zyohqzIDu3ZOuvxxcVrux3Hrj6wTjLlv4RgMQNbj7AWPcGYzrZQgyaxAtrChGMepOys",
    "token_id": "at-BvzRd3wgxgSbwGH8"
  },
  "wrap_info": null,
  "warnings": null,
  "auth": null
}
```

## demo

- use [certificate auth walkthrough](https://github.com/raygj/vault-content/blob/master/use-cases/certificate-auth/cert-auth-walkthrough.md) as baseline build
- update Vault policy to include TFC mount path
- use Vault Agent to interact with Vault and automatically write token to an environment variable

### update policy to add TFC secret engine access

- add access to the policy

```
cat << EOF > myapp-kv-ro.hcl
path "demo/*" {
capabilities = ["read", "list"]
}
path "terraform/creds/*" {
capabilities = ["read"]
}
EOF
```

- update policy config

`vault policy write myapp-kv-ro myapp-kv-ro.hcl`

- verify

`vault policy read myapp-kv-ro`

### demo

_use the TFC API to validate access_

- set Vault server address

`export VAULT_ADDR=https://vault-ent-node-1:8200`

- use Vault Agent to login into Vault

```
vault login \
    -method=cert \
    -ca-cert=lab_ca.crt \
    -client-cert=vault-client.crt \
    -client-key=vault-client.key \
    name=web
```

- pull a TFC token for the "workflow" user

`vault read terraform/creds/tfcuser`

- set TFE_TOKEN value

`export TFE_TOKEN=oWaLT3e4h0HUQg.atlasv1.RmwybGa...`

- use token to lock TFE-DEMO workspace

```
curl \
  --header "Authorization: Bearer $TFE_TOKEN" \
  --header "Content-Type: application/vnd.api+json" \
  --request POST \
  --data @payload.json \
  https://app.terraform.io/api/v2/workspaces/ws-haK1VpFdEDGUJnqm/actions/lock | jq
```

- revoke lease in Vault, verify in TFC consul and test revoked token to confirm it is invalid

# Notes

- Rotate Role supported for the "bind" token used by Vault for roles that support Organization and Team tokens only
