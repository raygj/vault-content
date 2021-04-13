List Policies

`vault policy list`

Static Secrets - KV engine

show all active engines:

`vault secrets list`

CLI write a secret:

`vault kv put secret/demo/config/demo-api-key ttl=30m my-value=s3cr3t2`

CLI retrieve a secret:

`vault read secret/demo/config`



API list a secret:

export VAULT_TOKEN=< some token >

 curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data @payload.json \
    http://127.0.0.1:8200/v1/secret/demo/my-secret | jq



API retrieve a secret:

 curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    http://127.0.0.1:8200/v1/secret/demo/my-secret | jq
    

API delete a secret

 curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request DELETE \
    http://127.0.0.1:8200/v1/secret/demo/my-secret | jq