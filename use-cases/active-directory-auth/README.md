# Active Directory (LDAP) Authentication Walkthrough

walkthrough configuring AD as an authentication source for Vault

## references

[HashiCorp SE Blog, Essential Vault Patterns](https://medium.com/hashicorp-engineering/essential-patterns-of-vault-part-2-b4d34976f1dc)

[HashiCorp Documentation](https://www.vaultproject.io/docs/auth/ldap.html)

[Pugme Blog](http://www.pugme.co.uk/index.php/2017/02/08/using-the-hashicorp-vault-ldap-auth-backend/)

## Windows Configuration

### Windows Server 2016

- set static IP address
- set DNS to local host `127.0.0.1`
- deploy new domain (forest) `vault-lab.home.org`
- after reboot verify AD and DNS services are running clean

#### Active Directory Setup

- create Vault Bind user (with minium RO access) that will be used by Vault to communicate to Windows AD

`Vault Bind, vaultbind`

- verify with `dsquery`

```

dsquery user -name "vault bind"

"CN=vault bind,CN=Users,DC=vault-lab,DC=home,DC=org"

```

- create AD group that will hold users that should have auth access to Vault

`vault-auth-group`

- use `dsquery` to pull/validate full LDAP string that will be used in the Vault connection details in the next step

```

dsquery group -name vault-auth*

"CN=vault-auth-group,DC=vault-lab,DC=home,DC=org"

```

- response string will be used to configure Vault to as the `binddn`

- use [ldp](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/cc771022(v%3Dws.11)) utility to connect to AD and verify credentials, LDAP strings, or explore directory

![diagram](/images/ldp_search.png)

^^ here's an example using LDP utility to gather or validate the `objectClass` and `groupattr-memberOf` components of the LDAP config

- create AD user that will represent a standard users that will auth to Vault, via AD

`Vault Sample, vsample`

- add this user `vsample` to the `vault-auth-group`

## Vault Configuration

### enable LDAP auth method at path `/windows`

`vault auth enable ldap`

- verify

`vault auth list`

### configure LDAP auth method

```

vault write auth/ldap/config \
     url="ldap://192.168.1.240" \
     binddn="CN=vaultadm,CN=Users,DC=vault-lab,DC=home,DC=org" \
     bindpass='m8M34v-343v' \
     starttls=false \
     insecure_tls=false \
     discoverdn=false \
     deny_null_bind=true \
     userattr="CN" \
     userdn="CN=Users,DC=vault-lab,DC=home,DC=org" \
     groupfilter="(&(objectClass=person)(uid={{.Username}}))" \
     groupattr="memberOf" \
     groupdn="CN=vault-auth-group,CN=Users,DC=vault-lab,DC=home,DC=org" \
     use_token_groups=true \
     case_sensitive_names=true

```

### create KV mount for demo at path /windows-demo

`vault secrets enable -path=windows-demo kv`

- verify

`vault secrets list`

### create policy and map to `ldap` config

- create policy HCL file that limits access to KV mounted at `/windows-demo` to ready-only

```

cat << EOF > /tmp/windows-kv-ro.hcl

# If working with K/V v1
path "windows-demo/*" {
    capabilities = ["read", "list"]
}
EOF

```

- write contents of policy HCL to Vault policy `windows-kv-ro`:

`cat /tmp/windows-kv-ro.hcl | vault policy write windows-kv-ro -`

- map `vault-auth-group` AD group to policy `windows-kv-ro`

`vault write auth/ldap/groups/vault-auth-group policies=windows-kv-ro`

- verify

`vault list auth/ldap/groups`

## test

CLI

`vault login -method=ldap username=jray password=m8M34v-343v`

- success

```

[root@vault-oss-node tmp]# vault login -method=ldap username="jim ray" password=m8M34v-343v
Success! You are now authenticated. The token information displayed below
is already stored in the token helper. You do NOT need to run "vault login"
again. Future Vault requests will automatically use this token.

Key                    Value
---                    -----
token                  s.fL4hRRnZkqKsHpHnK7pkcq0j
token_accessor         MU4ctQFkEQx2khhisSdLEfvr
token_duration         768h
token_renewable        true
token_policies         ["default" "windows-kv-ro"]
identity_policies      []
policies               ["default" "windows-kv-ro"]
token_meta_username    jim ray

```

## troubleshooting

- wireshark on the Windows AD server you authenticating against

![diagram](/images/wireshark_failed_auth.png)

^^ this is a failed login attempt that ended with a `Code: 400. Errors: * ldap operation failed` error from Vault. the bind connection and initiatial search was successful, but then the flow stops.

![diagram](/images/wireshark_success_auth.png)

^^ this is a successful login attempt, notice the how the flow continues past the bind success of the failed flow...the next step being actually looking for the user in question and then associated groups.