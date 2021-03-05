# Vault EKS Auto-Unseal with KMS, IAM Role Auth

_the goal of this walkthrough is to provide code snippets for key configuration items to support this pattern; additional or modified configuration items may be required_

- this configuration assumes AWS IRSA is working in the EKS environment to provide pod-level IAM access
- existing deployments will require a seal migration noted in the appendix
- new or existing KMS key can be used
## Vault AWS Dependencies

- Vault [needs](https://www.vaultproject.io/docs/configuration/seal/awskms#authentication) the following permissions on the KMS key:

```
kms:Encrypt
kms:Decrypt
kms:DescribeKey
```

- These can be granted via IAM permissions on the principal that Vault uses, on the KMS key policy for the KMS key, or via KMS Grants on the key.

### steps for creating the required IAM policy and key

_assumption is that Terraform code is used to create the IAM role and KMS key, but that is beyond the scope of this guide_

- AWS KMS service create a new synchronous key called `vault` and make note of the key id, as it will be used in the IAM policy in the next step and the Vault configuration file in the following section


- Start by creating the IAM policy called `VaultKMSUnsealPolicy`

```
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": ["kms:Encrypt", "kms:Decrypt", "kms:DescribeKey"],
      "Resource": "*"
    }
  ]
}
```

**note** the `resource` value should be locked down to the specific ARN of the key

- Attach the `VaultKMSUnsealPolicy` to the existing role used by the EKS instance supporting Vault

### IRSA config

_config is outside the scope of this document, but essentially you are mapping the role created above to the policy bound to the Vault instance_

## Vault Helm Modications

- set an `awskms` seal config block for the Vault confiuguration file:

```
seal "awskms" {
  region     = "${aws_region}"
  kms_key_id = "${kms_key}"
}
```

- awskms is the module used by Vault to communicate with the AWS KMS to fetch and update the keys
- aws_region refers to the AWS region where the AWS KMS key is setup
- kms_key_id is the key id of the AWS KMS key(vault) created in the Vault AWS Dependencies section above

- And either add the role annotation to the service account in the chart values:

```
server:
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: <role-arn>
```

- or [specify](https://www.vaultproject.io/docs/platform/k8s/helm/configuration#serviceaccount) which existing K8S service account to use:

```
server:
  serviceAccount:
    create: false
    name: vault
```

- Summary

EKS will set `AWS_ROLE_ARN` and `AWS_WEB_IDENTITY_TOKEN_FILE` environment variables in the pod if [IRSA](https://aws.amazon.com/blogs/opensource/introducing-fine-grained-iam-roles-service-accounts/) is setup correctly, and the `awskms` logic will attempt to use those credentials for accessing the KMS (turn on Vault debug logging for more info in that part of the process). Then run `vault operator init` for a default of 5 _recovery key_ shards.

**note** the initialization generates recovery keys (instead of unseal keys) when using auto-unseal. Some of the Vault operations still require Shamir keys. For example, to regenerate a root token, each key holder must enter their recovery key.

# appendix

- Vault [seal migrationi](https://www.vaultproject.io/docs/concepts/seal#seal-migration) can be used to migrate an existing Vault from Shamirs Key Shards to Auto-Unseal
