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
"auth/userpass/login/vault","data":{"password":"hmac-sha7fa55ceab"},"remote_address":"127.0.0.1"},
"response":{"data":{"error":"hmac-saa9"}},"error":"1 error occurred:\n\t* invalid request\n\n"}
```
7. now, execute the k8s auth attempt and check Vault's audit log for errors

### exmaple of a successful K8S login via Injector Sidecar

```
"hmac-sha256:2dfca6f426f38"},"remote_address":"172.17.0.1"},"response":{"auth":{"client_token":"hmac-sha256:fe8070d6ea474e",
"accessor":"hmac-sha256:3b103132","display_name":"k8s_injector-vault-int-app-sa","policies":["default","int-app-ro"],
"token_policies":["default","int-app-ro"],"metadata":{"role":"int-app-v_role","service_account_name":"int-app-sa",
"service_account_namespace":"vault","service_account_secret_name":"int-app-sa-token-9822g","service_account_uid":
"8709bd47-bc51-41ba-aa92-53f87bf5fa99"},"entity_id":"e4b08af3-2e72-7caa-d1ec-8045b877a675",
"token_type":"service","token_ttl":86400,"token_issue_time":"2021-01-26T17:16:49Z"},"mount_type":"token"}}
```
