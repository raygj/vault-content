##setup Vault on Windows Server

###download and prepare Vault binary

- [download Vault from release.hashicorp](https://releases.hashicorp.com/vault/)
- unzip to dedicated folder, e.g., c:\vault
- set path

`control panel > system and security > system > advanced system settings > environment variables`

- select `Path` and then `Edit...`
- add the path to vault.exe with leading and trailing ";" for example:

`%USERPROFILE%\AppData\Local\Microsoft\WindowsApps;c:\vault;`

- close all windows/prompts
- open a new command prompt and verify path statement is correct

command `vault` should return info on vault binary, if not, troubleshoot path statement

##start a vault server
- start vault in dev mode to test environment

`vault server -dev`

- open a new command prompot and set VAULT_ADDR environment variable on the Vault node

`set VAULT_ADDR=http://127.0.0.1:8200`

- verify with vault status, should report vault is unsealed

`vault status`

- use `ctrl-c` to stop the vault server

##start a vault agent

- open a command prompot and set VAULT_ADDR environment variable on the Vault node

`set VAULT_ADDR=https://vault-ent-node-1:8200`

###using cert auth for Windows

- cert signed by CA, stored as .crt file in C:\vault\certs

```
c:\vault\certs>dir
 Volume in drive C has no label.
 Volume Serial Number is 10DC-0E88

 Directory of c:\vault\certs

12/28/2020  11:20 AM    <DIR>          .
12/28/2020  11:20 AM    <DIR>          ..
12/21/2020  06:44 PM             3,825 vault-client.crt
```
- import cert to Personal cert store for current user

####manual auth attempt

vault login -method=cert -ca-cert=c:\vault\certs\lab_ca.crt -client-cert=c:\vault\certs\vault-client.crt -client-key=c:\vault\certs\vault-client.key name=web

####auto-auth

- Vault agent config c:\vault\agent\auto_auth-conf.hcl

```
exit_after_auth = true #run once, then exit
pid_file = "./pidfile"

auto_auth {
    method "cert" {
        mount_path = "auth/cert"
        config = {
            name = "web"
            ca_cert = "c:\\vault\\certs\\lab_ca.crt"
            client_cert = "c:\\vault\\certs\\vault_client.crt"
            client_key = "c:\\vault\\certs\\vault_client.key"
        }
    }

vault {
  address = "https://vault-ent-node-1:8200"
}

    sink "file" {
        config = {
            path = "c:\\vault\\vault_token_via_agent\\here_is_your_token.txt"
        }
    }
}
```

- run Vault agent manually

vault agent -config=c:\vault\agent\auto_auth-conf.hcl -log-level=debug

- Vault agent config with token wrapping enabled

```
exit_after_auth = true #run once, then exit
pid_file = "./pidfile"

auto_auth {
    method "cert" {
        mount_path = "auth/cert"
        config = {
            name = "web"
            ca_cert = "c:\\vault\\certs\\lab_ca.crt"
            client_cert = "c:\\vault\\certs\\vault_client.crt"
            client_key = "c:\\vault\\certs\\vault_client.key"
        }
    }

vault {
  address = "https://vault-ent-node-1:8200"
}

    sink "file" {
      wrap_ttl = "10m"
        config = {
            path = "c:\\vault\\vault_token_via_agent\\here_is_your_token.txt"
        }
    }
}
```
###Agent Template COMMAND use case

- start with a working Vault Agent Configuration

exit_after_auth = true #run once, then exit
pid_file = "./pidfile"

auto_auth {
    method "cert" {
        mount_path = "auth/cert"
        config = {
            name = "web"
            ca_cert = "c:\\vault\\certs\\lab_ca.crt"
            client_cert = "c:\\vault\\certs\\vault_client.crt"
            client_key = "c:\\vault\\certs\\vault_client.key"
        }
    }

vault {
  address = "https://vault-ent-node-1:8200"
}

    sink "file" {
      wrap_ttl = "10m"
        config = {
            path = "c:\\vault\\vault_token_via_agent\\here_is_your_token.txt"
        }
    }
}

template {
destination = "c:\\vault\\agent\\command_uc\\secret.txt"
contents = <<EOT

{{ with secret "demo/myapp/config/" }}
{{ .Data.current_password }}
{{ end }}

EOT
command = "c:\\vault\agent\command_uc\\powershell_to_execute.ps"
}


####PowerShell and Windows Info

- run PowerShell from cmd.exe:

powershell -noexit "& ""C:\my_path\yada_yada\run_import_script.ps1""" (enter)

- PowerShell non-interactive:

powershell.exe -NonInteractive -Command "Remove-Item 'D:\Temp\t'"

powershell.exe -NonInteractive -Command ping esx01

- sample 0, fetch current password from Sink location and pipe it to an environment variable

Get-Content -Path C:\vault\agent\command_uc\secret.txt -outvariable password

- sample 0 for use within Vault Agent template:
```
function Get-TimeStamp {

    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)

}
Write-Output "$(Get-TimeStamp) Vault Agent Processing New/Update Secret..."
$file_data = Get-Content C:\vault\agent\command_uc\secret.txt
$file_data[2] | Set-Variable -Name "password" -Scope global
Get-Variable "password"

# use this to interogate the source data file to determine the row where the data resides
# Get-Content C:\vault\agent\command_uc\secret.txt | Measure-Object
```

  - use `Get-Variable "password"` to view the env var

- this command works from a powershell terminal, not sure if this works from
`Invoke-Expression 'cmd.exe /c start powershell -Command { Add-Content -Path C:\vault\agent\command_uc\status.txt | Set-Variable -Value password'`

- sample 1
#http://www.send4help.net/change-remote-windows-service-credentials-password-powershel-495
Function Set-ServiceAcctCreds([string]$strCompName,[string]$strServiceName,[string]$newAcct,[string]$newPass){
  $filter = 'Name=' + "'" + $strServiceName + "'" + ''
  $service = Get-WMIObject -ComputerName $strCompName -namespace "root\cimv2" -class Win32_Service -Filter $filter
  $service.Change($null,$null,$null,$null,$null,$null,$newAcct,$newPass)
  $service.StopService()
  while ($service.Started){
    sleep 2
    $service = Get-WMIObject -ComputerName $strCompName -namespace "root\cimv2" -class Win32_Service -Filter $filter
  }
  $service.StartService()
}

- sample 2
$account="domain\user"
$password="[IO.File]::ReadAllText("c:\vault\agent\command_uc\secret.txt")"
$service="name='servicename'"

$svc=gwmi win32_service -filter $service
$svc.StopService()
$svc.change($null,$null,$null,$null,$null,$null,$account,$password,$null,$null,$null)
$svc.StartService()

- sample 3


  - using this script in a "post build" call
# "C:\WINDOWS\Microsoft.NET\Framework\v2.0.50727\installutil.exe" myservice.exe powershell -command - < c:\psscripts\changeserviceaccount.ps1

**set contents of a file to env var**
# https://stackoverflow.com/questions/7976646/powershell-store-entire-text-file-contents-in-variable

$content = [IO.File]::ReadAllText(".\test.txt")



#####Vault Agent working sample
config and template that pulls KV value and calls PowerShell to execute password change

exit_after_auth = true #run once, then exit
pid_file = "./pidfile"

auto_auth {
    method "cert" {
        mount_path = "auth/cert"
        config = {
            name = "web"
            ca_cert = "c:\\vault\\certs\\lab_ca.crt"
            client_cert = "c:\\vault\\certs\\vault_client.crt"
            client_key = "c:\\vault\\certs\\vault_client.key"
        }
    }

vault {
  address = "https://vault-ent-node-1:8200"
}

    sink "file" {
      wrap_ttl = "10m"
        config = {
            path = "c:\\vault\\vault_token_via_agent\\here_is_your_token.txt"
        }
    }
}

template {
destination = "c:\\vault\\agent\\command_uc\\secret.txt"
contents = <<EOT

{{ with secret "demo/myapp/config/" }}
{{ .Data.current_password }}
{{ end }}

EOT

command = "powershell -command - < c:\vault\scripts\hello_world.ps1"
}

#appendix


#reset windows activation timer

1. administrator PS command prompt
2. `slmgr.vbs -rearm`
3. reboot

testacct
&72kjln23433rV
