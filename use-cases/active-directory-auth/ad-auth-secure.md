# Vault Active Directory Authentication

## Vault Setup

### enable ldap auth method:

`vault auth enable ldap`

### Vault config using secure LDAP

- configure connection to active directory using variables for username, password, userdn
	- this requires an active directory account with appropriate privileges
- assumes secure ldap, TLS, is enabled
- assumes CA cert exported from Windows Domain controller and imported to Vault server, see [HERE](https://github.com/raygj/vault-content/tree/master/use-cases/active-directory-service-account-mgmt#secure-ldap-requires-ca-cert-from-windows-ca-where-ad-resides)

```

vault write auth/ldap/config \
	binddn=${USERNAME} bindpass=${PASSWORD} \
	url="ldaps://vault-ad-test.vault-ad-test.net:636" \
	userdn=${USERDN} \
	userattr="cn"\
	certificate=@vault-ad-test.cer\
	groupfilter="(&(objectClass=group) \
	(member:1.2.840.113556.1.4.1941:={{.UserDN}}))"\
	groupdn=${USERDN}\
	groupattr="cn"

```

### test using ldapsearch utility

```

ldapsearch -H ldaps://vault-ad-test.vault-ad-test.net:636 -D \
"vault-admin@vault-ad-test.net" -w "Test12345678" -b "CN=Users,DC=vault-ad-test,DC=net" \
"(&(objectClass=group)(memberOf:1.2.840.113556.1.4.1941:=CN=vault-ad-test,CN=Users,DC=vault-ad-test,DC=net))"

```

### configure login method for vault-ad-test user

`vault login -method=ldap username=vault-ad-test`

### bind active directory group

`vault write auth/ldap/groups/"Domain Admins" name="Domain Admins" policies=foo,bar`

## API call to verify configuration

`export VAULT_TOKEN=< some token >`

`export VAULT_ADDR=https://< some address/name >:8200`

```
curl \
    --header "X-Vault-Token:${VAULT_TOKEN}" \
    --request LIST \
    ${VAULT_ADDR}/v1/auth/ldap/groups | jq
```
