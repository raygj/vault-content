# Background and Prerequisites

deploy 2 Vault nodes with enterprise binaries using this code:

https://github.com/raygj/vault-content/tree/master/vault-aws-demo-instance/terraform-aws-multi-cluster

then use the following steps to break the 2-node cluster into individual single-node deployments that can be clustered

## environment

Server1 (primary)
  Vault Ent

Server2 (perf secondary)
  Vault Ent

Client
  Vault Agent

**note** plan (as of 05/2020) is to modify the TPL script to support this two cluster setup automatically...when time allows

## Prepare Vault Nodes

you will execute these steps on each Vault node

### Consul Config

- stop Consul

`sudo systemctl stop consul`

#### modify Consul Client config

```

sudo tee /etc/consul.d/consul-default.json <<EOF
{
  "datacenter": "vault-perf",
  "data_dir": "/opt/consul/data",
  "bind_addr": "0.0.0.0",
  "client_addr": "0.0.0.0",
  "log_level": "INFO",
  "ui": true
}
EOF

```

#### modify Consul Server config

```

sudo tee /etc/consul.d/consul-server.json <<EOF
{
  "server": true,
  "bootstrap_expect": 1
}
EOF

```

#### cleanup filesystem

sudo rm -rf /opt/consul/data

sudo mkdir -pm 0755 /opt/consul/data

sudo chown -R consul:consul /opt/consul/data

### start Consul and verify

`sudo systemctl start consul`

`consul members`

### Create New vault.hcl Config

- stop Vault, backup existing config, create new config that uses filesystem and Shamir keys, restart Vault

export PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)

```

sudo systemctl stop vault

sudo cp /etc/vault.d/vault.hcl /etc/vault.d/vault.hcl.orig

sudo rm -rf /etc/vault.d/vault.hcl

sudo tee /etc/vault.d/vault.hcl <<EOF
storage "consul" {
  address = "127.0.0.1:8500"
  path    = "vault/"
}

listener "tcp" {
  address     = "$PRIVATE_IP:8200"
  tls_disable = 1
}

#seal "awskms" {
#  region = "$${AWS_REGION}"
#  kms_key_id = "$${KMS_KEY}"
#}

ui=true
EOF

```

- start Vault

`sudo systemctl start vault`

### Apply Vault Enterprise License

vault login <root token>

open `.HCLIC` file locally, copy the contents to the clipboard

`vault write sys/license text=< paste the very long character string>`

- for example:

`vault write sys/license text=01MV4UU43...`

`ENTER`

- successful apply:

`Success! Data written to: sys/license`

- restart Vault:

`sudo systemctl restart vault`

## Configure Performance Replication

### Primary Node

- enable perf primary:

`vault write -f sys/replication/performance/primary/enable`

- set secondary token:

`vault write sys/replication/performance/primary/secondary-token id=demo-perf-0`

example output:

Key                              Value
---                              -----
wrapping_token:                  eyJhbGciOiJFUzUxMiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3NvciI6IiIsImFkZHIiOiJodHRwOi8vMTAuMC4xMDEuOTQ6ODIwMCIsImV4cCI6MTU5MDc4NjEwMSwiaWF0IjoxNTkwNzg0MzAxLCJqdGkiOiJzLjYyV1RGRHNucFhNaE5IZGZFU01idzdQTyIsIm5iZiI6MTU5MDc4NDI5NiwidHlwZSI6IndyYXBwaW5nIn0.AIy6J0DERd4ONvI5YgacitFwinEmM6UwiygZ_8GkucIwnrk8u1olBhGVYDAj3TDk2XaxmCxqbtYLIKnmkYqJErcbAFeOBcIHsW-aXhquMozsDMRV_hW2CiPvd2g0vZbud1WHBU4Z6PVu_BRkr-yH3JXp0PvYV0PLXL1QInip8Y15NsEw
wrapping_accessor:               FzabhI2NmwjehtvHdIo4wmAD
wrapping_token_ttl:              30m
wrapping_token_creation_time:    2020-05-29 20:31:41.213606477 +0000 UTC
wrapping_token_creation_path:    sys/replication/performance/primary/secondary-token

### Perf Replication Node

`vault write sys/replication/performance/secondary/enable token=<wrapping token from primary>`

example output:

WARNING! The following warnings were returned from Vault:

  * Vault has successfully found secondary information; it may take a while to
  perform setup tasks. Vault will be unavailable until these tasks and initial
  sync complete.
