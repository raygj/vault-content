# Vault Enterprise Licensing

## General Notes

- HashiCorp Vault Enterprise customers receive information on how to retrieve a pre-licensed binary
- If you download a Vault Enterprise binary from [releases.hashicorp.com](https://releases.hashicorp.com/) the Vault Enterprise license file will be supplied by your HashiCorp TAM or SE
- the license should be applied on a single node while the other (usually 2 stand-by nodes) are not running
  - once the license is applied on the single active node and verified, start the Vault service and unseal each of the stand-by nodes
  - the enterprise license will be replicated to the stand-by nodes
- the license must be applied applied within 30 minutes of starting the Vault service or Vault will seal itself (and you need will need to restart the service and start the process over)
- note this guide assumes you have enabled HTTPS enabled on your cluster
- check [Vault Enterprise Documentation](https://www.vaultproject.io/docs/enterprise/) for future updates and formal guidance on applying the license file

## On the Active Vault Node

- assuming Vault is unsealed and you have a valid root token OR token with appropriate policy to write to the `/sys` path
- export token to an env var:

`export VAULT_TOKEN= < root or privileged token >`

### CLI method

- input:

`vault write sys/license text=< some very character string>`

`enter`

- output:

`Success! Data written to: sys/license`


### API method

if you do not have access to the CLI, then use the API method.

#### prepare the Vault Enterprise license file

- the license file name is in the format `< some string of numbers >.hclic`
- copy the `.hclic` file to server at `/tmp`:

`scp /<local dir>/*.hclic root@<remote server>:/tmp`

- create a new file that will be the JSON payload:

`cp /tmp/< filename >.hclic /tmp/vault.json`

- the file contains a long string that must be modified into a proper JSON format by adding a header
- modify the file with Nano or VIM

`nano vault.json`

- add curly brackets, the "text" annotation, and double quotes around the license string
- for example:

```

{
  "text": "01ABCDEFG..."
}

```

- save and exit the payload file

#### apply the license

- assumes the env var is set and the curl command is issued on the Vault node (if not, replace 127.0.0.1 with the actual address of the Vault node):

`curl --header "X-Vault-Token: $VAULT_TOKEN" --request PUT --data @vault.json https://127.0.0.1:8200/v1/sys/license`

- verify the license was written:

`curl --header "X-Vault-Token: $VAULT_TOKEN" https://127.0.0.1:8200/v1/sys/license | jq`

- check Vault status:

`curl https://127.0.0.1:8200/v1/sys/seal-status`

## On each of the Secondary Vault Nodes

- start the Vault service:

`systemctl start vault`

- validate that Vault is unsealed and that the license has been replicated

export VAULT_TOKEN= < root or privileged token >

- unseal Vault with `vault operator unseal` or the [API endpoint](https://www.vaultproject.io/api-docs/system/unseal/#sysunseal)
- verify Vault status:

`curl https://127.0.0.1:8200/v1/sys/seal-status`

- verify the license is active

`curl --header "X-Vault-Token: $VAULT_TOKEN" https://127.0.0.1:8200/v1/sys/license | jq`
