# Vault Active Directory  walkthrough

This is a walkthrough of the Vault integration with Windows Server 2016 Active Directory for Service Account secrets management as of Vault 1.2.x. Vault 1.3 beta [contains](https://github.com/hashicorp/vault/blob/master/CHANGELOG.md#13-unreleased) new Active Directory features that will build off this integration.

[reference:  Active Directory Secrets Engine](https://www.vaultproject.io/docs/secrets/ad/index.html)

## Environment

- Windows Server 2016 VM (evals available from Microsoft or AWS Windows image)
- Vault instance (dev or existing cluster)

### Windows AD setup

https://blogs.technet.microsoft.com/canitpro/2017/02/22/step-by-step-setting-up-active-directory-in-windows-server-2016/

#### high-level domain steps

- deploy Windows 2016 instance
- configure network adapter point to localhost for DNS
- run server wizard, add roles for AD, DNS
- setup domain, noting:
	- domain name, i.e., vault-lab.home.org
	- DSRM password
	- user with domain admin privileges

## Create AD Users

using account with domain admin privileges, create the following accounts

1. human domain admin

used to configured domain resources

jray: < password >

2. vault priv service acct

used by Vault to manage accounts

vaultadm: < password >

3. service account

this is the account that will be managed by Vault

appsvc1: < password >

### gather Active Directory details

use `dsquery` to determine the LDAP string of account used as `binddn` in the Vault AD engine configuration

```

PS C:\Users\Administrator> dsquery user -name vault*

"CN=vaultadm,CN=Users,DC=vault-lab,DC=home,DC=org"

```

## Vault Setup

1. enable AD secrets engine

`vault secrets enable ad`

2. configure priv creds for Vault to communicate with AD

*note* if using Windows 2016 Active Directory is configured to communicate via TLS, you will need to use the secure configuration and provision a cert for Vault

### secure LDAP (requires CA cert from Windows CA where AD resides)

```

vault write ad/config \
    binddn='vaultadm@vault-lab.home.org' \
    bindpass='m8M34v-343v' \
    url=ldaps://rootdc.vault-lab.home.org \
    certificate=@/home/vault/data/vault_lab_ca.pem \
    userdn='CN=Users,DC=vault-lab,DC=home,DC=org' \
    insecure_tls=false \
    starttls=true

```

**notes**

- `url` must use FQDN that matches `userdn` whcih must mactch the exact string of the CA cert used
- make sure you can resolve FQDN of `url` from the Vault server, if neccessary add an entry in the HOSTS file
- Rotate Root Credentials (binddn) password using [this procedure](https://www.vaultproject.io/api/secret/ad/index.html#rotate-root-credentials)

#### export/import of CA cert

[reference, Microsoft TechNet: enabling Secure LDAP](https://blogs.msdn.microsoft.com/microsoftrservertigerteam/2017/04/10/step-by-step-guide-to-setup-ldaps-on-windows-server/)

- in order for Vault to make the LDAPS connection, the CA cert must be presented:

export the cert (in demo lab, CA cert was exported in DER format from Windows Domain Controller acting as CA), copy to Vault server, convert from DER to PEM, copy to stable location in the filesystem

- export steps

1. In the AD server, launch the Certificate Authority application by Start | Run | certsrv.msc.
2. Right click the CA you created and select Properties.
3. On the General tab, click View Certificate button.
4. On the Details tab, select Copy to File.
5. Follow through the wizard, and select the DER Encoded binary X.509 (.cer) format.
6. Click browse and specify a path and filename to save the certificate.
7. Click  Next button and click Finish.

- copy to Vault server, then use openssl to convert from DER to PEM format

`openssl x509 -inform der -in /tmp/vault_lab_ca_3.cer -out /home/vault/data/vault_lab_ca.pem`

- chown to vault user being used by systemctl

`chown vault:vault /home/vault/data/vault_lab_ca.pem`

3. configure role in Vault

this maps to the `service account` in AD; not the account used by Vault to connect to AD; Vault will rotate this account's password

`vault write ad/roles/demo-app-svc service_account_name=appsvc1@vault-lab.home.org`

- where `/demo-app-svc` is the unique name of the app or service that is using the service account creds, in this case `appsvc1@vault-lab.home.org`
- Vault uses the `userPrincipalName` directory attribute in the form _user@somedomain.com_
- in the future the Vault plugin may be updated to include CRUD operations for AD, see Vault 1.3 beta changelog
    
## tests

### Vault CLI

this command will request Vault to create a new password for the bound service account; in our case `appsvc1`

`vault read ad/creds/demo-app-svc`

### Vault API to retrieve password

- set VAULT_TOKEN env var

`export VAULT_TOKEN=< some token with appropriate policy/access>`

- create payload.json

```

cat << EOF > /tmp/payload.json
{
  "service_account_name": "appsvc1@vault-lab.home.org",
  "ttl": 100
}
EOF

```
- get latest credential information

```    
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request GET \
    --data @payload.json \
    http://127.0.0.1:8200/v1/ad/roles/appsvc1

```

- output:

```

{
  "request_id": "d1b24486-c8b7-6af2-84d3-0d5320726a98",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 0,
  "data": {
    "password_last_set": "2019-11-10T20:45:41.1266883Z",
    "service_account_name": "appsvc1@vault-lab.home.org",
    "ttl": 100
  },
  "wrap_info": null,
  "warnings": null,
  "auth": null
}

```

- retrieve password

```

curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request GET \
    http://127.0.0.1:8200/v1/ad/creds/appsvc1
    
```

- output:

```

{
  "request_id": "23c36eff-f051-0f79-160e-d696fcae1a22",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 0,
  "data": {
    "current_password": "?@09AZBBUk4xOjWJbg3wExx/QAsCvCYSDi9d3fgorSpPNjWS0RD9gB3rxGKnu0vp",
    "username": "appsvc1"
  },
  "wrap_info": null,
  "warnings": null,
  "auth": null
}

```

# Troubleshooting

- DNS resolution of target LDAP server from Vault
- valid cert loaded on Vault
- invalid `userdn` path where service account is actually located in AD

## LDAP Result Code 53 Error

[reference LDAP error codes](https://ldapwiki.com/wiki/WILL_NOT_PERFORM)

if you receive this error:

```

[root@vault-oss-node ~]# vault read ad/creds/demo-app-svc
Error reading ad/creds/demo-app-svc: Error making API request.

URL: GET http://127.0.0.1:8200/v1/ad/creds/demo-app-svc
Code: 500. Errors:

1 error occurred:
LDAP Result Code 53 "Unwilling To Perform": 0000001F: SvcErr: DSID-031A1262, problem 5003 (WILL_NOT_PERFORM), data 0

```

more than likely this error is caused by using the insecure LDAP connection; new versions of Windows do not support password changes of insecure channels (there is no workaround or domain policy edit), suggest using the secure LDAP connection method.

## ldapsearch utility

CLI utility for probing LDAP, for example:

`ldapsearch -ZZ -H ldap://192.168.1.240:389 -D vaultadm@home.org -W -b DC=home,DC=org sAMAccountName=vaultadm`

# Appendix: Demo Service Account Password Rotation

- suggest using something like VNC Viewer for Windows to demo service account rotation - need a functional service that works with Local System for the Log On As account

[HashiCorp Consul Template - Windows Release 0.22.1](https://releases.hashicorp.com/consul-template/0.22.1/consul-template_0.22.1_windows_amd64.zip)

[painless-password-rotation preso](https://www.hashicorp.com/resources/painless-password-rotation-hashicorp-vault)

[painless-password-rotation repo](https://github.com/scarolan/painless-password-rotation/blob/master/files/rotate_windows_password.ps1)

# Appendix: API-based configuration

- set VAULT_TOKEN env var

`export VAULT_TOKEN=< some token with appropriate policy/access>`

- create payload.json

```

cat << EOF > /tmp/payload.json
{
  "service_account_name": "my-application@example.com",
  "ttl": 100
}
EOF

```
- get latest credential information

```    
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request GET \
    --data @payload.json \
    http://192.168.1.159:8200/v1/ad/roles/appsvc1

```

- output:

```

{
  "request_id": "e94a50a9-9f6e-9758-7edc-ff1629113a24",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 0,
  "data": {
    "last_vault_rotation": "2019-11-11T20:40:49.915151419Z",
    "password_last_set": "2019-11-11T20:40:49.7726369Z",
    "service_account_name": "appsvc1@vault-lab.home.org",
    "ttl": 100
  },
  "wrap_info": null,
  "warnings": null,
  "auth": null
}

```

# Appendix: Create a Windows Service

here are some quick steps to create a demo Windows service with the credentials created in this walkthrough (and subsequently managed by Vault)

## Demo Service

- use simple Go code to create Windows EXE [code here](https://golangcode.com/writing-to-file/)
- install Go for Windows
- create local `.go` file
- compile to EXE
- create dir `c:\vault-demo` and copy `vault-demo.exe` into this dir
- run EXE to write Hello World file

- download pre-compiled EXE from [here](https://github.com/raygj/vault-content/tree/master/use-cases/active-directory-service-account-mgmt/windows-exe/vault-demo)

### PowerShell New-Service

- code to create a service with `automatic startup` type

```

new-service -Name [INSERT SERVICE NAME] -DisplayName "[INSERT DISPLAY NAME]" -Description "[INSERT DESCRIPTION]" -BinaryPathName "[INSERT BINARY PATH]" -StartupType Automatic -Credential [INSERT CREDENTIALS]

```
- example

```

new-service -Name HashiCorp.Vault.Test.Service -DisplayName "HashiCorp Vault Demo Test Service" -Description "Test Service used for Vault Service Account demo" -BinaryPathName "C:\vault-demo\vault-demo.exe" -StartupType Automatic -Credential vault-lab\appsvc1


```

- once you enter the PowerShell command you will be prompted to enter a password, this may be the initial password you set on the account or the password Vault set
- if needed, pull the current password using an [API call](https://github.com/raygj/vault-content/tree/master/use-cases/active-directory-service-account-mgmt#vault-api-to-retrieve-password) 

![diagram](/images/ps_create_service.png)

- assuming you enter the correct password, the service will be created...but stopped - go ahead and start it

![diagram](/images/ps_service_success.png)