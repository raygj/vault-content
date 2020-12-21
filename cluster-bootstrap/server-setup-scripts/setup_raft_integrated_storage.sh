#!/bin/sh
#
# Once you have stood up your three Vault instances, run the script on each
# machine with your three IP addresses as script arguments. Put the IP address
# of the local machine *first* in the list.
#
# Once the script is complete you should be able to start Vault
#
apt-get install python -y

CLUSTER_COUNT=$#
VAULT_VERSION="1.6.0"
MYIP=$1
MACHINE1=$2
MACHINE2=$3

# Set up some directories
mkdir -pm 0755 /etc/vault.d
mkdir -pm 0755 /etc/ssl/vault

user_rhel() {
  # RHEL user setup
  /usr/sbin/groupadd --force --system ${GROUP}

  if ! getent passwd ${USER} >/dev/null ; then
    /usr/sbin/adduser \
      --system \
      --gid ${GROUP} \
      --home ${HOME} \
      --no-create-home \
      --comment "${COMMENT}" \
      --shell /bin/false \
      ${USER}  >/dev/null
  fi
}

user_ubuntu() {
  # UBUNTU user setup
  if ! getent group ${GROUP} >/dev/null
  then
    addgroup --system ${GROUP} >/dev/null
  fi

  if ! getent passwd ${USER} >/dev/null
  then
    adduser \
      --system \
      --disabled-login \
      --ingroup ${GROUP} \
      --home ${HOME} \
      --no-create-home \
      --gecos "${COMMENT}" \
      --shell /bin/false \
      ${USER}  >/dev/null
  fi
}

createuser () {
USER="${1}"
COMMENT="HashiCorp ${1} user"
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

createuser vault

# Set up the Vault service script
# use systemctl daemon-reload to reload after unit changes, then restart
cat << EOF > /etc/systemd/system/vault.service
[Unit]
Description="HashiCorp Vault - A tool for managing secrets"
Documentation=https://www.vaultproject.io/docs/
Requires=network-online.target
After=network-online.target
ConditionFileNotEmpty=/etc/vault.d/vault-tls.hcl
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
User=vault
Group=vault
ProtectSystem=full
ProtectHome=read-only
PrivateTmp=yes
PrivateDevices=yes
SecureBits=keep-caps
AmbientCapabilities=CAP_IPC_LOCK
Capabilities=CAP_IPC_LOCK+ep
CapabilityBoundingSet=CAP_SYSLOG CAP_IPC_LOCK
NoNewPrivileges=yes
ExecStart=/usr/local/bin/vault server -config=/etc/vault.d/vault-tls.hcl
ExecReload=/bin/kill --signal HUP $MAINPID
KillMode=process
KillSignal=SIGINT
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
LimitNOFILE=65536
LimitMEMLOCK=infinity

[Install]
WantedBy=multi-user.target
EOF

# Setup the "Raft and tls enabled" vault config file Multi-Node cluster
cat << EOF > /etc/vault.d/vault-tls.hcl
storage "raft" {
  path    = "/opt/vault/raft"
  node_id = "vault-ent-node-3a" #node 1 of 3
  retry_join {
    leader_api_addr = "http://192.168.1.x:8200" #node 2 of 3
  }
  retry_join {
    leader_api_addr = "http://192.168.1.x:8200" #node 3 of 3
  }
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_cert_file = "/etc/ssl/vault/vault.crt"
  tls_key_file = "/etc/ssl/vault/vault.key"
}
telemetry {
  dogstatsd_addr   = "localhost:8125"
  disable_hostname = true
}
api_addr="https://$MYIP:8200" #normally a public address
cluster_addr = "http://$MYIP:8201" #specify private address
disable_mlock=true
ui=true
EOF

# Setup the "Raft and tls enabled" vault config file Single Node cluster
# cat << EOF > /etc/vault.d/vault-tls.hcl
# storage "raft" {
#  path    = "/opt/vault/raft"
#  node_id = "vault-ent-node-x"
#}
#
#listener "tcp" {
#  address     = "0.0.0.0:8200"
#  tls_cert_file = "/etc/ssl/vault/vault.crt"
#  tls_key_file = "/etc/ssl/vault/vault.key"
#}
#telemetry {
#  dogstatsd_addr   = "localhost:8125"
#  disable_hostname = true
#}
#api_addr="https://$MYIP:8200" #normally a public address
#cluster_addr = "http://$MYIP:8201" #specify private address
#disable_mlock=true
#ui=true
#EOF

# Setup the "no-tls" vault config file
#cat << EOF > /etc/vault.d/vault-no-tls.hcl
#storage "raft" {
#  path    = "/opt/vault/raft"
#  node_id = "vault-ent-node-1"
#  retry_join {
#    leader_api_addr = "http://127.0.0.1:8201"
#  }
#listener "tcp" {
#  address     = "0.0.0.0:8200"
#  tls_disable = 1
#}
#telemetry {
#  dogstatsd_addr   = "localhost:8125"
#  disable_hostname = true
#}
#ui=true
#EOF

logger() {
  DT=$(date '+%Y/%m/%d %H:%M:%S')
  echo "$DT $0: $1"
}

mkdir binaries && cd binaries
python -mplatform | grep -qi Ubuntu &&  apt -y install wget unzip ||  yum -y install wget unzip
wget https://releases.hashicorp.com/vault/${VAULT_VERSION}+ent/vault_${VAULT_VERSION}+ent_linux_amd64.zip
unzip vault_${VAULT_VERSION}+ent_linux_amd64.zip
cp -rp vault /usr/local/bin/vault
chown -R vault:vault /etc/vault.d /etc/ssl/vault
chmod -R 0644 /etc/vault.d/*
chmod 0755 /usr/local/bin/vault
chown vault:vault /usr/local/bin/vault
chmod 0664 /etc/systemd/system/vault*

# setup dir for raft storage
mkdir -pm 0755 /opt/vault/raft
chown -R vault:vault /opt/vault/raft

# use these commands if you need to nuke the local Raft storage and reset Vault to a new instance
# sudo mkdir -pm 0755 /opt/vault/raft
# sudo chown -R vault:vault /opt/vault/raft

# directory for vault audit log
touch /var/log/vault_audit.log
chown vault:vault /var/log/vault_audit.log

systemctl enable vault
systemctl start vault
systemctl status vault

logger "Complete"
