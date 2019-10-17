# Vault PKI Walkthrough

References:

https://medium.com/hashicorp-engineering/pki-as-a-service-with-hashicorp-vault-a8d075ece9a

Mike McRill
@Guy Barros you should be able to get the vault PKI intermediate setup to work pretty easily
just submit the CSR it generates to the MS root CA

## Goal

Configure Vault as a Intermediate CA from air-gapped, Windows Active Directory CA, and then use Consul Template to automatically renew and reset certificate for a webserver.

## Vault Configuration

- enable PKI engine at path adlab_int

`vault secrets enable -path=adlab_int pki`

- tune TTL for secrets issued from this mount to 5 years (equal or less than root TTL)

`vault secrets tune -max-lease-ttl=43800h adlab_int`

- generate CSR

`vault write adlab_int/intermediate/generate/internal common_name="vault.lab.org Intermediate Authority" ttl=43800h`

- manually copy CSR to text file locally on your workstation, add .pem extension

Key    Value
---    -----
csr    -----BEGIN CERTIFICATE REQUEST-----
MIICdDCCAVwCAQAwLzEtMCsGA1UEAxMkdmF1bHQubGFiLm9yZyBJbnRlcm1lZGlh
dGUgQXV0aG9yaXR5MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqt9J
rcoNaJjhM+qmum3VOPVuf/M+zURF+yq7COGc7lItD+7zIb0wO/uO0ITY/t3fc6Ba
b66eIYjD2SGb1sv4OJNjuSYBeufrguhpdzR4nU5V396BliJG7JE3lL9j1+ehV3Bo
QyQqRX1fd7ftx/qrqkd8qHVbLj54zcobxn9Lr7WB+ZHFqUKZdY3vHOH+DRLdpLoe
H+5/bHegVgCBpQisA6yUx+2o+ZPh1cHsitLn8mrKrNDY4+NKQlofOiQczWARWzFk
TYW3eD3w0VE7c5irkXQFW8fqtk8RzhzWu8l4uqptMdF5iyja5JoLqRBn+5LnRAwK
j5rMjfk89cq1x2kiBwIDAQABoAAwDQYJKoZIhvcNAQELBQADggEBAGIKm/rt09zo
DmkdO5z8zPZtEgM+iCcsHPabLVi5K4R6W5uMyJBh5uiqnEpfyinF/zNcopyPsNRX
UzPvODw2ruHm33T7rEezCxEoNld6LxIPNJD2CQy5qWOPMWdiRBKEaCW/OrkqyHfg
nG/Y5gv6AqZjE270lAbvKOJTeBfYGMmaZj1h3yh4coM2c2GBaZL0teEbaJqAKDzT
LeuUX6EXpY6xOhxYSyC79/uCYFb2MBe9nJA/fcyw9S9bqMmUHf/52Mk9Wg7f2XlD
rDQsneQPChEhVnd2A3AQJkgPnRuJ4VKAwTJlnOuK4jcPCKXOffVETNye+kT7X4DY
dEsvWMEJo84=
-----END CERTIFICATE REQUEST-----

## Windows CA Host

- copy .pem file to C:\csr

notes on Windows Certificate Applet/Configuration

1. suggest duplicating the default Certificate Template Subordinate Certificate Authority to create a dedicated template for Vault CSR
2. after creating new template, you must "publish it" https://itluke.online/2017/10/11/how-to-publish-a-certificate-template/
3. or you will get a funky error 0X80094800 CERTIFICATE NOT SUPPORTED BY CA https://itluke.online/2017/10/12/solved-0x80094800-certificate-not-supported-by-ca/

### use PowerShell CLI to import CSR against the template

```

cd c:\csr
certreq -submit -attrib "CertificateTemplate:VaultSubCATest" vault.pem

```

- Save Certificate prompt, save to c:\csr

### Certification Authority GUI, vault Intermediate CA cert is stored in Issued Certificates

- retrieve signed cert

