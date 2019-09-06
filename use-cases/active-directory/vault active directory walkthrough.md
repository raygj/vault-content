# vault active directory walkthrough

https://www.vaultproject.io/docs/secrets/ad/index.html

## lab overview

- Windows Server 2016 VM (evals available from Microsoft or AWS Windows image)

- Vault instance (dev or existing cluster)

### windows AD setup

https://blogs.technet.microsoft.com/canitpro/2017/02/22/step-by-step-setting-up-active-directory-in-windows-server-2016/

#### high-level domain steps

deploy Windows 2016 instance
configure network adapter point to localhost for DNS
run server wizard, add roles for AD, DNS
setup domain
	ad.lab.org
	DSRM password: <>

## create domain users

### human domain admin

used to configured domain resources

jray: <password>

### vault priv service acct

used by vault to manage accounts

vault: <password>

### service account

this is the account that will be managed by Vault

mappsvc: <password>

## pull required info to configure Vault

use dsquery to determine the LDAP string

dsquery user -name v*
"CN=Vault Service,CN=Users,DC=ad,DC=lab,DC=org"

## vault setup

### secrets engine
vault secrets enable ad

### configure priv creds for Vault to communicate with AD

*note* if Active Directory is configured to communicate via TLS, you will need to use the secure configuration and provision a cert for Vault

### insecure

```

vault write ad/config \
    binddn='vault' \
    bindpass='<>' \
    url=ldap://192.168.1.229 \
    insecure_tls=true \
    starttls=false \
    userdn='DC=ad,DC=lab,DC=org'

```

### secure (requires TLS cert for AD and Vault)

```

vault write ad/config \
    binddn='vault' \
    bindpass='<>' \
    url=ldaps://192.168.1.229 \ //need to verify the "s" in ldaps
    userdn='DC=ad,DC=lab,DC=org'

```

## configure role in Vault

this maps to the `service account` in AD; not the account used by Vault to connect to AD; Vault will rotate this account's password

`vault write ad/roles/appsvc service_account_name="appsvc@ad.lab.org"`

in the future the Vault plugin may be updated to include CRUD operations for AD
    
## tests

### Vault CLI

`vault read ad/creds/appsvc`

### Vault API to retrieve password

create payload.json

```

cd tmp

nano payload.json

{
  "service_account_name": "mappsvc@ad.lab.org",
  "ttl": 100
}

```
   
### API calls

`export VAULT_TOKEN=< some token with appropriate policy/access>`

```

curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request GET \
    http://127.0.0.1:8200/v1/ad/creds/| jq

```

```    
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data @payload.json \
    http://127.0.0.1:8200/v1/ad/roles/appsvc

```