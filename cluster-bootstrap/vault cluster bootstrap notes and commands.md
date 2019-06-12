# Vault Ent Cluster Bootstrap Notes and Command Snippets
- vaulnodea/b/c on local ESXi 02.25.2019
- install JQ to format API responses

`sudo apt install jq -y` or `yum install jq -y`

## Initial Root Token: <root token in keepass>
- use env var to call root token
`export VAULT_ROOT=<root token>`

# licensing
# https://www.vaultproject.io/api/system/license.html
```
curl --header "X-Vault-Token: $VAULT_ROOT --request PUT --data @vault.json http://127.0.0.1:8200/v1/sys/license

curl \
    --header "X-Vault-Token: $VAULT_ROOT" \
    http://127.0.0.1:8200/v1/sys/license | jq
```

# setup Consul and Vault variables
```
export VAULT_ADDR=http://127.0.0.1:8200

echo 'export VAULT_ADDR="http://127.0.0.1:8200"' >> $HOME/.bashrc

sudo echo export 'CONSUL_HTTP_ADDR="http://127.0.0.1:8500"' >> $HOME/.profile
```

# applying Vault ent licenses

`curl --header "X-Vault-Token: $VAULT_ROOT" --request PUT --data @vault.json http://127.0.0.1:8200/v1/sys/license`

# create userpass auth method
```
vault write -namespace=LOB-Team-1 auth/userpass/users/jray password="password"

vault login -method=userpass \
    username=jray \
    password=<some password>
```

# request counter (requires OSS version 1.1 or greater)
- used for sizing enterprise clusters
```
vault read -format=json sys/internal/counters/requests

curl \
--header "X-Vault-Token: $VAULT_ROOT" \
	http://127.0.0.1:8200/v1/sys/internal/counters/requests | jq
```