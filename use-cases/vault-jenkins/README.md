## Example Jenkins integration for Vault

courtesy of @kawsark

This snippet provides an example Jenkinsfile that performs an AppRole authentication using `curl` utility. The objective is to allow Jenkins to Authenticate to Vault, then use a temporary token to retrieve a secret. It does not rely on a plugin and therefore offers more flexibility.

### Vault setup
Please use commands below to create the AppRole Auth method, define an App role, and retrieve the Role ID and Secret ID.
- In this example, the `SECRET_ID` is limited to a TTL of 24 hours (`secret_id_ttl`) and a limit of 40 uses (`secret_id_num_uses`).  Hence the value will need to be updated periodically, otherwise, you will get an error message: "invalid secret id".
- The resulting Vault token can be used 5 times (`token_num_uses=5`). This will need to be adjusted if you have additional stages in the Pipeline where you will continue to use the same token.
```
vault secrets enable -path=secrets kv
vault write secrets/creds/dev username=dev password=legos
cat <<EOF > jenkins-policy.hcl
path "secrets/creds/dev" {
 capabilities = ["read"]
}
EOF
vault policy write jenkins jenkins-policy.hcl
vault auth enable approle
vault write auth/approle/role/jenkins-role \
    secret_id_ttl=24h \
    token_num_uses=5 \
    token_ttl=20m \
    token_max_ttl=30m \
    secret_id_num_uses=40 \
    policies="jenkins"

# Use .data.role_id in role.json file as the ROLE_ID for Jenkins setup
vault read -format=json auth/approle/role/jenkins-role/role-id > role.json

# Use .data.secret_id in secretid.json file as the SECRET_ID for Jenkins credential
vault write -format=json -f auth/approle/role/jenkins-role/secret-id > secretid.json
```

### Jenkins setup
We will create a new Jenkins pipeline project to demonstrate Vault interaction. Note: you will need `curl` and `jq` utilities installed on your Jenkins server/worker node.
- Please adjust the values of `VAULT_ADDR` to your Vault server.
- Adjust the `ROLE_ID` from the output of your `vault write auth/approle/role/jenkins-role ...` command.
- Please import the Jenkinsfile snippets below into a new or existing Pipeline stage.
- Define a SECRET_ID in Jenkins credentials of type "Secret Text," The value will come from Vault Setup above.
- Adjust other variables appropriately: `VAULT_ADDR`,`ROLE_ID` and `SECRETS_PATH`.
- Run the Pipeline project
```
pipeline {
agent any
    environment {
        VAULT_ADDR="http://35.194.95.200:80"
        ROLE_ID="c4cec819-eae2-ca98-b312-46fcfe322c7c"
        SECRET_ID=credentials("SECRET_ID")
        SECRETS_PATH="secrets/creds/dev"
    }

    stages {     
      stage('Stage 0') {
          steps {
            sh """
            export PATH=/usr/local/bin:${PATH}
            # AppRole Auth request
            curl --request POST \
              --data "{ \"role_id\": \"$ROLE_ID\", \"secret_id\": \"$SECRET_ID\" }" \
              ${VAULT_ADDR}/v1/auth/approle/login > login.json

            VAULT_TOKEN=$(cat login.json | jq -r .auth.client_token)
            # Secret read request
            curl  --header "X-Vault-Token: $VAULT_TOKEN" \
              ${VAULT_ADDR}/v1/${SECRETS_PATH} | jq .
            """
          }
      }
    }
}
```

### Testing
Upon running the pipeline successfully you should see an output such as below.
```
{
  "request_id": "38e4ff71-fea3-837e-b4fd-9d19050826d7",
  "lease_id": "",
  "renewable": false,
  "lease_duration": 2764800,
  "data": {
    "password": "legos",
    "username": "dev"
  },
  "wrap_info": null,
  "warnings": null,
  "auth": null
}
```

You have now setup Jenkins server to Authenticate with Vault and retrieve a secret.
