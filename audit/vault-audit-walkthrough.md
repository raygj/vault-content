## configure audit log

- if needed, setup dirs

```
sudo touch /var/log/vault_audit.log
sudo chown vault:vault /var/log/vault_audit.log
```

- enable audit in Vault (once unsealed)

`vault audit enable file file_path=/var/log/vault_audit.log`

## sample queries

[ref](https://learn.hashicorp.com/tutorials/vault/query-audit-device-logs?in=vault/monitoring)

- SSH to a node in the primary Vault cluster

- set an env var for the target location of the Vault audit log that has been enabled

export AUDIT_LOG_FILE=/var/log/vault_audit.log

- look for all errors and counts

`sudo jq -n '[inputs | {Errors: .error} ] | group_by(.Errors) | map({Errors: .[0].Errors, Count: length}) | sort_by(-.Count) | .[]' $AUDIT_LOG_FILE`

- collect operations and counts

`sudo jq -n '[inputs | {Operation: .request.operation} ] | group_by(.Operation) | map({Operation: .[0].Operation, Count: length}) | .[]' $AUDIT_LOG_FILE`

- collect requested paths and counts

`sudo jq -n '[inputs | {Path: .request.path} ] | group_by(.Path) | map({Path: .[0].Path, Count: length}) | sort_by(-.Count) | limit(5;.[])' $AUDIT_LOG_FILE`

- remote address by count

`sudo jq -n '[inputs | {RemoteAddress: .request.remote_address} ] | group_by(.RemoteAddress) | map({RemoteAddress: .[0].RemoteAddress, Count: length}) | .[]' $AUDIT_LOG_FILE`
