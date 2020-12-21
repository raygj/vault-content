##setup Vault on Windows Server

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







#appendix

#reset windows activation timer

1. administrator PS command prompt
2. `slmgr.vbs -rearm`
3. reboot
