# Transit Backend: Encryption as a Service

## Purpose

Walkthrough Vault Encryption as a Service (EaaS) use case in a lab environment consisting of a Vault cluster and demo application.

## Lab Environment

vaultnodea		CentOS7			Vault Ent 1.1.2
vaultnodeb		CentOS7			Vault Ent 1.1.2
transit-demo	Ubuntu 18.4		MySQL/Go app

## References

[learn.hashicorp](https://learn.hashicorp.com/vault/encryption-as-a-service/eaas-transit)

[transit example app](https://github.com/norhe/vault-transit-datakey-example)

# High Level Steps

## Demo App Server
- Ubuntu VM Bootstrap
- Clone Git repo
- Docker MySQL instance
- Basic Go app to interact with DB

## Vault
- Configure Transit Secret Engine
- Encrypt Secrets

### Optional
- Decrypt a cipher-text
- Rotate the Encryption Key
- Update Key Configuration
- Generate Data Key

# Walkthrough

## Host Bootstrapping
- Ubuntu host
```
sudo apt install jq -y
sudo apt install unzip -y
sudo apt install bind-utils -y
sudo apt install nmap -y
sudo apt install  -y

```
- Go installed and set in path

[digital ocen walkthrough](https://www.digitalocean.com/community/tutorials/how-to-install-go-on-ubuntu-18-04)

- Clone Git repo

`mkdir ~/demo-app; cd ~/demo-app`

`git clone https://github.com/norhe/vault-transit-datakey-example.git`

## Use Consul DNS to Find Active Vault Node

[learn.hashicorp](https://learn.hashicorp.com/consul/security-networking/forwarding)

[consul dns info](https://www.consul.io/docs/agent/dns.html)

### Install and Configure Consul

```
mkdir ~/consul; cd ~/consul

wget https://releases.hashicorp.com/consul/1.5.1/consul_1.5.1_linux_amd64.zip

unzip consul_1.5.1_linux_amd64.zip
```

- add consul to path

```
# consul

echo 'export PATH=$PATH:~/consul' >> ~/.profile

source ~/.profile \\ centos, need verify ubuntu

consul -autocomplete-install

complete -C /usr/local/bin/consul consul
```

- setup data and log dirs

```
mkdir ~/consul/data

mkdir ~/consul/log/

touch ~/consul/log/output.log
  ```

### Setup Firewall

`su root`

- create firewalld service definition for consul ports

```

cat << EOF > /etc/firewalld/services/consul.xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>Consul</short>
  <description>TCP connectivity required for HashiCorp Consul cluster communication.</description>
  <port protocol="tcp" port="8300"/>
  <port protocol="tcp" port="8301"/>
  <port protocol="udp" port="8301"/>  
  <port protocol="tcp" port="8302"/>
  <port protocol="udp" port="8302"/>  
  <port protocol="tcp" port="8500"/>
  <port protocol="tcp" port="8600"/>
  <port protocol="udp" port="8600"/>
</service>
EOF

```
- identify default zone

`firewall-cmd --get-default-zone # identify the default zone`

- add custom services to default zone (assumes the zone is _public_)

```

firewall-cmd --zone=public --add-service=consul --permanent
firewall-cmd --zone=public --add-service=https --permanent
firewall-cmd --zone=public --add-service=http --permanent

```
- reload firewalld

`firewall-cmd --complete-reload`

### Start Consul

- start consul agent as background process

`~/consul/consul agent -data-dir="~/consul/data" -bind=192.168.1.xxx -client=192.168.1.xxx >> ~/consul/log/output.log &`

- join existing consul cluster/DC

`~/consul/consul join -http-addr=192.168.1.xxx:8500 192.168.1.231`

- verify join on consul cluster
`curl http://192.168.1.xxx:8500/v1/agent/members?segment=_all | jq`

- validate consul DNS from client
`dig @192.168.1.xxx -p 8600 active.vault.service.consul. A`

## Resolving Consul DNS from host

_goal is to get native OS resolution of *consul records_

- there are several options there:

1. BIND server setup to forward _consul_ domain queries to Consul cluster
2. Windows server setup as primary DNS server, using _conditional forwarder_ to push _consul_ domain queries to BIND
3. Host running Consul agent with configuration to forward Consul DNS queries to Consul agent on port 8600 [use learn.hashicorp guide](https://learn.hashicorp.com/consul/security-networking/forwarding)

- options 1 and 2 are covered in a separate [guide](https://github.com/raygj/consul-content/blob/master/consul-dns/consul%20DNS%20BIND%20walkthrough.md)
- option 3 is covered in the next section for CentOS7, Ubuntu 18.04, Windows Server 2016

### Option 3: dnsmasq utility

**Ubuntu 18.04 Steps**

#### configure primary LAN connection to not use DHCP-provided DNS server and to search the _*consul_ domain

- baseline existing DNS status

`sudo systemd-resolve --status`

- stop and disable systemd-resolved

```
sudo systemctl disable systemd-resolved

sudo systemctl stop systemd-resolved

```

- remove symlinked `resolve.conf` file

```
ls -lh /etc/resolv.conf

sudo rm /etc/resolv.conf

```

- create new resolve.conf file

`sudo nano /etc/resolv.conf`

- enter minimum configuration

`nameserver 127.0.0.1`

- save and exit file, then restart network service

`sudo netplan apply`

- install dnsmasq

`sudo apt install dnsmasq -y`

- create dnsmasq config

`sudo nano /etc/dnsmasq.d/10-consul`

- drop the following into the file; this identifies the consul agent DNS listener on port 8600 and applicable CIDRs for reverse DNS

```
server=/consul/192.168.1.xxx#8600 # this is the address of the host running dnsmasq
server=192.168.1.yyy # this is your local, default DNS server for non-Consul domains

no-resolv
log-queries

# Uncomment and modify as appropriate to enable reverse DNS lookups for
# common netblocks found in RFC 1918, 5735, and 6598:

rev-server=192.168.0.0/16,192.168.1.xxx#8600 # this is the address of the host running dnsmasq

#rev-server=0.0.0.0/8,127.0.0.1#8600
#rev-server=10.0.0.0/8,127.0.0.1#8600
#rev-server=100.64.0.0/10,127.0.0.1#8600
#rev-server=127.0.0.1/8,127.0.0.1#8600
#rev-server=169.254.0.0/16,127.0.0.1#8600
#rev-server=172.16.0.0/12,127.0.0.1#8600
#rev-server=224.0.0.0/4,127.0.0.1#8600
#rev-server=240.0.0.0/4,127.0.0.1#8600

```

- save and exit file, then restart dnsmasq process

`sudo systemctl restart dnsmasq`

- test DNS resolution

`ping active.vault.service.consul`

**CentOS Steps**

#### configure primary LAN connection to not use DHCP-provided DNS server and to search the _*consul_ domain

- backup, then modify network-script
- ifcfg-ens*** where "*** = your adapter number"

```
sudo cp /etc/sysconfig/network-scripts/ifcfg-ens192 /etc/sysconfig/network-scripts/ifcfg-ens192.backup

sudo nano /etc/sysconfig/network-scripts/ifcfg-ens192

```

- modify/add

```
PEERDNS=NO
DOMAIN=consul

```

- save and exit

- restart network service

`sudo systemctl restart network`

##### install and configure dnsmasq utility that will handle all name resolution for OS

_this configuration will push *consul queries to the local Consul agent on port 8600 and all other queries to another DNS server on port 53_

- install dnsmasq

`sudo yum install dnsmasq -y`

- backup default config file

`sudo mv /etc/dnsmasq.conf /etc/dnsmasq.conf.orig`

- create dnsmasq config

`sudo nano /etc/dnsmasq.conf`

- drop the following into the file; this identifies the consul agent DNS listener on port 8600 and applicable CIDRs for reverse DNS

```

server=/consul/192.168.1.xxx#8600 // this is the address of the host running dnsmasq
server=192.168.1.yyy // this is your local, default DNS server for non-Consul domains

no-resolv
log-queries

# Uncomment and modify as appropriate to enable reverse DNS lookups for
# common netblocks found in RFC 1918, 5735, and 6598:

rev-server=192.168.0.0/16,192.168.1.xxx#8600

#rev-server=0.0.0.0/8,127.0.0.1#8600
#rev-server=10.0.0.0/8,127.0.0.1#8600
#rev-server=100.64.0.0/10,127.0.0.1#8600
#rev-server=127.0.0.1/8,127.0.0.1#8600
#rev-server=169.254.0.0/16,127.0.0.1#8600
#rev-server=172.16.0.0/12,127.0.0.1#8600
#rev-server=224.0.0.0/4,127.0.0.1#8600
#rev-server=240.0.0.0/4,127.0.0.1#8600


```

- save and exit file, then restart dnsmasq process

`sudo systemctl restart dnsmasq`


- check dnsmasq status before testing

`sudo systemctl status dnsmasq`

_sample status, notice the two bindings from the config for 1.193#8600 and 1.1#53 respectively_

```
[jray@consul-lab01 ~]$ sudo systemctl status dnsmasq
● dnsmasq.service - DNS caching server.
   Loaded: loaded (/usr/lib/systemd/system/dnsmasq.service; disabled; vendor preset: disabled)
   Active: active (running) since Tue 2019-07-09 14:12:51 EDT; 3s ago
 Main PID: 9069 (dnsmasq)
   CGroup: /system.slice/dnsmasq.service
           └─9069 /usr/sbin/dnsmasq -k

Jul 09 14:12:51 consul-lab01 systemd[1]: Started DNS caching server..
Jul 09 14:12:51 consul-lab01 dnsmasq[9069]: started, version 2.76 cachesize 150
Jul 09 14:12:51 consul-lab01 dnsmasq[9069]: compile time options: IPv6 GNU-getopt DBus no-i18n IDN DHCP DHCPv6 no-Lua TFTP no-conntrack ipset auth no-DNSSEC loop-detect inotify
Jul 09 14:12:51 consul-lab01 dnsmasq[9069]: using nameserver 192.168.1.193#8600 for domain 168.192.in-addr.arpa
Jul 09 14:12:51 consul-lab01 dnsmasq[9069]: using nameserver 192.168.1.1#53
Jul 09 14:12:51 consul-lab01 dnsmasq[9069]: using nameserver 192.168.1.193#8600 for domain consul
Jul 09 14:12:51 consul-lab01 dnsmasq[9069]: read /etc/hosts - 2 addresses
```

- test DNS resolution

`ping active.vault.service.consul`

`ping www.espn.com`

### troubleshooting DNS
- use tcpdmp to monitor queries to 53 and 8600 *note* determine <int name> by using `ip addr` command

`sudo tcpdump -nt -i <int name> udp port 53`

`sudo tcpdump -nt -i <int name> udp port 8600'


### Gracefully close Consul agent
_results in Consul agent being listed with a "left" status in the Consul cluster and will age out altogether after 72 hours_

- collect consul PID

`ps -ef | grep consul`

- issue kill command using PID

`sudo kill -INT <consul PID>`
## MySQL
set values for `MYSQL_ROOT_PASSORD, MYSQL_DATABASE, MYSQL_PASSWORD` inputs

```
docker pull mysql/mysql-server:5.7
mkdir ~/transit-data
docker run --name mysql-transit \
  -p 3306:3306 \
  -v ~/transit-data:/var/lib/mysql \
  -e MYSQL_ROOT_PASSWORD=root \
  -e MYSQL_ROOT_HOST=% \
  -e MYSQL_DATABASE=my_app \
  -e MYSQL_USER=vault \
  -e MYSQL_PASSWORD=vaultpw \
  -d mysql/mysql-server:5.7
  ```
## Vault
Assumption is a root token will be used for the demo, in all our non-demo situations, a proper policy with _least privilege_ is created and used to consume EaaS via the Transit Backend. See https://learn.hashicorp.com/vault/encryption-as-a-service/eaas-transit#policy-requirements

*NOTE*: Vault can encrypt a binary file such as an image. When you encrypt plaintext, it must be base64 encoded.

*NOTE*: Vault does NOT store any data encrypted via the transit/encrypt endpoint. The output you received is the ciphertext. You can store this ciphertext at the desired location (e.g. MySQL database) or pass it to another application.

- Enable Transit Backend at */eaas_demo* using `-path` argument

`vault secrets enable -path=eeas_demo transit`

- Create key ring named *eaas_pii*

`vault write -f transit/keys/eaas_pii`

### EaaS via CLI
- Encrypt dummy credit card number 4111 1111 1111 1111

`vault write transit/encrypt/eaas_pii plaintext=$(base64 <<< "4111 1111 1111 1111")`

- Decrypt cipher string
`vault write transit/decrypt/eaas_pii ciphertext="vault:v1: < encrypted string>"`

- Decode decrypted string
`base64 --decode <<< "< base64 encoded string>"`

### EaaS via API
- Vault token set as env var
`export VAULT_TOKEN= < your token >`

- Encrypt dummy credit card number 4111 1111 1111 1111
	- generate Base64-encoded plaintext
`base64 <<< "4111 1111 1111 1111"`

- pass the Base64-encoded plaintext as API payload

```
    curl --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data '{"plaintext": "< base64 encoded output>"}' \
    https://active.vault.service.consul:8200/v1/transit/encrypt/eaas_pii | jq

```

- Decrypt 
```
       curl --header "X-Vault-Token: $VAULT_TOKEN" \
       --request POST \
       --data '{"ciphertext": "< encrypted cipher text>"}' \
       https://active.vault.service.consul:8200/v1/transit/decrypt/orders | jq
```


#### Script to take input of data to encode and set as env var
https://linuxhint.com/bash_base64_encode_decode/

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

#### CLI command to encode and set output as env var
- this worked w/o syntax error but did not set the env var

`export ENCODED_PII= "$(base64 <<< "4111-1111-1111-1111")"`

```
    curl --header "X-Vault-Token: $VAULT_TOKEN" \
    --request POST \
    --data '{"plaintext": "$ENCODED_PII"}' \
    https://active.vault.service.consul:8200/v1/transit/encrypt/eaas_pii | jq

```




- these did not work:
export ENCODED_PII= "$(echo `4111-1111-1111-1111` | base64)"

ENCODED_PII=`echo -n $text | base64`


## Access App
http://<IP or hostname>:1234
