# SSH Use Case

support SSH one-time passwords, with TTLs, and signed SSH keys to *Nix hosts

**note** although recent versions of Windows Server support SSH, the Vault SSH Helper is not compiled to run in Windows. this may be added as an appendix to this walkthrough in the near future.

## Overview

An authenticated client requests an OTP from the Vault server. If the client is authorized, Vault issues and returns an OTP. The client uses this OTP during the SSH authentication to connect to the desired target host.

When the client establishes an SSH connection, the OTP is received by the Vault helper which validates the OTP with the Vault server. The Vault server then deletes this OTP, ensuring that it is only used once.

## Resources

[OpenSSH in Windows](https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_overview)

[HashiConf SSH Preso](https://www.hashicorp.com/resources/manage-ssh-with-hashicorp-vault)

[learn.hashicorp guide](https://learn.hashicorp.com/vault/secrets-management/sm-ssh-otp)

[Vault-SSH-Helper repo](https://github.com/hashicorp/vault-ssh-helper#vault-ssh-helper-configuration)

## Environment

- Vault server
- Ubuntu 18 VM
- Windows Server 2016 VM

**note** for production, it is assumed Vault is running in TLS mode and would have a valid cert and CA cert that can be used in the Vault SSH Helper config so endpoints can validate the Vault server when setting up SSH login.

## Bootstrap Ubuntu

### download and install HashiCorp vault-ssh-helper binary

- download the vault-ssh-helper

`wget https://releases.hashicorp.com/vault-ssh-helper/0.1.4/vault-ssh-helper_0.1.4_linux_amd64.zip`

- unzip the vault-ssh-helper in /user/local/bin

`sudo unzip -q vault-ssh-helper_0.1.4_linux_amd64.zip -d /usr/local/bin`

- make sure that vault-ssh-helper is executable

`sudo chmod 0755 /usr/local/bin/vault-ssh-helper`

- set the usr and group of vault-ssh-helper to root

`sudo chown root:root /usr/local/bin/vault-ssh-helper`

### create Vault SSH helper config

[reference on config options](https://github.com/hashicorp/vault-ssh-helper#vault-ssh-helper-configuration)

`sudo mkdir /etc/vault-ssh-helper.d/`

`sudo nano /etc/vault-ssh-helper.d/config.hcl`

- production version, using PEM-encoded CA cert file specified in the `ca_cert` value. this CA cert is used by the client to verify Vault server's TLS certificate **assumes Vault is running in TLS mode**

```

vault_addr = "https://<VAULT_ADDRESS>:8200"
ssh_mount_point = "ssh"
ca_cert = "/etc/vault-ssh-helper.d/vault.crt"
tls_skip_verify = false
allowed_roles = "*"

```

- sandbox version, using -dev to ignore cert requirement

```

vault_addr = "http://<VAULT_ADDRESS>:8200"
ssh_mount_point = "ssh"
ca_cert = "-dev"
tls_skip_verify = true
allowed_roles = "*"

```

#### validate ssh-helper is configured properly

`vault-ssh-helper -verify-only -config=/etc/vault-ssh-helper.d/config.hcl`

if successful, you will see a message such as:

```

Using SSH Mount point: ssh
vault-ssh-helper verification successful!

```


### modify existing SSHD config

`sudo cp /etc/pam.d/sshd /etc/pam.d/sshd.orig`

`sudo nano /etc/pam.d/sshd`

- comment-out `@include common-auth` and add custom Vault lines

```

#@include common-auth
auth requisite pam_exec.so quiet expose_authtok log=/tmp/vaultssh.log /usr/local/bin/vault-ssh-helper -config=/etc/vault-ssh-helper.d/config.hcl
auth optional pam_unix.so not_set_pass use_first_pass nodelay

```

#### dev mode

for sandbox where Vault is not running with TLS enabled

`sudo cp /etc/pam.d/sshd /etc/pam.d/sshd.orig`

`sudo nano /etc/pam.d/sshd`

- comment-out `@include common-auth` and add custom Vault lines

```

#@include common-auth
auth requisite pam_exec.so quiet expose_authtok log=/tmp/vaultssh.log /usr/local/bin/vault-ssh-helper -dev -config=/etc/vault-ssh-helper.d/config.hcl
auth optional pam_unix.so not_set_pass use_first_pass nodelay

```

**note** the presence of `-dev` in the /user/local/bin/vault-ssh-helper command string, this tells vault-ssh-helper it is OK to use HTTP and not validate a cert

### modify existing SSHD_CONFIG

`sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.orig`

`sudo nano /etc/ssh/ssh_config`

- add these lines to enable the keyboard-interactive authentication and PAM authentication modules (the password authentication is disabled).

```

ChallengeResponseAuthentication yes
PasswordAuthentication no
UsePAM yes

```

- restart SSH service

`sudo systemctl restart sshd`

## Vault Configuration

### enable SSH secrets engine

`vault secrets enable ssh`

### create a role

- a role is created for each user (default user)
- the CIDR block should be as granular as possible, wildcard (0.0.0.0/0) for testing only
- uses One-Time-Password (OTP) engine

```

vault write ssh/roles/otp_key_role key_type=otp \
        default_user=jray \
        cidr_list=0.0.0.0/0

```

### create SSH policy

- create policy file

```

cat << EOF > /tmp/ssh-user.hcl

path "ssh/*" {
  capabilities = [ "list", "read", "create", "update" ]
}
EOF

```

- write contents of policy HCL to Vault policy `ssh-user`

`cat /tmp/ssh-user.hcl | vault policy write ssh-user -`

- verify policy was written

`vault read sys/policy`

- map policy to existing group being used to auth, in this case an AD group used for LDAP auth to Vault

`vault write auth/ldap/groups/vault-auth-group policies="windows-kv-ro,ssh-user"`

## User Persona; Request OTP

to generate an OTP credential for an IP of the remote host belongs to the otp_key_role:

### using the Vault UI

1. Select `ssh` under Secrets Engines.

![diagram](/images/vault-ssh-00.png)

2. Select `otp_key_role` and enter < username defined in role > in the Username field, and enter the target host's IP address (e.g. 192.0.2.10) in the IP Address field.

![diagram](/images/vault-ssh-01.png)

3. Click Generate.

![diagram](/images/vault-ssh-02.png)

4. Click Copy credentials. This copies the OTP (key value).

5. Open CLI terminal and SSH to the host who's IP you entered in the OTP generation field, using the username you entered

```

[root@vault-oss-node tmp]# ssh jray@192.168.1.179
jray@192.168.1.179's password:

```

when prompted, paste the OTP you copied from the Vault UI

6. Success!

7. It's a OTP, so logout and try to use it again - **denied**

### using an API call

- set Vault token env var

`export VAULT_TOKEN=<vault token with access to SSH policy>`

- request OTP

`curl --header "X-Vault-Token: $VAULT_TOKEN" --request POST --data '{"ip": "192.168.1.207"}' http://192.168.1.159:8200/v1/ssh/creds/otp_key_role  | jq`

- response

```

{
  "request_id": "5b4885f7-00d6-09f8-9cd7-43c61b9e0490",
  "lease_id": "ssh/creds/otp_key_role/yBMVPqkAvbJ4kcAYe3u9bgQx",
  "renewable": false,
  "lease_duration": 2764800,
  "data": {
    "ip": "192.168.1.207",
    "key": "06e1e013-8bc7-bc69-3dad-d2043098de35",
    "key_type": "otp",
    "port": 22,
    "username": "jray"
  },
  "wrap_info": null,
  "warnings": null,
  "auth": null
}

```

## Troubleshooting

- use `vault-ssh-helper -verify-only -config=/etc/vault-ssh-helper.d/config.hcl` to verify the remote agent's config is valid and can talk to Vault
- if needed, setup tcpdump to capture traffic on the Vault server from the remote host `tcpdump -i <interface name> host <remote host IP>`

# Appendix: SSH Basics

## create new SSH key

this will overwrite any existing key in your `~/.ssh` directory

`ssh-keygen -t rsa -b 4096 -C "name@github.com"`

**note**apparently there is a known issue with Terraform not being able to process a password-protected private key, see [here](https://github.com/yugabyte/terraform-gcp-yugabyte/issues/10)

## copy your SSH key to a host

`ssh-copy-id -i ~/.ssh/id_rsa user@host`

_This logs into the server host, and copies keys to the server, and configures them to grant access by adding them to the authorized_keys file. The copying may ask for a password or other authentication for the server._

## store passphrase in Mac Keychain

`ssh-add -K ~/.ssh/id_rsa`

`nano ~/.ssh/config`

```

Host *
  UseKeychain yes
  AddKeysToAgent yes
  IdentityFile ~/.ssh/id_rsa

```
