# Setup

Create a “finance” and an “education” namespace:
$ vault namespace create finance
$ vault namespace create education
Now create child namespaces:
$ vault namespace create -namespace=education training
$ vault namespace create -namespace=education certification
List namespaces:
$ vault namespace list
education/
finance/

$ vault namespace list -namespace=education
certification/
training/

# Command/Input

Author the namespace admin policy file:
finance-admins.hcl
# Full permissions on the finance path
path "finance/*" {
   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
C Create the policy in Vault:
# Create finance-admins policy
$ vault policy write finance-admins finance-admins.hcl
E  Generate a token associated with this policy. We are only using token for simplicity,          c  we could instead associate this policy with any other authentication method.
$ vault token create -policy=finance-admins
Key                Value
---                -----
token              1258090c-5074-fe52-d57c-f1aa304d95f2
token_accessor     fdee81f5-bcbf-b5cc-4082-025a6f0c725f
token_duration     768h
token_renewable    true
token_policies     [finance-admins]

Now let’s work as if we were a finance-admins administrator. We want to create a policy to allow a third user to only create, read, update, delete and list secrets in the path “finance/secret/app1/”.

First create a policy:
finance-app1.hcl
# Full permissions on the finance path
path "finance/secret/app1/*" {
   capabilities = ["create", "read", "update", "delete", "list"]
}
Now let’s use the token associated with the Finance namespace admin. Since we are using token authentication, you just need to export to VAULT_TOKEN

$ export VAULT_TOKEN=<finance-admin-token>

Now you can run
$ vault policy -namespace=finance write finance-app1 finance-app1.hcl 

If you try to write the policy outside the assigned namespace, you will get an error:
$ vault policy write finance-app1 finance-app1.hcl 

This demonstrates that a namespace admin can only manage users and policies of their assigned namespace.

Now let’s mount a secret engine within this namespace:
$ vault enable kv -namespace=finance -path=secret

Finally, let’s create a token associate with the app1 policy. Once again, this policy could be associated with any authentication method, we are only using token for simplicity.

$ vault token create -policy=finance-app1
Key                Value
---                -----
token              1258090c-5074-fe52-d57c-f1aa304d95f2
token_accessor     fdee81f5-bcbf-b5cc-4082-025a6f0c725f
token_duration     768h
token_renewable    true
token_policies     [finance-app1]

And now we can login as the app1 user, and validate that this user can only work within the specified constraints.

$ export VAULT_TOKEN=<app1-token>
$ vault kv -namespace=finance put secret/app1 value=test
$ vault kv -namespace=finance get secret/app1
$ vault kv -namespace=education secret/app1
# fails

