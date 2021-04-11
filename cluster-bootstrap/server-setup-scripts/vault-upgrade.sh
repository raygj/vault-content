#!/bin/sh
read -p "this is a disruptive process..."
sleep 5
systemctl stop vault
export VAULT_VERSION=1.7.0
wget https://releases.hashicorp.com/vault/${VAULT_VERSION}+ent/vault_${VAULT_VERSION}+ent_linux_amd64.zip
unzip vault_${VAULT_VERSION}+ent_linux_amd64.zip
cp -rp vault /usr/local/bin/vault
chown -R vault:vault /etc/vault.d /etc/ssl/vault
chmod -R 0644 /etc/vault.d/*
chmod 0755 /usr/local/bin/vault
chown vault:vault /usr/local/bin/vault
chmod 0664 /etc/systemd/system/vault*
systemctl start vault
print "upgrade complete!"
