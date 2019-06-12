Consul Server Setup with Vault

# ~/vault_consul.hcl

cat <<EOF > ~/vaultconsul.hcl
storage "consul" {
 address = "127.0.0.1:8500"
 path = "vault/"
 }
listener "tcp" {
  address = "0.0.0.0:8200"
  tls_disable = "true"
}
disable_mlock="true"
ui = "true"
EOF

sudo mkdir -pm 0755 /etc/consul.d
sudo mkdir -pm 0755 /opt/consul/data

sudo chown -R vagrant:vagrant /etc/consul.d /opt/consul
sudo chmod -R 0644 /etc/consul.d/*

#ON FIRST VAGRANT

cat <<EOF > /etc/consul.d/consul.json
{"server": true,
 "bootstrap_expect": 1,
 "leave_on_terminate": true,
 "advertise_addr": "192.168.56.106",
 "retry_join": ["192.168.56.106"],
 "data_dir": "/opt/consul/data",
 "client_addr": "0.0.0.0",
 "log_level": "INFO",
 "ui": true}
EOF

#On SECOND VAGRANT
cat <<EOF > /etc/consul.d/consul.json
{"server": true,
 "bootstrap_expect": 1,
 "leave_on_terminate": true,
 "advertise_addr": "192.168.56.107",
 "retry_join": ["192.168.56.107"],
 "data_dir": "/opt/consul/data",
 "client_addr": "0.0.0.0",
 "log_level": "INFO",
 "ui": true}
EOF


To Start:  
nohup consul agent -config-dir /etc/consul.d/ > consul.out 2>&1 &


nohup vault server -config=vaultconsul.hcl > vaultconsul.out 2>&1 &

---
Admin Policy

https://www.vaultproject.io/guides/identity/policies.html

----
echo '
# Manage auth methods broadly across Vault
path "auth/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "sys/auth/"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List, create, update, and delete auth methods
path "sys/auth/*"
{
  capabilities = ["create", "read", "update", "delete", "sudo"]
}
path "sys/policy/"
{
  capabilities = ["read", "list"]
}

# Create and manage ACL policies broadly across Vault
path "sys/policy/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Create and manage ACL policies broadly across Vault
path "sys/acl/policies/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Create and manage ACL policies broadly across Vault
path "sys/acl/policies/"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}


# Create and manage ACL policies broadly across Vault
path "sys/policies/acl/"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Create and manage ACL policies broadly across Vault
path "sys/policies/acl/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List, create, update, and delete key/value secrets
path "secret/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List, create, update, and delete key/value secrets
path "US_NON_GDPR_data/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List, create, update, and delete key/value secrets
path "EU_GDPR_data/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage and manage secret engines broadly across Vault.
path "sys/mounts/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage and manage secret engines broadly across Vault.
path "access/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage and manage secret engines broadly across Vault.
path "access/"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage and manage secret engines broadly across Vault.
path "token/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage and manage secret engines broadly across Vault.
path "userpass/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Read health checks
path "sys/health"
{
  capabilities = ["read", "sudo"]
}

path "sys/capabilities"
{
  capabilities = ["create", "update", "list"]
}

path "sys/capabilities-self"
{
  capabilities = ["create", "update", "list"]
}' | vault policy write admin-policy -

--------------------------------


------------------