-----BEGIN CERTIFICATE-----
MIIFQjCCBCqgAwIBAgITXAAAAAyK+wQdGPrJSwAAAAAADDANBgkqhkiG9w0BAQsF
ADBQMRMwEQYKCZImiZPyLGQBGRYDb3JnMRMwEQYKCZImiZPyLGQBGRYDbGFiMRIw
EAYKCZImiZPyLGQBGRYCYWQxEDAOBgNVBAMTB2Fkd2luY2EwHhcNMTkwNDEwMTQz
NDE5WhcNMjEwNDEwMTQ0NDE5WjAvMS0wKwYDVQQDEyR2YXVsdC5sYWIub3JnIElu
dGVybWVkaWF0ZSBBdXRob3JpdHkwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEK
AoIBAQCq30mtyg1omOEz6qa6bdU49W5/8z7NREX7KrsI4ZzuUi0P7vMhvTA7+47Q
hNj+3d9zoFpvrp4hiMPZIZvWy/g4k2O5JgF65+uC6Gl3NHidTlXf3oGWIkbskTeU
v2PX56FXcGhDJCpFfV93t+3H+quqR3yodVsuPnjNyhvGf0uvtYH5kcWpQpl1je8c
4f4NEt2kuh4f7n9sd6BWAIGlCKwDrJTH7aj5k+HVweyK0ufyasqs0Njj40pCWh86
JBzNYBFbMWRNhbd4PfDRUTtzmKuRdAVbx+q2TxHOHNa7yXi6qm0x0XmLKNrkmgup
EGf7kudEDAqPmsyN+Tz1yrXHaSIHAgMBAAGjggI0MIICMDAdBgNVHQ4EFgQU2rGC
VZhhmvqPCa2+JIWFh7Ji+V0wHwYDVR0jBBgwFoAUCbKSWXUtwFBy9VD12bunMgcr
gM0wgc8GA1UdHwSBxzCBxDCBwaCBvqCBu4aBuGxkYXA6Ly8vQ049YWR3aW5jYSxD
Tj1XSU4tNEs0VlNWMDVTTVIsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZp
Y2VzLENOPVNlcnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9YWQsREM9bGFiLERD
PW9yZz9jZXJ0aWZpY2F0ZVJldm9jYXRpb25MaXN0P2Jhc2U/b2JqZWN0Q2xhc3M9
Y1JMRGlzdHJpYnV0aW9uUG9pbnQwgbsGCCsGAQUFBwEBBIGuMIGrMIGoBggrBgEF
BQcwAoaBm2xkYXA6Ly8vQ049YWR3aW5jYSxDTj1BSUEsQ049UHVibGljJTIwS2V5
JTIwU2VydmljZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1hZCxE
Qz1sYWIsREM9b3JnP2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0
aWZpY2F0aW9uQXV0aG9yaXR5MA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQD
AgGGMD0GCSsGAQQBgjcVBwQwMC4GJisGAQQBgjcVCIWh4AKBp5JehuWfF4OavVmG
75caM4a5xRqBkY0bAgFkAgEFMA0GCSqGSIb3DQEBCwUAA4IBAQBDYeQ2xZNtbXMq
IGx6cyEea8BcBn5gPcF/YoKk0C4MwIIMr2fgGnQ7KEgJ0/E+JWvxezrMNKCgCV0A
WizmpZoT15FMKGUHbakGK14K5iZr+UHObQHs0Pzs3mXV5dPLaaDtpUY77sHEm09m
lWcchm/lc5xCFZveNKDEyH/r30+PJX05fNpiPYlGRYFjz7MmvHQq4MAZejI5Iw+D
3dtI+bV3NkQdD9hxPrplCu16R42njoDzpCF0StjG6Hm+QAXNQHFUUGUonN+sEbNz
gAfp1ta8f2BG/rJTr0Y2DpcpLV42e90jQFRmHP8TltztBd6T40dH06tjRzsLSyHo
r3WZ3euF
-----END CERTIFICATE-----

## Vault 

- create tmp\vault.pem

- copy contents of signed cert to vault.pem

- write signed cert back to vault

`vault write adlab_int/intermediate/set-signed certificate=@vault.pem`

set URL: Generated certificates can have the CRL location and the location of the issuing certificate encoded

```

vault write adlab_int/config/urls issuing_certificates="http://192.168.1.231:8200/v1/adlab_int/ca" crl_distribution_points="http://192.168.1.231:8200/v1/adlab_int/crl"

vault write adlab_int/config/urls issuing_certificates="http://<vault VIP>:8200/v1/adlab_int/ca" crl_distribution_points="http://<vault VIP>:8200/v1/adlab_int/crl"

vault read adlab_int/config/urls

curl http://127.0.0.1:8200/v1/adlab_int/crl > mycrl

openssl crl -inform DER -text -noout -in mycrl

```


**note** eventually you will use this command to watch the CRL update as certs are revoked:

`watch "curl -sS http://127.0.0.1:8200/v1/adlab_int/crl | openssl crl -inform DER -text -noout"`


### error to troubleshoot

