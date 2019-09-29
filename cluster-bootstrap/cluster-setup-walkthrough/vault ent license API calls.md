create the vaultlic.json

```

cat vaultlic.json >>EOF

{
  "text": "< paste license string here>"
}

EOF

```

set vault token

`export VAULT_TOKEN=$<root or admin token>

write license

```

curl --header "X-Vault-Token: $VAULT_TOKEN" --request PUT --data @/tmp/vaultlic.json http://127.0.0.1:8200/v1/sys/license

```

validate

```

curl --header "X-Vault-Token: $VAULT_TOKEN" http://127.0.0.1:8200/v1/sys/license

```

Vault license update
# On one of the Vault members (or via the API)
$ export VAULT_TOKEN=”$TOKEN”
$ vault write sys/license text=”CONTENTSOFLICENSEFILE…”

Two or more Vault Enterprise clusters 
Vault Enterprise can provide replication for geographically dispersed nodes/clusters. 
It would also assist in cases where horizontal scaling is required, although limitations in Vault 
performance are generally due to the I/O access capabilities for the Storage backend. 
In this case, a Cluster would serve as primary to a number of secondary clusters. 

Replication should be enabled in the primary node using the following command:
vault write -f sys/replication/primary/enable 
Secondary tokens should be generated using the following command:
vault write sys/replication/primary/secondary-token id=<id> 

In the secondary clusters, replication should be enabled using the tokens obtained from the primary cluster, using the following command:
vault write sys/replication/secondary/enable token=<token> 
