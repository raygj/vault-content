# Consul Enterprise Licensing

- download .hclic file from licensing.hashicorp.com
- copy file to Vault server

`scp /<local dir>/*.hclic root@<remote server>:/tmp`

- install license

`consul license put @<binary file>.hclic`

- remove hclic file

`rm rf /tmp/*hclic`

# Vault Enterprise Licensing

- download .hclic file from licensing.hashicorp.com
- copy file to Vault server

`scp /<local dir>/*.hclic root@<remote server>:/tmp`

- Create new file `vault.json`

`cp /tmp/*hclic /tmp/vault.json`

- modify JSON file to include header and formatting

`nano vault.json`

- modify format into key:value JSON format

```

{
  "text": "01ABCDEFG..."
}

```

- install license using Vault API call

```

export VAULT_TOKEN= < root or privileged token >

curl --header "X-Vault-Token: $VAULT_TOKEN" --request PUT --data @vault.json http://127.0.0.1:8200/v1/sys/license


```

- check license details

`curl  --header "X-Vault-Token: $VAULT_TOKEN" http://127.0.0.1:8200/v1/sys/license | jq`

- check Vault

`vault status`
