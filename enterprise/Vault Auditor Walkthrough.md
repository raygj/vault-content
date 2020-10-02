# Vault Auditor Walkthrough

_Vault auditor is a publicly available command line tool which runs on Linux and MacOS that parses through Vault audit logs sitting on the filesystem and returns a client count seen in those logs. The tool does not connect to Vault directly and only operates on log data._

## requirements

- Vault 1.3 - 1.5 releases are supported
  - Vault 1.6 will include this functionality when released
- audit must be enaabled
- minimum of one month's data to start

## enable logging

if logging is not currently enabled, follow these steps and get a cup of coffee (minimum of one month's audit data recommended)

- create target log file (ensure target filesystem has adequate space)

`sudo touch /var/log/vault_audit.log`

- transfer ownership to _vault_ user tied to the system service

`sudo chown vault:vault /var/log/vault_audit.log`


- enable Vault audit

`vault audit enable file file_path=/var/log/vault_audit.log`

**note** it is [recommended](https://www.vaultproject.io/docs/audit) that more than one audit target is used, this could be a second filesystem path, syslog, or socket target.

## view log contents

- Vault logs are in JSON format, use jq utility to make them human-friendly when viewing in a console

`sudo tail -f /var/log/vault_audit.log | jq`

- execute functions in Vault to see audit activity

## pull log(s) file to a local system

- it is recommended to pull logs from a central source for analysis on a system that is NOT running Vault
- when functionality is added in Vautl 1.6 there will be a `usage` command added that can be used within a cluster
- Vault Auditor can process multiple logs, a single log is used in the exmaples that follow
- logs from each Primary and Secondary Performance cluster should be analyzed

`sudo cp /var/log/vault_audit.log /tmp/vault_audit.log`

`sudo chown ubuntu:ubuntu /tmp/vault_audit.log`

`scp -i jray.pem ubuntu@xx.yy.xx.yy:/tmp/vault_audit.log /Users/jray/Documents/hashi/vault-auditor/logs`

## download Vault Auditor

- MacOS

https://releases.hashicorp.com/vault-auditor/1.0.1/vault-auditor_1.0.1_darwin_amd64.zip

- unzip
- copy to a standard location

`cp vault-auditor /Users/jray/Documents/hashi/vault-auditor/`

- *nix

https://releases.hashicorp.com/vault-auditor/1.0.1/vault-auditor_1.0.1_linux_amd64.zip

## execute

- run Vault Auditor against a specific log

`./vault-auditor parse /some/path/to/log/file(s)`

- to parse a time period within a logset

`vault-auditor parse -start-date=2020-07-01 -end-date=2020-07-31 ./`

### example environemnt

- in this scenario i setup Vault as a root user, created two users within Userpass auth method, logged in as those users, then pulled the log file, and analyzed it.
- expectation is that client count would be (1) for root user and (2) for the non-root Userpass users that were created
- run analysis

`./vault-auditor parse /Users/jray/Documents/hashi/vault-auditor/logs`


```
Distinct Entities: 2
Non-Entity Tokens: 1
Total Clients: 3
Total files processed: 1
Date range: 2020-10-02T18:02:13Z - 2020-10-02T18:19:03Z
```

**note** Non-Entity tokens are tokens not associated with an entity, either as a result of a root token, orphan token or batch token creation (and usage).
