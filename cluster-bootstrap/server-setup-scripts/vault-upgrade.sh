export VAULT_VERSION=1.1.2

wget https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/vault/ent/${VAULT_VERSION}/vault-enterprise_${VAULT_VERSION}%2Bent_linux_amd64.zip

unzip vault-enterprise_${VAULT_VERSION}+ent_linux_amd64.zip

systemctl stop vault

cp -rp vault /usr/local/bin/vault

systemctl start vault