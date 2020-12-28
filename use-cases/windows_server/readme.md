##setup Vault on Windows Server

###download and prepare Vault binary

- [download Vault from release.hashicorp](https://releases.hashicorp.com/vault/)
- unzip to dedicated folder, e.g., c:\vault
- set path

`control panel > system and security > system > advanced system settings > environment variables`

- select `Path` and then `Edit...`
- add the path to vault.exe with leading and trailing ";" for example:

`%USERPROFILE%\AppData\Local\Microsoft\WindowsApps;c:\vault;`

- close all windows/prompts
- open a new command prompt and verify path statement is correct

command `vault` should return info on vault binary, if not, troubleshoot path statement

##start a vault server
- start vault in dev mode to test environment

`vault server -dev`

- open a new command prompot and set VAULT_ADDR environment variable on the Vault node

`set VAULT_ADDR=http://127.0.0.1:8200`

- verify with vault status, should report vault is unsealed

`vault status`

- use `ctrl-c` to stop the vault server

##start a vault agent

- open a command prompot and set VAULT_ADDR environment variable on the Vault node

`set VAULT_ADDR=https://vault-ent-node-1:8200`

###using cert auth for Windows

- cert signed by CA, stored as .crt file in C:\vault\certs

```
c:\vault\certs>dir
 Volume in drive C has no label.
 Volume Serial Number is 10DC-0E88

 Directory of c:\vault\certs

12/28/2020  11:20 AM    <DIR>          .
12/28/2020  11:20 AM    <DIR>          ..
12/21/2020  06:44 PM             3,825 vault-client.crt
```
- import cert to Personal cert store for current user

####manual auth attempt

vault login -method=cert -ca-cert=c:\vault\certs\lab_ca.crt -client-cert=c:\vault\certs\vault-client.crt -client-key=c:\vault\certs\vault-client.key name=web

####auto-auth

- Vault agent config c:\vault\agent\auto_auth-conf.hcl

```
exit_after_auth = true #run once, then exit
pid_file = "./pidfile"

auto_auth {
    method "cert" {
        mount_path = "auth/cert"
        config = {
            name = "web"
            ca_cert = "c:\\vault\\certs\\lab_ca.crt"
            client_cert = "c:\\vault\\certs\\vault_client.crt"
            client_key = "c:\\vault\\certs\\vault_client.key"
        }
    }

vault {
  address = "https://vault-ent-node-1:8200"
}

    sink "file" {
        config = {
            path = "c:\\vault\\vault_token_via_agent\\here_is_your_token.txt"
        }
    }
}
```

- run Vault agent manually

vault agent -config=c:\vault\agent\auto_auth-conf.hcl -log-level=debug

- Vault agent config with token wrapping enabled

```
exit_after_auth = true #run once, then exit
pid_file = "./pidfile"

auto_auth {
    method "cert" {
        mount_path = "auth/cert"
        config = {
            name = "web"
            ca_cert = "c:\\vault\\certs\\lab_ca.crt"
            client_cert = "c:\\vault\\certs\\vault_client.crt"
            client_key = "c:\\vault\\certs\\vault_client.key"
        }
    }

vault {
  address = "https://vault-ent-node-1:8200"
}

    sink "file" {
      wrap_ttl = "10m"
        config = {
            path = "c:\\vault\\vault_token_via_agent\\here_is_your_token.txt"
        }
    }
}
```


#appendix

#reset windows activation timer

1. administrator PS command prompt
2. `slmgr.vbs -rearm`
3. reboot
