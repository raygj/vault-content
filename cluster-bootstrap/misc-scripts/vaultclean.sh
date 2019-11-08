#! /bin/bash

# this script will provide a clean slate for a vault instance using filesystem storage

systemctl stop vault
rm -rf /home/vault
mkdir -p /home/vault/data
chown vault:vault /home/vault/data
systemctl start vault

# create in /tmp
# chmod +x /tmp/vaultclean.sh