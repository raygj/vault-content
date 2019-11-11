# SSH Use Case

support SSH one-time passwords, with TTLs, and signed SSH keys to *Nix hosts

**note** although recent versions of Windows Server support SSH, the Vault SSH Helper is not compiled to run in Windows. this may be added as an appendix to this walkthrough in the near future.

## Resources

[OpenSSH in Windows](https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_overview)

[HashiConf SSH Preso](https://www.hashicorp.com/resources/manage-ssh-with-hashicorp-vault)

[learn.hashicorp guide](https://learn.hashicorp.com/vault/secrets-management/sm-ssh-otp)

## Environment

- Vault server
- Ubuntu 18 VM
- Windows Server 2016 VM

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

`sudo mkdir /etc/vault-ssh-helper.d/`

```

sudo cat << EOF > /etc/vault-ssh-helper.d/config.hcl
vault_addr = "<VAULT_ADDRESS>"
ssh_mount_point = "ssh"
ca_cert = "/etc/vault-ssh-helper.d/vault.crt"
tls_skip_verify = false
allowed_roles = "*"
EOF

```

### modify existing SSHD config

`sudo cp /etc/pam.d/sshd /etc/pam.d/sshd.orig`

`sudo nano /etc/pam.d/sshd`

- comment-out `@include common-auth` and add custom Vault lines

```

#@include common-auth
auth requisite pam_exec.so quiet expose_authtok log=/tmp/vaultssh.log /usr/local/bin/vault-ssh-helper -dev -config=/etc/vault-ssh-helper.d/config.hcl
auth optional pam_unix.so not_set_pass use_first_pass nodelay

```

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

### from the Vault UI

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