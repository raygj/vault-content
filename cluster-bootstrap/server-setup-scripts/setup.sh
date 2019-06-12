#!/bin/sh
# This is a setup script meant to be used with the Vault POV Workshop
# https://github.com/TheHob/vault-pov-training
# 
# Once you have stood up your three Vault instances, run the script on each
# machine with your three IP addresses as script arguments. Put the IP address
# of the local machine *first* in the list.
#
# Once the script is complete you should be able to start Vault and Consul:
#
# systemctl start consul
# systemctl start vault

CLUSTER_COUNT=$#
CONSUL_VERSION="1.4.4"
VAULT_VERSION="1.1.2"
MYIP=$1
MACHINE1=$2
MACHINE2=$3

# Set up some directories
mkdir -pm 0755 /etc/vault.d
mkdir -pm 0755 /etc/ssl/vault
mkdir -pm 0755 /etc/consul.d
mkdir -pm 0755 /opt/consul/data

# Create Consul online service config
cat << EOF > /etc/systemd/system/consul-online.service
[Unit]
Description=Consul Online
Requires=consul.service
After=consul.service
[Service]
Type=oneshot
ExecStart=/usr/local/bin/consul-online.sh
User=consul
Group=consul
[Install]
WantedBy=consul-online.target multi-user.target
EOF

# Create the Consul online script
cat << EOF > /usr/local/bin/consul-online.sh
#!/usr/bin/env bash
set -e
set -o pipefail
CONSUL_ADDRESS=${1:-"127.0.0.1:8500"}
# waitForConsulToBeAvailable loops until the local Consul agent returns a 200
# response at the /v1/operator/raft/configuration endpoint.
#
# Parameters:
#     None
function waitForConsulToBeAvailable() {
  local consul_addr=$1
  local consul_leader_http_code
  consul_leader_http_code=$(curl --silent --output /dev/null --write-out "%{http_code}" "${consul_addr}/v1/operator/raft/configuration") || consul_leader_http_code=""
  while [ "x${consul_leader_http_code}" != "x200" ] ; do
    echo "Waiting for Consul to get a leader..."
    sleep 5
    consul_leader_http_code=$(curl --silent --output /dev/null --write-out "%{http_code}" "${consul_addr}/v1/operator/raft/configuration") || consul_leader_http_code=""
  done
}
waitForConsulToBeAvailable "${CONSUL_ADDRESS}"
EOF

# Configure the Consul online service target
cat << EOF > /etc/systemd/system/consul-online.target
[Unit]
Description=Consul Online
RefuseManualStart=true
EOF

if [ $CLUSTER_COUNT -eq 1 ]; then
  # Configure the Consul JSON config
  cat << EOF > /etc/consul.d/consul.json
  {
  "server": true,
  "leave_on_terminate": true,
  "advertise_addr": "${MYIP}",
  "data_dir": "/opt/consul/data",
  "client_addr": "0.0.0.0",
  "log_level": "INFO",
  "ui": true
  }
EOF
elif [ $CLUSTER_COUNT -eq 3 ]; then
  # Three node cluster
  cat << EOF > /etc/consul.d/consul.json
  {
  "server": true,
  "bootstrap_expect": 3,
  "leave_on_terminate": true,
  "advertise_addr": "${MYIP}",
  "retry_join": ["${MACHINE1}","${MACHINE2}"],
  "data_dir": "/opt/consul/data",
  "client_addr": "0.0.0.0",
  "log_level": "INFO",
  "ui": true
  }
EOF
else
  echo "Please provide either 1 or 3 IP addresses (single node or 3 node cluster)"
  exit 1
fi
  


# Set up the Consul service script
cat << EOF > /etc/systemd/system/consul.service
[Unit]
Description=Consul Agent
Requires=network-online.target
After=network-online.target
[Service]
Restart=on-failure
ExecStart=/usr/local/bin/consul agent -config-dir /etc/consul.d
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
User=consul
Group=consul
[Install]
WantedBy=multi-user.target
EOF

