# Vault Active Directory Check Out | Check In, Service Account Management, and AD Auth Walkthrough

- both Check-Out/In and Auth require a working Active Directory configuration
- the Check-Out | Check-Out workflow is based on a target set of accounts (library) that Vault will manage (blind rotation when account is "checked in")
- the Auth workflow is for authenticating to Vault using Active Directory accounts

## background and assumptions

- Windows Server 2016, Forest Win2016 Functional Level
- Vault 1.6 OSS or ENT
- Vault TLS Listener from separate CA than Windows Domain
## references

## build: Windows Prep

### create a "bind" user in AD

user `vaultbind` will be configured as the account that Vault will use to interact with Active Directory

- verify with dsquery (and capture connection string for Vault config)

`dsquery user -name vaultbind`

`"CN=vaultbind,CN=Users,DC=vault-lab,DC=home,DC=org"`

### create target service accounts that Vault will manage

sa00@vault-lab.home.org

sa01@vault-lab.home.org

`dsquery user -name servic*`

"CN=service account00,CN=Users,DC=vault-lab,DC=home,DC=org"
"CN=service account01,CN=Users,DC=vault-lab,DC=home,DC=org"

- verify with dsquery (and capture connection string for Vault config)

### create a group to target for auth (optional)

vault-auth-group

- verify with dsquery (and capture connection string for Vault config)

`dsquery group -name vault-auth*`

`"CN=vault-auth-group,CN=Users,DC=vault-lab,DC=home,DC=org"`

#### create a test user and add them to the group

Jim Ray (jray@vault-lab.home.org)

### prepare domain controller for LDAPS

**this is a required step to use LDAPS and all Active Directory functionality in your lab**

Step 1: Follow this guide to enable AD CS
https://pdhewaju.com.np/2016/04/08/installation-and-configuration-of-active-directory-certificate-services/

Step 2: Follow this guide to validate LDAPS
https://pdhewaju.com.np/2017/03/02/configuring-secure-ldap-connection-server-2016/

Step 3. Export the Windows CA certificate

[see](https://docs.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/hh831649(v=ws.11)

http://192.168.1.21/certsrv/certcarc.asp

Step 4. copy cert to the Vault server

`scp -i .ssh/jgrdubc /Users/jray/win-domain-ca-cert.cer jray@vault-ent-node-1:/home/jray/win-domain-ca-cert.cer`

Step 5. use openssl to convert from DER to PEM format

`openssl x509 -inform der -in /home/jray/win-domain-ca-cert.cer -out  /home/jray/win-domain-ca-cert.pem`

Step 6. move to a stable directory where Vault will consume the cert

`mkdir ~/win-domain-cert/`

`cp /home/jray/win-domain-ca-cert.pem ~/win-domain-cert/win-domain-ca-cert.pem`

- verify cert

`openssl x509 -in ~/win-domain-cert/win-domain-ca-cert.pem -text -noout`

## build: Vault Check-Out | Check-In Config

1. enable AD secret engine

`vault secrets enable ad`

2. configure AD secret engine

```
vault write ad/config \
binddn='CN=vaultbind,CN=Users,DC=vault-lab,DC=home,DC=org' \
bindpass='m8M34v-343v' \
url="ldaps://WIN-E4SBU33RUPV.vault-lab.home.org" \
certificate=@/home/jray/win-domain-cert/win-domain-ca-cert.pem \
userdn='CN=Users,DC=vault-lab,DC=home,DC=org' \
starttls=true \
insecure_tls=false
```

3. create a library

```
vault write ad/library/ops-team \
        service_account_names="sa00@vault-lab.home.org, sa01@vault-lab.home.org" \
        ttl=1h \
        max_ttl=12h
```

4. verify library

`vault read ad/library/ops-team/status`

5. check-out an account

`vault write -f ad/library/ops-team/check-out`

6. run through command scenarios (renew, revoke, etc)

https://www.vaultproject.io/docs/secrets/ad#service-account-check-out

## build: service account rotation

1. gather/create AD user that will be managed by Vault

application serviceaccount00
as00@vault-lab.home.org

2. set initial password for service account

< $up3rSecRet >

3. enable AD secret engine at path **sa-rotate**

`vault secrets enable -path sa-rotate ad`

4. configure AD secret engine

```
vault write sa-rotate/config \
binddn='CN=vaultbind,CN=Users,DC=vault-lab,DC=home,DC=org' \
bindpass='m8M34v-343v' \
url="ldaps://WIN-E4SBU33RUPV.vault-lab.home.org" \
certificate=@/home/jray/win-domain-cert/win-domain-ca-cert.pem \
userdn="DC=vault-lab,DC=home,DC=org" \
starttls=true \
insecure_tls=false
```
- validate config

`vault read sa-rotate/config`

5. map a Vault role (rotation policy) to the Windows Service Account

`vault write sa-rotate/roles/app00 service_account_name="as00@vault-lab.home.org"`

6. validate/fetch service account info

`vault read sa-rotate/roles/app00`

7. API test

export VAULT_TOKEN=s.tZ0kI2vW38fb5KzUMyDvnevQ

export VAULT_ADDR=https://vault-ent-node-1:8200

cat << EOF > ~/payload.json
{
  "service_account_name": "as00@vault-lab.home.org",
  "ttl": 1
}
EOF

- fetch password

```
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request GET \
    --data @payload.json \
    $VAULT_ADDR/v1/sa-rotate/creds/app00 | jq
```

## build: enable LDAP auth

1. enable LDAP auth at default mount

`vault auth enable ldap`

2. configure LDAP auth

- this config supports `sAMAccountName` attribute mapped to **userattr**, the short-form of the username (jray versus Jim Ray)

```
vault write auth/ldap/config \
url="ldaps://WIN-E4SBU33RUPV.vault-lab.home.org" \
binddn="CN=vaultbind,CN=Users,DC=vault-lab,DC=home,DC=org" \
bindpass='m8M34v-343v' \
starttls=true \
insecure_tls=false \
discoverdn=false \
deny_null_bind=true \
userattr="sAMAccountName" \
userdn="CN=Users,DC=vault-lab,DC=home,DC=org" \
groupfilter="(&(objectClass=person)(uid={{.Username}}))" \
groupattr="memberOf" \
groupdn="CN=vault-auth-group,CN=Users,DC=vault-lab,DC=home,DC=org" \
use_token_groups=true \
case_sensitive_names=true
```
3. create RO policy

```
cat << EOF > myapp-kv-ro.hcl
path "demo/*" {
capabilities = ["read", "list"]
}
EOF
```

4. assign RO policy

`vault write auth/ldap/groups/vault-auth-group policies=windows-kv-ro`

5. login

`vault login -method=ldap username="jray" password=m8M34v-343v`
