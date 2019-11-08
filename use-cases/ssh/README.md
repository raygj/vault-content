# SSH Use Case

automate SSH one-time passwords and signed SSH keys to *nix and Windows Server hosts

## Resources

[OpenSSH in Windows](https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_overview)

[HashiConf SSH Preso](https://www.hashicorp.com/resources/manage-ssh-with-hashicorp-vault)

[learn.hashicorp guide](https://learn.hashicorp.com/vault/secrets-management/sm-ssh-otp)

## Environment

- Vault server
- Ubuntu 18 VM
- Windows Server 2016 VM

## Bootstrap Windows OpenSSH

[Installing OpenSSH with PowerShell](https://docs.microsoft.com/en-us/windows-server/administration/openssh/openssh_install_firstuse#installing-openssh-with-powershell)

### validate OpenSSH feature is available to install

`Get-WindowsCapability -Online | ? Name -like 'OpenSSH*'`

- if not, troubleshoot:

```
	
gpedit.msc (or create a GPO)

Administrative Templates\System\"Specify settings for optional component installation and component repair"

check the checkbox "Download repair content and optional features directly from Windows Update instead of Windows Server Update Service (WSUS)"

if not available, click "enable" to enable the policy and then check the checkbox

run gpupdate from a CMD prompt

```

### install OpenSSH client

`Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0`

### install OpenSSH server

`Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0`