# Set up the Vault service script
cat << EOF > /etc/systemd/system/vault.service
[Unit]
Description=Vault Server
Requires=consul-online.target
After=consul-online.target
[Service]
Restart=on-failure
PermissionsStartOnly=true
ExecStartPre=/sbin/setcap 'cap_ipc_lock=+ep' /usr/local/bin/vault
ExecStart=/usr/local/bin/vault server -config /etc/vault.d
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM
User=vault
Group=vault
[Install]
WantedBy=multi-user.target
EOF

# Setup the "no-tls" vault config file
cat << EOF > /etc/vault.d/vault-no-tls.hcl
storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
}
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1
}
ui=true
EOF

# # Setup the "tls enabled" vault config file
# cat << EOF > /etc/vault.d/vault-tls.hcl
# storage "consul" {
#   address = "127.0.0.1:8500"
#   path    = "vault/"
# }
# listener "tcp" {
#   address     = "0.0.0.0:8200"
#   tls_cert_file = "/etc/ssl/vault/vault.crt"
#   tls_key_file = "/etc/ssl/vault/vault.key"
# }
# ui=true
# EOF

logger() {
  DT=$(date '+%Y/%m/%d %H:%M:%S')
  echo "$DT $0: $1"
}

user_rhel() {
  # RHEL user setup
  /usr/sbin/groupadd --force --system "${GROUP}"

  if ! getent passwd "${USER}" >/dev/null ; then
    /usr/sbin/adduser \
      --system \
      --gid "${GROUP}" \
      --home "${HOME}" \
      --no-create-home \
      --comment "${COMMENT}" \
      --shell /bin/false \
      "${USER}"  >/dev/null
  fi
}

user_ubuntu() {
  # UBUNTU user setup
  if ! getent group "${GROUP}" >/dev/null
  then
    addgroup --system "${GROUP}" >/dev/null
  fi

  if ! getent passwd "${USER}" >/dev/null
  then
    adduser \
      --system \
      --disabled-login \
      --ingroup "${GROUP}" \
      --home "${HOME}" \
      --no-create-home \
      --gecos "${COMMENT}" \
      --shell /bin/false \
      "${USER}"  >/dev/null
  fi
}

createuser () {
USER="${1}"
COMMENT="Hashicorp ${1} user"
GROUP="${1}"
HOME="/srv/${1}"

if $(python -mplatform | grep -qi Ubuntu); then
  logger "Setting up user ${USER} for Debian/Ubuntu"
  user_ubuntu
else
  logger "Setting up user ${USER} for RHEL/CentOS"
  user_rhel
fi
}

logger "Running"

createuser vault
createuser consul

mkdir binaries && cd binaries
python -mplatform | grep -qi Ubuntu && sudo apt -y install wget unzip || sudo yum -y install wget unzip
wget https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/vault/ent/${VAULT_VERSION}/vault-enterprise_${VAULT_VERSION}%2Bent_linux_amd64.zip
wget https://s3-us-west-2.amazonaws.com/hc-enterprise-binaries/consul/ent/${CONSUL_VERSION}/consul-enterprise_${CONSUL_VERSION}%2Bent_linux_amd64.zip
unzip consul-enterprise_${CONSUL_VERSION}+ent_linux_amd64.zip
unzip vault-enterprise_${VAULT_VERSION}+ent_linux_amd64.zip
cp -rp consul /usr/local/bin/consul
cp -rp vault /usr/local/bin/vault

chown -R consul:consul /etc/consul.d /opt/consul
chmod -R 0644 /etc/consul.d/*
chmod 0755 /usr/local/bin/consul
chown consul:consul /usr/local/bin/consul

chown -R vault:vault /etc/vault.d /etc/ssl/vault
chmod -R 0644 /etc/vault.d/*
chmod 0755 /usr/local/bin/vault
chown vault:vault /usr/local/bin/vault

chmod 0664 /etc/systemd/system/vault*
chmod 0664 /etc/systemd/system/consul*
# Not sure why this is here.
# chmod 0664 /lib/systemd/system/{vault*,consul*}
chmod 0755 /usr/local/bin/consul-online.sh

systemctl enable vault.service
systemctl enable consul.service

# set VAULT_ADDR environment var for CLI
echo 'export VAULT_ADDR="http://127.0.0.1:8200"' >> $HOME/.bashrc

logger "Complete"
