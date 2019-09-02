# Vault Demo

[Courtesy of tdsacilowski](https://github.com/tdsacilowski/vault-demo)

Terraform code to spin up a stand-alone demo Vault instance along with resources to be used while following along when implementing the various Vault auth methods and secrets engines.

- Clone this repo
- Update TF variables copy terraform.tfvars.example > terraform.tfvars and update values accordingly
- Run `terraform init`
- Check that the right resources will be built with `terraform plan`
- If all looks good, deploy the environment with `terraform apply`