```

sh: /v1/adlab_int/crl: No such file or directory
unable to load CRL
140350208882576:error:0D07207B:asn1 encoding routines:ASN1_get_object:header too long:asn1_lib.c:157:

```

- configure parameters for role that will be used by PKI consumers to generate certs

```

vault write adlab_int/roles/lab.org \
    allowed_domains=lab.org \
    allow_subdomains=true \
    max_ttl=5m \
    generate_lease=true

```
  
- create an policy with minimum access so users can create their own certs

```

nano adlab_int.hcl

vault policy write adlab_int adlab_int.hcl

path "adlab_int/*" {
      capabilities = ["create", "read", "list", "update"]
    }

    path "adlab_int/certs" {
      capabilities = ["list"]
    }

    path "adlab_int/revoke" {
      capabilities = ["create", "update"]
    }

    path "adlab_int/tidy" {
      capabilities = ["create", "update"]
    }

    path "auth/token/renew" {
      capabilities = ["update"]
    }

    path "auth/token/renew-self" {
      capabilities = ["update"]
    }

```

- create a test cert

`vault write adlab_int/issue/lab.org common_name=test.lab.org`

- test revocation

`vault write adlab_int/revoke serial_number="<serial of cert>"`


## nginx configuration

[reference](https://medium.com/hashicorp-engineering/pki-as-a-service-with-hashicorp-vault-a8d075ece9a)

- create token for nginx to use

`vault token create -policy=adlab_int -ttl=24h`

sample:

Key                  Value
---                  -----
token                <some token>
token_accessor       9Hjw3zKivbGwRLHFWT29yqVU
token_duration       24h
token_renewable      true
token_policies       ["adlab_int" "default"]
identity_policies    []
policies             ["adlab_int" "default"]


- create initial cert

`vault write adlab_int/issue/lab.org common_name=nginx.lab.org`

## nginx server

using Ubuntu 18 host with nginx installed and connectivity to Vault server, configure Consul Template and Vault Agent

- download and unzip consul-template and vault (for agent mode)

```

export CONSUL_TEMP_VERSION="0.22.0"
export VAULT_VERSION="1.2.0"

wget https://releases.hashicorp.com/consul-template/${CONSUL_TEMP_VERSION}/consul-template_${CONSUL_TEMP_VERSION}_linux_amd64.zip
unzip consul-template_${CONSUL_TEMP_VERSION}_linux_amd64.zip
sudo mv consul-template /usr/local/bin

wget https://releases.hashicorp.com/nomad/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip
unzip nomad_${VAULT_VERSION}_linux_amd64.zip
sudo mv vault /usr/local/bin

```

- consul template service

`sudo mkdir /etc/consul-template.d/; cd /etc/consul-template.d/`

### optional: Consul DNS

use this [guide](https://github.com/raygj/consul-content/tree/master/consul-dns) if you want to push name resolution of Vault active node to Consul

or just set hosts file:

```

sudo nano /etc/hosts

192.168.1.231   active.vault.service.consul

```

# create service definition

- create vault token env var

`export VAULT_TOKEN= < vault token using role created earlier >`

- create consul agent config

```

sudo nano /etc/consul-template.d/pki-demo.hcl

vault {
  address = "http://active.vault.service.consul:8200"
  token = "$VAULT_TOKEN" // set with export VAULT_TOKEN=
  grace = "1s"
  unwrap_token = false
  renew_token = true

  retry {
    enabled = true
    attempts = 5
    backoff = "250ms"
  }
}

syslog {
  enabled = true
  facility = "LOCAL5"
}

template {
  source      = "/etc/consul-template.d/lab-cert.tpl"
  destination = "/etc/nginx/certs/lab.crt"
  perms       = "0600"
  command     = "systemctl reload nginx"
}

template {
  source      = "/etc/consul-template.d/lab-key.tpl"
  destination = "/etc/nginx/certs/lab.key"
  perms       = "0600"
  command     = "systemctl reload nginx"
}

```

- create dir where cert will be stored

`sudo mkdir -p /etc/nginx/certs`

- create templates that will be used by consul template

`sudo nano /etc/consul-template.d/lab-cert.tpl`

```

{{- /* lab-cert.tpl */ -}}
{{ with secret "adlab_int/issue/lab.org" "common_name=nginx.lab.org"     "ttl=5m" }}
{{ .Data.certificate }}
{{ .Data.issuing_ca }}{{ end }}

```

`sudo nano /etc/consul-template.d/lab-key.tpl`

```

{{- /* lab-key.tpl */ -}}
{{ with secret "adlab_int/issue/lab.org" "common_name=nginx.lab.org" "ttl=5m"}}
{{ .Data.private_key }}{{ end }}

```

- systemd configuration

`sudo nano /etc/systemd/system/consul-template.service`

```

[Unit]
Description=consul-template
Requires=network-online.target
After=network-online.target

[Service]
EnvironmentFile=-/etc/sysconfig/consul-template
Restart=on-failure
ExecStart=/usr/local/bin/consul-template $OPTIONS -config='/etc/consul-template.d/pki-demo.hcl'
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target

```
- systemd commands

```

sudo systemctl daemon-reload
sudo systemctl enable consul-template.service
sudo systemctl start consul-template.service

```
- check service

`sudo systemctl status consul-template.service`

- watch for new certs to validate consul-template and vault integration is working

`sudo watch -n 15 ls -la /etc/nginx/certs`

assuming it is working, move on

### nginx configuration

if you have not already, install nginx: `sudo apt-get install nginx -y`

- configure nginx

`sudo nano /etc/nginx/sites-available/pki-demo`

- redirect traffic from http to https

```

server {
listen              80;
listen              [::]:80;
server_name         <NGINX_FQDN> www.<NGINX_FQDN>;
return 301          https://<NGINX_FQDN>$request_uri;
return 301          https://www.<NGINX_FQDN>$request_uri;
}

server {
    listen              443 ssl http2 default_server;
    server_name         <NGINX_FQDN> www.<NGINX_FQDN>;
    ssl_certificate     /etc/nginx/certs/<name of cert>.crt;
    ssl_certificate_key /etc/nginx/certs/<name of cert>.key;
    ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    location / {
      root   /usr/share/nginx/html;
      index  index.html index.htm;
    }
}

```

- example config from lab, redirect traffic from http to https:

```

server {
listen              80;
listen              [::]:80;
server_name         nginx.lab.org nginx.lab.org;
return 301          https://nginx.lab.org$request_uri;
return 301          https://$request_uri;
}

server {
    listen              443 ssl http2 default_server;
    server_name         nginx.lab.org nginx.lab.org;
    ssl_certificate     /etc/nginx/certs/lab.crt;
    ssl_certificate_key /etc/nginx/certs/lab.key;
    ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
    ssl_ciphers         HIGH:!aNULL:!MD5;

    location / {
      root   /usr/share/nginx/html;
      index  index.html index.htm;
    }
}

```

- enable site and remove default site

```

sudo ln -s /etc/nginx/sites-available/pki-demo /etc/nginx/sites-enabled/pki-demo

sudo rm /etc/nginx/sites-enabled/default

```

## demo

- you will need to install Vault's intermediate cert on the local workstation to avoid the browser invalid cert warning
- access nginx server and view the attached certificate
	- note the certificate expiration of 5 minutes
- for fun, customize the index.html with HashiCorp logos and a custom demo message:

```

sudo nano /usr/share/nginx/html/index.html

<!DOCTYPE html>
<html>
<img src="vault.jpg" alt="Vault Logo" style="width:128px;height:128px;">

<body>
<title>Welcome to the Vault-Consul-Template-Cert Demo!!</title>
<style>
    body {
        width: 35em;
        margin: 0 auto;
        font-family: Tahoma, Verdana, Arial, sans-serif;
    }
</style>
</head>
<body>
<h1>Welcome to the test page for Vault-Consul-Template-Cert Demo!</h1>
<p>If you see this page, the nginx  web server has been successfully configured
to use HTTPS redirect and consume the SSL cert being managed by Consul-Template
to reach out and grab a cert from Vault every 5 minutes.
<p>
If your browser threw a cert warning, then you need to install Vault's intermediate
CA cert on your local machine. On a Mac make sure you change the trust setting from
System Default to Always Trust.
</p>

<p>For online documentation and support please refer to
<a href="https://hashicorp.com">hashicorp.com</a>.<br/>
<img src="HashiCorp_Black.png" alt="HashiCorp Logo"style="width:128px;height:128px;">

</p>
</body>
</html>

```

### Vault API calls

set environment variable for $VAULT_TOKEN to a token with the PKI policy created earlier in the walkthrough

`export VAULT_TOKEN=< some token>`

- create cert

```

curl --header "X-Vault-Token: $VAULT_TOKEN" \
     --request POST \
     --data @nginx-test.json \
     http://192.168.1.231:8200/v1/adlab_int/issue/lab.org | jq

```

- force rotation

```

curl \
   --header "X-Vault-Token: $VAULT_TOKEN" \
   http://<VAULT_IP:8200>/v1/pki_int/crl/rotate | jq

```