#Environment

Requires a Vault server
Client workstation or VM where the Vault binary has been unzipped and added to the path statement.
Set VAULT_ADDR environment variable pointing to the Vault cluster
A signed certificate and public key for the client that includes `extendedKeyUsage = clientAuth`
CA cert for the CA that signed the client’s cert if that CA is not available on the Vault server’s CA store
Valid DNS record for the client as presented in the signed certificate

#Prepare Vault

Enable KV at path /demo:

vault secrets enable -path=demo kv

Create dummy data at path /demo:

vault kv put demo/myapp/config \
current_password=tH1si3ecure \
last_password=Sup3rSecret

Create a read-only policy for our clients:

```
cat << EOF > myapp-kv-ro.hcl
path "demo/*" {
capabilities = ["read", "list"]
}
EOF
```

write the policy:

`vault policy write myapp-kv-ro myapp-kv-ro.hcl`

view active policies and their contents:

`vault policy list`

`vault policy read myapp-kv-ro`

Enable the certificate auth method:

`vault auth enable cert`

Upload or copy the client's certificate to the Vault server:

`scp -i .ssh/jgrdubc /Users/jray/vault-client.crt jray@vault-ent-node-1:~/`

Configure the cert mount with trusted certificates that are allowed to authenticate:

```
vault write auth/cert/certs/web \
    display_name=web \
    policies=myapp-kv-ro \
    certificate=@vault-client.crt
```

## update policy to add TFC secret engine access

- add read access to the policy

```
cat << EOF > myapp-kv-ro.hcl
path "demo/*" {
capabilities = ["read", "list"]
}
path "terraform/creds/tfcuser" {
capabilities = ["read", "list"]
}
EOF
```

- re-write policy config

```
vault write auth/cert/certs/web \
    display_name=web \
    policies=myapp-kv-ro \
    certificate=@vault-client.crt
```

#Authenticate from a Client

##Setup Vault

```
export VAULT_VERSION=1.6.0
export VAULT_ADDR=https://vault-ent-node-1:8200
```

`wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip`

`unzip vault_${VAULT_VERSION}_linux_amd64.zip`

`sudo cp -rp vault /usr/local/bin/vault`

```
sudo tee -a /etc/environment <<EOF
export VAULT_ADDR=$VAULT_ADDR
EOF
```

`source /etc/environment`

##Authenticate

```
vault login \
    -method=cert \
    -ca-cert=lab_ca.crt \
    -client-cert=vault-client.crt \
    -client-key=vault-client.key \
    name=web
```

```
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                            Value
---                            -----
token                          s.XBEsxUlf5yzwzehK1jVIorQQ
token_accessor                 P7NFfeRX4BpqcBrew1AgxwAi
token_duration                 768h
token_renewable                true
token_policies                 ["default" "myapp-kv-ro"]
identity_policies              []
policies                       ["default" "myapp-kv-ro"]
token_meta_authority_key_id    d1:8b:ea:a5:c8:26:be:46:50:32:d6:7b:97:6c
token_meta_cert_name           web
token_meta_common_name         vault-client
token_meta_serial_number       302267282237613760284485424536315069081
token_meta_subject_key_id      3b:e7:10:73:2b:50:75:11:5a:a9:c6:7c:0a:de
```

Validate policy is granting read-only access to the KV path:

`vault kv get demo/myapp/config`

```
========== Data ==========
Key                 Value
---                 -----
current_password    tH1si3ecure
last_password       Sup3rSecret
```

- attempt to write data

```
vault kv put demo/myapp/config \
current_password=pwnthis
```

```
Error writing data to demo/myapp/config: Error making API request.

URL: PUT https://vault-ent-node-1:8200/v1/demo/myapp/config
Code: 403. Errors:

* 1 error occurred:
	* permission denied
```

###Vault Agent Auto-Auth

- Vault Agent configuration
`exit_after_auth` is used for testing or calling Vault Agent in a script; Vault Agent can be run as a daemon if desired mark this as `false`
within the sink config, **config path** is the complete path and filename

```
tee ~/auto-auth-conf.hcl <<EOF
exit_after_auth = true #run once, then exit
pid_file = "./pidfile"

auto_auth {
    method "cert" {
        mount_path = "auth/cert"
        config = {
            name = "web"
            ca_cert = "/home/jray/lab_ca.crt"
            client_cert = "/home/jray/vault-client.crt"
            client_key = "/home/jray/vault-client.key"
        }
    }

    vault {
      address = "https://vault-ent-node-1:8200"
    }

    sink "file" {
        config = {
            path = "/home/jray/vault-token-via-agent/here_is_your_token"
        }
    }
}
EOF
```

- make sure VAULT_ADDR is set with HTTPS if TLS is enabled on the cluster:

`export VAULT_ADDR=https://vault-ent-node-1:8200`

- run Vault Agent manually:

`vault agent -config=/home/jray/auto-auth-conf.hcl -log-level=debug`

- view the token from the file sink:

`cat /home/jray/vault-token-via-agent/here_is_your_token`

- Vault Agent configuration with Seal Wrapping

```
tee ~/auto-auth-conf.hcl <<EOF
exit_after_auth = true #run once, then exit
pid_file = "./pidfile"

auto_auth {
    method "cert" {
        mount_path = "auth/cert"
        config = {
            name = "web"
            ca_cert = "/home/jray/lab_ca.crt"
            client_cert = "/home/jray/vault-client.crt"
            client_key = "/home/jray/vault-client.key"
        }
    }
    vault {
      address = "https://vault-ent-node-1:8200"
    }

    sink "file" {
      wrap_ttl = "10m"
        config = {
            path = "/home/jray/vault-token-via-agent/here_is_your_token"
        }
    }
}
EOF
```
- view wrapped data:

`tail /home/jray/vault-token-via-agent/here_is_your_token | jq`

- unwrap data

`export VAULT_TOKEN=$(vault unwrap -field=token $(jq -r '.token' /home/jray/vault-token-via-agent/here_is_your_token))`

- check for valid token:

`echo $VAULT_TOKEN`

- use this token to log into Vault:

`vault login $VAULT_TOKEN`

- read the KV path

`vault kv get demo/myapp/config`
