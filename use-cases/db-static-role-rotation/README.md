# Background

The focus of this walk through is testing static role password rotation for a DB role in Postgres. The goal is to validate behavior between a Vault Enterprise Primary and Performance Secondary cluster during simulated failover of services from one data center to another.

# Provision Vault Environment

[Deploy Vault Nodes on AWS](https://github.com/raygj/vault-content/tree/master/vault-aws-demo-instance)

[Refactor Vault Nodes into single node primary and perf secondary clusters](https://github.com/raygj/vault-content/blob/master/enterprise/create-two-clusters.md)

[Test script for automated testing](https://github.com/raygj/vault-content/blob/master/use-cases/db-static-role-rotation/test_script.sh)

[learn.hashicorp guide](https://learn.hashicorp.com/vault/secrets-management/db-creds-rotation)

![diagram](/images/static-db-role.png)

# Provision Postgres container and Postgres

- start Postgres container

`docker run --name postgres -e POSTGRES_USER=root -e POSTGRES_PASSWORD=temp123 -d -p 5432:5432 postgres`

- access bash CLI of container

`sudo docker exec -it postgres-1 bash`

- PSQL root user access

`psql -U root`

- create postgres user named vault-edu

`CREATE ROLE "vault-edu" WITH LOGIN PASSWORD 'temp123';`

- grant full access for vault-edu user

`GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "vault-edu";`

- create postgres user as admin

`CREATE ROLE "postgres" WITH LOGIN PASSWORD 'temp123';`

- grant full access on postgres user

```
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO "postgres";
ALTER USER postgres WITH SUPERUSER;
ALTER USER postgres CREATEDB;
ALTER USER postgres CREATEROLE;
```

- verify roles and attributes

`\du`

- quote

`\q`

# Vault Primary Node

## Create Vault Policy for Non-Root User to manage demo env

```
sudo tee ~/db-admin.json <<EOF
path "sys/mounts/*" {
	capabilities = ["create", "read", "update", "delete", "list"]
}
path "database/*" {
	capabilities = ["create", "read", "update", "delete", "list"]
}
path "sys/policies/acl/*" {
	capabilities = ["create", "read", "update", "delete", "list"]
}
path "auth/token/create" {
	capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF
```

## Create Policy for DB Cred Rotation

```
sudo tee ~/postgres_static_app_policy.json <<EOF
path "database/static-creds/test1" {
capabilities = [ "read" ]
}
EOF
```

### Apply Policies

`vault policy write db-admin db-admin.json`

`vault policy write postgres_static_app_policy postgres_static_app_policy.json`

## Create Token

`vault token create -policy=db-admin`

Key                  Value
---                  -----
token                s.jnNmoKWLW6oESxOORiMwAE7B
token_accessor       fnFQDUWG4rLT1brlThyGMhsm
token_duration       768h
token_renewable      true
token_policies       ["db-admin" "default"]
identity_policies    []
policies             ["db-admin" "default"]


## Configure DB Secrets Engine on Primary

- login to vault using above token

vault login

- Enable database secret engine
vault secrets enable database

- test connectivity from primary cluster Vault nodes to database engine
(timeout 1 bash -c '</dev/tcp/< ip of Docker host>/5432 && echo PORT OPEN || echo PORT CLOSED') 2>/dev/null

- configure postgres database config in database secret engine

```
vault write database/config/postgresql \
plugin_name=postgresql-database-plugin \
allowed_roles="*" \
connection_url=postgresql://{{username}}:{{password}}@< ip of Docker host>:5432/postgres?sslmode=disable \
username="postgres" \
password="temp123"
```

- write rotation.sql file

```
sudo tee ~/db-rotate.sql <<EOF
ALTER USER "{{name}}" WITH PASSWORD '{{password}}';
EOF
```

- create static role named test1 with 2 minute rotation period for postgres config

```
vault write database/static-roles/test1 \
db_name=postgresql \
rotation_statements=@db-rotate.sql \
username="vault-edu" \
rotation_period=120
```
- test policy of db-admin token

vault login < token from db-admin policy >

`vault read database/static-roles/test1`

_Vault should respond with credential info, but no password_

```
Key                    Value
---                    -----
db_name                postgresql
last_vault_rotation    2020-06-01T13:20:15.209795488Z
rotation_period        2m
rotation_statements    [ALTER USER "{{name}}" WITH PASSWORD '{{password}}';]
username               vault-edu
```
- create a token using postgress_static_app_policy to be used for testing

`vault token create -policy=postgres_static_app_policy`

Key                  Value
---                  -----
token                s.YpsO1XC8TUcO7SOxEBo6wfpf
token_accessor       oo1DfGmubzvQXIiDz5jqWhgS
token_duration       768h
token_renewable      true
token_policies       ["default" "postgres_static_app_policy"]
identity_policies    []
policies             ["default" "postgres_static_app_policy"]

# Test Cred Rotation on Primary

## Login to Vault with token from postgress_static_app_policy

`vault login s.YpsO1XC8TUcO7SOxEBo6wfpf`

- issue `read` command to rotate passsword

`vault read database/static-creds/test1`

Key                    Value
---                    -----
last_vault_rotation    2020-06-01T13:26:15.211075495Z
password               A1a-UK0S8vF6vJqXRQXp
rotation_period        2m
ttl                    45s
username               vault-edu

- test current credential by logging into Postgres DB

`psql -d postgres -U vault-edu -W`

< enter current passowrd >

- success:

`postgres=>`

# Test Cred Rotation on Performance Secondary

- root login on performance secondary cluster

- generate token for postgres credentials read

`vault token create -policy=postgres_static_app_policy`

Key                  Value
---                  -----
token                s.K5aiwN8pX8uiZVMPbUfsVy0V
token_accessor       ua2MZgoquRsAp9TNMnoiCSda
token_duration       768h
token_renewable      true
token_policies       ["default" "postgres_static_app_policy"]
identity_policies    []
policies             ["default" "postgres_static_app_policy"]

## Login to Vault with token from postgress_static_app_policy

`vault login s.K5aiwN8pX8uiZVMPbUfsVy0V`

- issue `read` command to pull current passsword

`vault read database/static-creds/test1`

## Apendix

- force a rotation event, only from Primary

`vault write -f database/rotate-role/test1`
