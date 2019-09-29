# vault ent
export VAULT_VERSION=1.2.0

wget https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/vault/ent/${VAULT_VERSION}/vault-enterprise_${VAULT_VERSION}%2Bent_linux_amd64.zip

unzip vault-enterprise_${VAULT_VERSION}+ent_linux_amd64.zip

systemctl stop vault

cp -rp vault /usr/local/bin/vault

systemctl start vault

# consul ent

export CONSUL_VERSION=1.6.1

wget https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/consul/ent/${CONSUL_VERSION}/consul-enterprise_${CONSUL_VERSION}%2Bent_linux_amd64.zip

unzip consul-enterprise_${CONSUL_VERSION}+ent_linux_amd64.zip

cp -rp consul /usr/local/bin/consul

# vault OSS
export VAULT_VERSION=1.2.0

wget https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip

unzip vault_${VAULT_VERSION}_linux_amd64.zip

systemctl stop vault

cp -rp vault /usr/local/bin/vault

systemctl start vault

# consul OSS
export CONSUL_VERSION=1.6.1

wget https://releases.hashicorp.com/consul/${CONSUL_VERSION}/consul_${CONSUL_VERSION}_linux_amd64.zip

unzip consul_${CONSUL_VERSION}_linux_amd64.zip

systemctl stop consul

cp -rp consul /usr/local/bin/consul

systemctl start vault