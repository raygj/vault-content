# Vault Demo

[Courtesy of tdsacilowski](https://github.com/tdsacilowski/vault-demo)

Terraform code to spin up a stand-alone demo Vault instance along with resources to be used while following along when implementing the various Vault auth methods and secrets engines.

- Clone this repo
- Update TF variables copy terraform.tfvars.example > terraform.tfvars and update values accordingly
	- alternatively, configure the ingress CIDR blocks in `security-groups.tf` to whitelist your network (and block the universe)
- Run `terraform init`
- Check that the right resources will be built with `terraform plan`
- If all looks good, deploy the environment with `terraform apply`

## SSH to server and client nodes

public IPs will be displayed as outputs when the run is complete

## Web UI

http://<public IP address of server>:8200

## Initialize Vault

from CLI or UI select the number of key shards (recommend 1 for demo environment)

collect initial root token and key