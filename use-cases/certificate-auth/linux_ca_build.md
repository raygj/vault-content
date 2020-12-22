#easy RSA certificate authority walkthrough
references
https://www.digitalocean.com/community/tutorials/how-to-set-up-and-configure-a-certificate-authority-ca-on-ubuntu-20-04

https://github.com/OpenVPN/easy-rsa/releases

https://www.spinup.com/install-openvpn-with-ubuntu-18-04/

##install
https://www.digitalocean.com/community/tutorials/how-to-set-up-and-configure-a-certificate-authority-ca-on-ubuntu-20-04

wget -P ~/ https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.8/EasyRSA-3.0.8.tgz

tar xvf EasyRSA-3.0.8.tgz

cd ~/EasyRSA-3.0.8

./easyrsa init-pki

##create CA

cd ~/EasyRSA-3.0.8

nano vars

set_var EASYRSA_REQ_COUNTRY    "US"
set_var EASYRSA_REQ_PROVINCE   "Penna"
set_var EASYRSA_REQ_CITY       "West Chester"
set_var EASYRSA_REQ_ORG        "homelab"
set_var EASYRSA_REQ_EMAIL      "bogus@home.lab"
set_var EASYRSA_REQ_OU         "lab"
set_var EASYRSA_ALGO           "ec"
set_var EASYRSA_DIGEST         "sha512"

./easyrsa build-ca

- enter passphrase
- enter DN or accept default
- ca.crt output to:

/home/jray/EasyRSA-3.0.8/pki/ca.crt

####create dirs for inbound and output signing activities

cd ~/EasyRSA-3.0.8

mkdir inbound_to_sign

mkdir outbound_signed

###copy CA to hosts and import

- copy ca.crt from CA to jumpbox or workstation, then shutdown the CA box ;-)
- distribute/copy ca.crt to servers and client machines as needed

scp -i .ssh/jgrdubc /Users/jray/lab_ca.crt jray@vault-ent-node-3c:/home/jray/



Ubuntu and Debian

sudo cp ~/lab_ca.crt /usr/local/share/ca-certificates/

sudo update-ca-certificates

RHEL and CentOS

sudo cp /tmp/lab_ca.crt /etc/pki/ca-trust/source/anchors/

sudo update-ca-trust

##create CSR

- openssl CSR (per node/cluster)
```
openssl req -new -sha256 -nodes -days 1095 -out \vault-node-1.csr -newkey rsa:2048 -keyout \vault-node-1.key -config <(
cat <<-EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn
[ dn ]
C=US
L=WestChester
CN = vault-ent-node-1.home.lab
[ req_ext ]
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = vault-ent-node-1
IP.0 = 192.168.1.249
IP.1 = 127.0.0.1
EOF
)
```

###Client Side Cert must have `extendedKeyUsage = clientAuth` to support client auth with Vault
if you attempted to configure Vault cert auth and received this error:

```
Error writing data to auth/cert/certs/web: Error making API request.

URL: PUT https://127.0.0.1:8200/v1/auth/cert/certs/web
Code: 400. Errors:

* non-CA certificates should have TLS client authentication set as an extended key usage
```

your client's certificate did not contain the `extendedKeyUsage = clientAuth` required for Vault to accept the cert.

####create a client cert
- generate CSR

openssl req -new -sha256 -nodes -days 1095 -out \vault-client.csr -newkey rsa:2048 -keyout \vault-client.key -config <(
cat <<-EOF
[req]
default_bits = 2048
prompt = no
default_md = sha256
req_extensions = req_ext
distinguished_name = dn
[ dn ]
C=US
L=WestChester
CN = vault-client
[ req_ext ]
subjectAltName = @alt_names
[ alt_names ]
DNS.1 = vault-ent-node-1
IP.0 = 192.168.1.211
IP.1 = 127.0.0.1
EOF
)

- move CSR and KEY to CA for signing

scp -i .ssh/jgrdubc jray@vault-client:/home/jray/vault-client.csr /Users/jray
scp -i .ssh/jgrdubc jray@vault-client:/home/jray/vault-client.key /Users/jray

- sign CSR using `client` openssl profile contain in ~/EasyRSA-3.0.8/x509-types


- verify CSR

openssl req -in vault-client.csr -noout -subject

- scp CSR off box and transfer to CA for signing

scp -i .ssh/jgrdubc jray@vault-ent-node-3a:/home/jray/vault-node-3.csr /Users/jray


scp -i .ssh/jgrdubc jray@vault-ent-node-3a:/home/jray/vault-cluster-3.csr /Users/jray
scp -i .ssh/jgrdubc jray@vault-ent-node-3a:/home/jray/vault-cluster-3.key /Users/jray

scp -i .ssh/jgrdubc jray@vault-client:/home/jray/vault-client.csr /Users/jray
scp -i .ssh/jgrdubc jray@vault-client:/home/jray/vault-client.key /Users/jray


- scp CSR to CA

scp -i .ssh/jgrdubc /Users/jray/vault-cluster-3.csr jray@vault-ent-lab-ca:/home/jray/EasyRSA-3.0.8/inbound_to_sign/vault-cluster-3.csr

scp -i .ssh/jgrdubc /Users/jray/vault-client.csr jray@vault-ent-lab-ca:/home/jray/EasyRSA-3.0.8/inbound_to_sign/vault-client.csr

##sign CSR

ssh -i .ssh/jgrdubc jray@vault-ent-lab-ca

cd ~/EasyRSA-3.0.8/

- import csr into easy-rsa

./easyrsa import-req ~/EasyRSA-3.0.8/inbound_to_sign/vault-client.csr vault-client

- sign the request for a server

./easyrsa sign-req server vault-ent-node-1

- sign the request for a client

./easyrsa sign-req client vault-client

- signed cert output to default folder

/home/jray/EasyRSA-3.0.8/pki/issued/vault-node-1.crt

- scp signed cert from CA to workstation

scp -i .ssh/jgrdubc jray@vault-ent-lab-ca:/home/jray/EasyRSA-3.0.8/pki/issued/vault-cluster-3.crt /Users/jray/vault-cluster-3.crt

scp -i .ssh/jgrdubc jray@vault-ent-lab-ca:/home/jray/EasyRSA-3.0.8/pki/issued/vault-client.crt /Users/jray/vault-client.crt

- scp signed cert back to Vault node(s)

scp -i .ssh/jgrdubc /Users/jray/vault-cluster-3.crt jray@vault-ent-node-3a:~/



scp -i .ssh/jgrdubc /Users/jray/vault-client.crt jray@vault-client:~/
scp -i .ssh/jgrdubc /Users/jray/vault-client.key jray@vault-client:~/


scp -i .ssh/jgrdubc /Users/jray/vault-cluster-3.crt jray@vault-ent-node-3c:~/
scp -i .ssh/jgrdubc /Users/jray/vault-cluster-3.key jray@vault-ent-node-3c:~/




scp -i .ssh/jgrdubc jray@vault-ent-node-3:/home/jray/vault-node-3.key /Users/jray/vault-node-3.key

scp -i .ssh/jgrdubc /Users/jray/vault-node-3.key jray@vault-ent-node-3c:~/
