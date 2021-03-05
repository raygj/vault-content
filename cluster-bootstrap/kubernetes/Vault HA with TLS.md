# HA Vault with TLS on K8S

[reference](https://github.com/hashicorp/vault-helm/issues/243) with additional config samples


- the CSR must be generated with the following config:

```
[alt_names]
DNS.1 = *.${VAULT_INTERNAL_SVC}
DNS.2 = *.${NAMESPACE}.svc.cluster.local
DNS.3 = *.${VAULT_INTERNAL_SVC}.${NAMESPACE}.svc.cluster.local
```

where

```
VAULT_RELEASE_NAME="vault"
VAULT_INTERNAL_SVC="${VAULT_RELEASE_NAME}-internal"
```

Then you can do:

vault operator init -address https://vault-0.vault-internal.vault.svc.cluster.local:8200
