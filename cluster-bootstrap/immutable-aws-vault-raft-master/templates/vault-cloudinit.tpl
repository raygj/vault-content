## template: jinja
#cloud-config
package_update: false

fs_setup:
  - label: vault-data
    filesystem: 'ext4'
    device: '/dev/sdf'
    partition: auto

mounts:
  - [ sdf, /var/lib/vault ]

write_files:
  - content: |
      aws_region: ${aws_region}
      vault_node_id: {{ v1.local_hostname }}
      vault_domain: ${vault_domain}
      vault_api_port: ${vault_api_port}
      vault_cluster_port: ${vault_cluster_port}
      vault_kms_key_id: ${vault_kms_key_id}
      vault_tls_path: ${vault_tls_path}
      vault_tls_cert_filename: ${vault_tls_cert_filename}
      vault_tls_key_filename: ${vault_tls_key_filename}
    path: /etc/vault.d/setup/vars.yml
  
  - content: |
      {
        "Comment": "Created via cloud-init",
        "Changes": [
          {
            "Action": "UPSERT",
            "ResourceRecordSet": {
              "Name": "{{ v1.local_hostname}}.${vault_domain}",
              "Type": "A",
              "TTL": 300,
              "ResourceRecords": [
                {
                  "Value": "{{ ds.meta_data.local_ipv4 }}"
                }
              ]
            }
          }
        ]
      }
    path: /etc/vault.d/setup/r53.json

  - content: complete -C "/usr/local/bin/vault" "vault"
    path: /etc/profile.d/99-vault-addr.sh

  - content: export VAULT_ADDR=https://{{ v1.local_hostname }}.${vault_domain}:${vault_api_port}
    path: /etc/profile.d/99-vault-completion.sh

runcmd:
  - aws route53 change-resource-record-sets --hosted-zone-id ${hosted_zone_id} --change-batch file:///etc/vault.d/setup/r53.json
  - aws ssm get-parameter --region ${aws_region} --with-decryption --name ${ssm_parameter_tls_certificate}  | jq --raw-output '.Parameter.Value' > /etc/vault.d/tls/certificate.pem
  - aws ssm get-parameter --region ${aws_region} --with-decryption --name ${ssm_parameter_tls_key}   | jq --raw-output '.Parameter.Value' > /etc/vault.d/tls/key.pem
  - aws ec2 describe-instances --region ${aws_region} --filters Name=tag:VaultRetryJoin,Values=${cluster_name} Name=instance-state-name,Values=pending,running | jq --raw-output '[.Reservations[].Instances[].PrivateDnsName] | map(rtrimstr(".${aws_region}.compute.internal"))' > /etc/vault.d/setup/peer_nodes.json
  - python /etc/vault.d/setup/render_vault_config.py
  - rm -rf /etc/vault.d/setup/
  - chmod 0640 /etc/vault.d/tls/*pem /etc/vault.d/vault.hcl
  - chown -R vault:vault /etc/vault.d /var/lib/vault
  - sleep 20
  - systemctl start vault
