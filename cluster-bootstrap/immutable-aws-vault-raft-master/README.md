# WIP – is-immutable-aws-vault-raft

Production-hardened, immutable deployment recipe for Vault 1.4+ with Raft Integrated Storage on AWS.

## Disclaimers

This is a work-in-progress, provided as-is and should be scrutinized for use in production.

## Dependencies

* Machine image built from `packer/is-vault-amzn2.json`
* Domain name in Route 53 hosted zone (requires use of AWS name servers)
* SSM parameter with **valid** TLS certificate for domain name
* SSM parameter with private key for TLS certificate
* Vault Enterprise license file

## Steps

* In AWS Systems Manager Parameter Store:
  * Create SecureString parameter with contents of TLS certificate chain
  * Create SecureString parameter with contents of TLS private key
* In Route 53:
  * Create hosted zone for domain name
* From the `examples/0-single-cluster` directory:
  * `cp default.auto.tfvars.example default.auto.tfvars`
  * Edit default.auto.tfvars values
  * `terraform init`
  * `terraform plan -out .tfplan`
  * Review plan
  * `terraform apply .tfplan`
* After provisioning, SSH to one of the Vault instances
  * Verify Vault is running with `vault status`
  * Init Vault
  * Login with initial root token
  * `vault operator raft list-peers` should report leader and followers
