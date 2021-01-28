### enable Vault audit logging:

1. setup dirs

```
kubectl -n vault exec -it vault-0 -- /bin/sh

touch /vault/vault_audit.log
```

2. enable audit

```
vault login < root token >

vault audit enable file file_path=/vault/vault-audit.log
```

3. start a tail in the exec session and then open another terminal window

`tail -f /vault/vault-audit.log`

4. identify a bad auth attempt with "userpass" login via API:

```
curl \
    --request POST \
    --data '{"password": "vault"}' \
    http://localhost:8200/v1/auth/userpass/login/vault | jq
```

5. view result in CLI:

```
{
  "errors": [
    "missing client token"
  ]
}
```

6. view result in audit log:

```
"auth/userpass/login/vault","data":{"password":"hmac-sha256:fb17f2547faa0de2c0d16f6557f5d309f9a3287cee63e0d2c2215ce7fa55ceab"},"remote_address":"127.0.0.1"},"response":{"data":{"error":"hmac-sha256:14aa3917f0b53a99579f7625b3399848f90a5a5c76f92acb0d3b4333fb2b2aa9"}},"error":"1 error occurred:\n\t* invalid request\n\n"}
```
7. now, execute the k8s auth attempt and check Vault's audit log for errors
