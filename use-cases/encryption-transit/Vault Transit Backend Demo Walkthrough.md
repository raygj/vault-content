# Transit Backend: Encryption as a Service

## Purpose

Walkthrough Vault Encryption as a Service (EaaS) use case in a lab environment consisting of a Vault cluster and demo application.

## Lab Environment

vaultnodea		CentOS7			Vault Ent 1.2.2

vaultnodeb		CentOS7			Vault Ent 1.2.2

transit-demo	Ubuntu 18.4		MySQL/Go app server (referred to as the Go App VM)

![diagram](/use-cases/encryption-transit/images/consul_lab.png)

## References

[learn.hashicorp](https://learn.hashicorp.com/vault/encryption-as-a-service/eaas-transit)

[transit example app](https://github.com/norhe/vault-transit-datakey-example)

# High Level Steps

## Demo App Server

- Ubuntu VM Bootstrap
- Clone Git repo
- Docker MySQL instance
- Start Go app that interacts with local DB and remote Vault server

## Vault

- Configure Transit Secret Engine

# Walkthrough

## Host Bootstrapping

- Ubuntu host

```
sudo apt install jq -y
sudo apt install unzip -y
sudo apt install bind-utils -y
sudo apt install nmap -y

```

### Install Go and Setup Path

For background info, see this [Digital Ocean Walkthrough.](https://www.digitalocean.com/community/tutorials/how-to-install-go-on-ubuntu-18-04)

#### Install Go

`cd ~`

`curl -O https://dl.google.com/go/go1.12.9.linux-amd64.tar.gz`

`tar xvf go1.12.9.linux-amd64.tar.gz`

`sudo chown -R root:root ./go`

`sudo mv go /usr/local`

#### Setup Path

`sudo nano ~/.profile`

```

export GOPATH=$HOME
export PATH=$PATH:/usr/local/go/bin:$GOPATH/bin

```

`source ~/.profile`

### Clone Git repo

`mkdir ~/src/github.com/norhe/; cd ~/src/github.com/norhe/`

`git clone https://github.com/norhe/vault-transit-datakey-example.git`

#### Workaround for Updated Source Files

Merge pending on a change to `/secure/vaultUtils.go` replace this file with a new copy from [here](https://github.com/raygj/vault-content/blob/master/use-cases/encryption-transit/vault-transit-datakey-example/secure/vaultUtils.go)

Grab 

### Using Consul Discovery to Locate Vault Service

Optionally, setup Consul client to perform DNS queries to find active Vault server. Follow this [guide.](https://github.com/raygj/consul-content/blob/master/consul-dns/using%20consul%20DNS%20walkthrough.md)

## MySQL

- Pull Docker container

`sudo docker pull mysql/mysql-server:5.7`

- Create target directory

`mkdir ~/transit-data`

- Start container with set values for `MYSQL_ROOT_PASSORD, MYSQL_DATABASE, MYSQL_PASSWORD`

```
sudo docker run --name mysql-transit \
  -p 3306:3306 \
  -v ~/transit-data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_ROOT_HOST=% \
  -e MYSQL_DATABASE=my_app \
  -e MYSQL_USER=vault \
  -e MYSQL_PASSWORD=vaultpw \
  -d mysql/mysql-server:5.7

```

### On Go App VM: Validate Container Status

`sudo docker ps`

`sudo docker logs --tail 100 mysql-transit`

Assuming the container is up and everything is running clean, move on...otherwise troubleshoot the MySQL instance.

## On Vault VM: Vault Transit Configuration

Assumption is a root token will be used for the demo, in all our non-demo situations, a proper policy with _least privilege_ is created and used to consume EaaS via the Transit Backend. [Guide on transit policy requirements](https://learn.hashicorp.com/vault/encryption-as-a-service/eaas-transit#policy-requirements)

*NOTE:*: Vault can encrypt a binary file such as an image. When you encrypt plaintext, it must be base64 encoded.

*NOTE:*: Vault does NOT store any data encrypted via the transit/encrypt endpoint. The output you received is the ciphertext. You can store this ciphertext at the desired location (e.g. MySQL database) or pass it to another application.

- Enable Transit Backend 

(alternatively, use the `-path` argument to mount the backend at a specific point/name)

`vault secrets enable transit`

- Create key ring named *my_app_key*

`vault write -f transit/keys/my_app_key`

## : Setup and Run Go Application

### Setup environment

`export VAULT_ADDR=< valid IP/FQDN or Consul FQDN>`

*NOTE:* if you are using Consul DNS, you would specify the Vault server FQDN as _active.vault.service.consul_

`export VAULT_TOKEN=<valid Vault token with appropriate policy>`

### Run App

`cd ~/src/github.com/norhe/vault-transit-datakey-example`

`go run main.go`


#### If you encounter missing packages for MySQL and Vault:

`go get -u github.com/go-sql-driver/mysql`

`go get -u github.com/hashicorp/vault/api`

*NOTE:* Go and Ruby are the HashiCorp supported client libraries for Vault, however, [libraries are available](https://www.vaultproject.io/api/libraries.html) for _most_ (if not all) popular languages.

# Demo Time

## Test Access App

http://<IP or hostname>:1234

![diagram](/use-cases/encryption-transit/images/Secure_App_Homepage.png)

## Create Data

Enter information from the web form, include an attachment...such as a HashiCorp logo :-) ![diagram](/use-cases/encryption-transit/images/hashicorp_graphic.jpg)

## View Encrypted Data on the Backend DB

On Go App VM:

- Connect to MySQL

`sudo docker exec -it mysql-transit mysql -uroot -proot`

- Change to my_app database

`USE my_app;`

- Observe "address" field is encrypted

`SELECT * FROM user_data LIMIT 10;`

- Show the attached file

`SELECT user_id, file_id, mime_type, file_name FROM user_files LIMIT 10;`

### Decrypt Data in Vault UI

- Copy encrypted strings from database record, for example:

`vault:v1:wXTyPJTEujrwFj23dCpO05rv+zMvy5qMkkWqZBnNNpx7AjQCds6C47nfkg==`

- Go to Vault UI and browse to the transit secret engine you are using, for example:

`secrets > transit > my_app_key > decrypt`

- Paste the encrypted string (including the **vault:v1:** prefix into the `ciphertext` field

Click `decrypt`

A base64 encoded string is returned, click `decode from base64`

The original text from the web form is returned

# Appendix - Extra Stuff Of Interest

## Script to take input of data to encode and set as env var

Use case is outside the scope of this guide, but as a means of encoding data and grabbing it for encryption operations.

[see this background info on base64 decode operations](https://linuxhint.com/bash_base64_encode_decode/)

```
cat << EOF > /tmp/b64encode.sh
#!/bin/bash
echo "Enter Some text to encode"
read text
etext=`echo -n $text | base64`
echo "Encoded text is : $etext"
EOF
```

`bash /tmp/b64encode.sh`

## CLI command to encode and set output as env var

- this worked w/o syntax error but did not set the env var

`export ENCODED_PII= "$(base64 <<< "4111-1111-1111-1111")"`

```
    curl --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data '{"plaintext": "$ENCODED_PII"}' \
    https://active.vault.service.consul:8200/v1/transit/encrypt/eaas_pii | jq

```

- these did not work:

```
export ENCODED_PII= "$(echo `4111-1111-1111-1111` | base64)"

ENCODED_PII=`echo -n $text | base64`

```

### EaaS via CLI

- Encrypt dummy credit card number 4111 1111 1111 1111

`vault write transit/encrypt/my_app_key plaintext=$(base64 <<< "4111 1111 1111 1111")`

- Decrypt cipher string

`vault write transit/decrypt/my_app_key ciphertext="vault:v1: < encrypted string>"`

- Decode decrypted string

`base64 --decode <<< "< base64 encoded string>"`

### EaaS via API

- Vault token set as env var

`export VAULT_TOKEN= < your token >`

- Encrypt dummy credit card number 4111 1111 1111 1111

	- generate base64-encoded plaintext

`base64 <<< "4111 1111 1111 1111"`

- pass the base64-encoded plaintext as API payload

```
    curl --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data '{"plaintext": "< base64 encoded output>"}' \
    https://active.vault.service.consul:8200/v1/transit/encrypt/my_app_key  | jq

```

- Decrypt 

```
       curl --header "X-Vault-Token: $VAULT_TOKEN" \
       --request POST \
       --data '{"ciphertext": "< encrypted cipher text>"}' \
       https://active.vault.service.consul:8200/v1/transit/decrypt/orders | jq

```