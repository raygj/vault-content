# login

`vault login < a vault token with required access>`

# set vault token var

`export VAULT_TOKEN=< a vault token with required access>`

#enable AWS backend

`vault secrets enable aws`

#configure AWS backend

## set AWS creds as env vars

```

export AWS_ACCESS_KEY_ID=<key>

export AWS_SECRET_ACCESS_KEY=<key>

```

## configure AWS secret engine

```

vault write aws/config/root \
    access_key=$AWS_ACCESS_KEY_ID \
    secret_key=$AWS_SECRET_ACCESS_KEY \
    region=us-east-1

```

### verify

`vault read aws/config/root`

#create role that will be used by Vault to generate AWS creds

##policy for EC2 and other services can be pulled from AWS

```

vault write aws/roles/jray-role \
        credential_type=iam_user \
        policy_document=-<<EOF
        {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Action": "ec2:*",
              "Resource": "*"
            }
          ]
        }
EOF

```

### verify

`vault read aws/roles/jray-role`

#configure lease value TTL

`vault write aws/config/lease lease=5m lease_max=15m`

#generate set of creds

`vault read aws/creds/jray-role`

#list active leases

`vault list sys/leases/lookup/aws/creds/jray-role`

#revoke all creds at mount point, via CLI

`vault lease revoke -prefix=true aws/creds/jray-role`

#revoke creds via CLI

`vault lease revoke aws/creds/jray-role/`

#create creds via API

```

curl --header "X-Vault-Token: $VAULT_TOKEN" \
       --request GET \
       http://127.0.0.1:8200/v1/aws/creds/jray-role | jq

```

#revoke all AWS creds at this mount point via API

```

curl --header "X-Vault-Token: $VAULT_TOKEN" --request POST \
       http://127.0.0.1:8200/v1/sys/leases/revoke-prefix/aws/creds | jq

```

# configuration lease duration for a namespace

`vault write -namespace=LOB-Team-1 aws/config/lease lease=5m lease_max=15m`

# read secret engine configuration

`vault read aws/config/lease`
