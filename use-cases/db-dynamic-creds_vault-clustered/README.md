# Background

The focus of this walk through is testing dynamic DB credentials between a Primary and Performance Secondary cluster to simulate a failover of services from one data center to another.


# Vault Client

the Vault client VM will host two Postgres instances in Docker containers and acts as a simulated app server that needs DB creds

- install Docker

`sudo apt install docker.io -y`

## Postgres Setup

### Instance 1

this instance will be tied to the primary Vault cluster

- start container

`sudo docker run --name postgres-1 -e POSTGRES_USER=root -e POSTGRES_PASSWORD=temp123 -d -p 5432:5432 postgres`

- exec into Docker container

`sudo docker exec -it postgres-1 bash`

- connect to Postgres as root

`psql -U root`

- create **demo** database

`CREATE DATABASE demo;`

- create postgres user **vault-demo** that will be used by Vault to manage Postgres

`CREATE ROLE "vault-demo" WITH LOGIN PASSWORD 'temp123';`

- grant full access for vault-demo user

`ALTER ROLE "vault-demo" WITH SUPERUSER;`

- grant all privilege on DB **demo** to **vault-demo** user

`GRANT ALL PRIVILEGES ON DATABASE demo TO "vault-demo";`

- check user and role assignments

`\du`

- quit Postgres

`\q`

### Instance 2

this instance will be tied to the performance secondary Vault cluster

- start container

`sudo docker run --name postgres-2 -e POSTGRES_USER=root -e POSTGRES_PASSWORD=temp123 -d -p 5433:5433 postgres`

- exec into Docker container

`sudo docker exec -it postgres-2 bash`

- create **demo** database

`CREATE DATABASE demo;`

- create postgres user **vault-demo** that will be used by Vault to manage Postgres

`CREATE ROLE "vault-demo" WITH LOGIN PASSWORD 'temp123';`

- grant full access for vault-demo user

`ALTER ROLE "vault-demo" WITH SUPERUSER;`

- grant all privilege on DB **demo** to **vault-demo** user

`GRANT ALL PRIVILEGES ON DATABASE demo TO "vault-demo";`

- check user and role assignments

`\du`

- quit Postgres

`\q`

# Setup Postgres Backend on Vault Primary Server

## Vault Policy

this policy will be used to create accounts that will request and consume DB creds

```

sudo tee ~/app-db-cred.json <<EOF
# Get credentials from the database secret engine
path "db-dc1/creds/readonly" {
  capabilities = [ "read" ]
}
EOF

```

## DB User Create SQL

this code will be executed by Vault to create users in the target DB

```
sudo tee ~/db-user-create.sql <<EOF
CREATE ROLE "{{name}}" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
GRANT SELECT ON ALL TABLES IN SCHEMA public TO "{{name}}";
EOF
```

## Configure Postgres Secrets Engine

- enable DB secrets engine

`vault secrets enable -path=db-dc1 database`

- configure Vault's connection to Postgres

```

export DB_HOST_IP=10.0.101.60

vault write db-dc1/config/postgresql \
 plugin_name=postgresql-database-plugin \
 allowed_roles="readonly" \
 connection_url="postgresql://{{username}}:{{password}}@$DB_HOST_IP:5432/demo?sslmode=disable" \
 username="vault-demo" \
 password="temp123"

```
## Configure Vault Role

`vault write db-dc1/roles/readonly db_name=demo creation_statements=@db-user-create.sql default_ttl=3m max_ttl=10m`

## Apply Vault Policy to Role

`vault policy write apps-db-readonly-cred app-db-cred.json`

## Test the Configuration

### App User/Service Test Token

this token will be used by services that need a readonly DB cred

`vault token create -policy="apps-db-readonly-cred"`

- output:

```
Key                  Value
---                  -----
token                s.jkrG8qNuYRqR0vdSAHJjFBoj
token_accessor       rlKxwpIl8rcD8Tapl6g36ORb
token_duration       768h
token_renewable      true
token_policies       ["apps-db-readonly-cred" "default"]
identity_policies    []
policies             ["apps-db-readonly-cred" "default"]
```

### Generate DB Cred

- login to Vault using token mapped to **readonly** role in the /db-dc1 mount and correpsoding **apps-db-readonly-cred** policy

`vault login s.jkrG8qNuYRqR0vdSAHJjFBoj`

- create DB cred

`vault read db-dc1/creds/readonly`
