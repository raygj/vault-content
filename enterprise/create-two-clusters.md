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

- grab private IP from EC2 service and set env var

`export PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)`

```

sudo tee /etc/consul.d/consul-default.json <<EOF
{
  "datacenter": "vault-perf",
  "data_dir": "/opt/consul/data",
  "bind_addr": "$PRIVATE_IP",
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

```
- grab private IP from EC2 service and set env var

`export PRIVATE_IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)`

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
wrapping_token:                  eyJhbGciOiJFUzUxMiIsInR5cCI6IkpXVCJ9.eyJhY2Nlc3NvciI6IiIsImFkZHIiOiJodHRwOi8vMTAuMC4xMDEuOTQ6ODIwMCIsImV4cCI6MTU5MDc4NzI5MiwiaWF0IjoxNTkwNzg1NDkyLCJqdGkiOiJzLnFzQm9RcWxMVjR2MjlveXl6U3RoaEZmbCIsIm5iZiI6MTU5MDc4NTQ4NywidHlwZSI6IndyYXBwaW5nIn0.AJYJmWXq_toj0IOriHHs2a1JVIytn6VkTxXsmJWxdXqFHXgPozeXZLMEyqpju5cAlc0tdl7cayqRIObL4PJvYODiAUFm3Yb7ITpAin5vnNwhXZq7HUV2zlCjTxELazoXS2zRLLLL88AcVl3UKqxkr8AWq32RP06IihHA_uMjEsdqh0-r
wrapping_accessor:               vaX54U4AzQBBP2kBmTJLMXzi
wrapping_token_ttl:              30m
wrapping_token_creation_time:    2020-05-29 20:51:32.191195595 +0000 UTC
wrapping_token_creation_path:    sys/replication/performance/primary/secondary-token

### Perf Replication Node

`vault write sys/replication/performance/secondary/enable token=<wrapping token from primary>`

example output:

WARNING! The following warnings were returned from Vault:

  * Vault has successfully found secondary information; it may take a while to
  perform setup tasks. Vault will be unavailable until these tasks and initial
  sync complete.

## Generate Root Token for Performance Secondary

Root tokens on secondary are wiped once performance replication is enabled. Approach is to configure an Auth Method on the secondary before enabling replication. If not, then the `generate-root` process must be used.

https://learn.hashicorp.com/vault/operations/ops-generate-root

https://learn.hashicorp.com/vault/operations/ops-replication#secondary-tokens

### on secondary

- initiate the process

`vault operator generate-root -init`

- Shamir key holder initiate process to unwrap Nonce

`vault operator generate-root`

< you will be prompted to enter the unseal key(s) >

output is an encoded token:

Operation nonce: c1c2df36-63d1-d247-f266-7abba1c98014
Unseal Key (will be hidden):
Nonce            c1c2df36-63d1-d247-f266-7abba1c98014
Started          true
Progress         1/1
Complete         true
Encoded Token    GWQaBkQhdH4dB3MlTDItFCw2VRMoVBt2PX0

- decode the token using the original OTP:

vault operator generate-root \
   -decode=<> \
   -otp=<>

output is unwrapped token
