# Vault Active Directory Check In | Check Out, Service Account Managment, and AD Auth Walkthrough
- both Check-In and Auth require a working Active Directory configuration, so both workflows are presented since end users will auth to Vault with AD, then access Service Accounts managed by Vault
- the Check-In | Check-Out workflow is based on a target set of accounts that Vault will manage (rotate password based on admin-define TTLs)
- the Auth workflow is for authenticating to Vault, via Active Directory

## background and assumptions
- Windows Server 2016, Forest Win2016 Functional Level
- Vault 1.6 OSS or ENT
- Vault TLS Listener from separate CA than Windows Domain
## references

## build: Windows Prep

### create a "bind" user in AD

vaultbind

- verify with dsquery (and capture connection string for Vault config)

`dsquery user -name vaultbind`

`"CN=vaultbind,CN=Users,DC=vault-lab,DC=home,DC=org"`

### create target service accounts that Vault will manage

sa00@vault-lab.home.org
sa01@vault-lab.home.org

```
`dsquery user -name servic*`

"CN=service account00,CN=Users,DC=vault-lab,DC=home,DC=org"
"CN=service account01,CN=Users,DC=vault-lab,DC=home,DC=org"
```

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

Step 5. copy cert to the Vault server

`scp -i .ssh/jgrdubc /Users/jray/win-domain-ca-cert.cer jray@vault-ent-node-1:/home/jray/win-domain-ca-cert.cer`

Step 6. use openssl to convert from DER to PEM format

`openssl x509 -inform der -in /home/jray/win-domain-ca-cert.cer -out  /home/jray/win-domain-ca-cert.pem`

Step 7. move to a stable directory where Vault will consume the cert

`mkdir ~/win-domain-cert/`

`cp /home/jray/win-domain-ca-cert.pem ~/win-domain-cert/win-domain-ca-cert.pem`

- verify cert

`openssl x509 -in ~/win-domain-cert/win-domain-ca-cert.pem -text -noout`

## build: Vault Check-In | Check-Out Config

1. enable AD secret engine

`vault secrets enable ad`

2. configure AD secret engine

```
vault write ad/config \
binddn='vaultbind@vault-lab.home.org' \
bindpass='m8M34v-343v' \
url="ldaps://WIN-E4SBU33RUPV.vault-lab.home.org" \
userdn='CN=Users,DC=vault-lab,DC=home,DC=org' \
starttls=true \
insecure_tls=false
```

3. create a library (using disable_check_in_enforcement to allow operator to force check in)

```
vault write ad/library/ops-team \
        service_account_names="sa00@vault-lab.home.org, sa01@vault-lab.home.org" \
        ttl=1h \
        max_ttl=2h \
        disable_check_in_enforcement=true
```

4. verify library

`vault read ad/library/ops-team/status`

5. check-out an account

`vault write -f ad/library/ops-team/check-out`

6. run through command scenarios (renew, revoke, etc)

https://www.vaultproject.io/docs/secrets/ad#service-account-check-out

### API workflow

- prepare vault client

```
export VAULT_ADDR=
export VAULT_TOKEN=
```

- check out account:

```
curl --header "X-Vault-Token: $VAULT_TOKEN" \
--request POST \
$VAULT_ADDR/v1/ad/library/ops-team/check-out | jq
```

- view library status

```
curl --header "X-Vault-Token: $VAULT_TOKEN" \
--request POST \
$VAULT_ADDR/v1/ad/library/ops-team/status | jq
```

- check-in account

```
curl --header "X-Vault-Token: $VAULT_TOKEN" \
--request POST \
$VAULT_ADDR/v1/ad/library/ops-team/check-in | jq
```

  - if "disable_check_in_enforcement" was set to active on the library, then an operator can "force" check-in accounts even though that client did not check-out the account(s)

```
curl --header "X-Vault-Token: $VAULT_TOKEN" \
--request POST \
$VAULT_ADDR/v1/ad/library/manage/ops-team/check-in | jq
```

  - target an account if more than one is checked out by that Vault client

```
cat << EOF > sa_list.json
{
  "service_account_names": ["as00@vault-lab.home.org","as01@vault-lab.home.org",]
}
EOF
```

```
curl --header "X-Vault-Token: $VAULT_TOKEN" \
--request POST \
--data @sa_list.json \
$VAULT_ADDR/v1/ad/library/ops-team/check-in | jq
```

## build: service account rotation

1. gather/create AD user that will be managed by Vault

application serviceaccount00
as00@vault-lab.home.org

2. set initial password for service account

< $up3rSecRet >

3. enable AD secret engine at path **sa-rotate**

`vault secrets enable -path sa-rotate ad`

3. configure AD secret engine

```
vault write sa-rotate/config \
binddn='vaultbind@vault-lab.home.org' \
bindpass='m8M34v-343v' \
url="ldaps://WIN-E4SBU33RUPV.vault-lab.home.org" \
userdn="DC=vault-lab,DC=home,DC=org" \
starttls=true \
insecure_tls=false
```

4. map a Vault role (rotation policy) to the Windows Service Account

`vault write sa-rotate/roles/app00 service_account_name="as00@vault-lab.home.org"`

5. validate/fetch service account info

`vault read sa-rotate/roles/app00`

6. API test

export VAULT_TOKEN=s.tZ0kI2vW38fb5KzUMyDvnevQ

export VAULT_ADDR=https://vault-ent-node-1:8200

cat << EOF > ~/payload.json
{
  "service_account_name": "as00@vault-lab.home.org",
  "ttl": 1
}
EOF

- fetch password

curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request GET \
    --data @payload.json \
    $VAULT_ADDR/v1/sa-rotate/creds/app00 | jq

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
4. create RO policy

```
cat << EOF > myapp-kv-ro.hcl
path "demo/*" {
capabilities = ["read", "list"]
}
EOF

5. assign RO policy

`vault write auth/ldap/groups/vault-auth-group policies=windows-kv-ro`

6. login

`vault login -method=ldap username="jray" password=m8M34v-343v`
