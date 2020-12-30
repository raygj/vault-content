# basic script to pull data from a file and write it to an environment variable
# then print the environment variable
# used to demo Vault Agent on Windows interacting with a PowerShell script
function Get-TimeStamp {

    return "[{0:MM/dd/yy} {0:HH:mm:ss}]" -f (Get-Date)

}
Write-Output "$(Get-TimeStamp) Vault Agent Processing New/Update Secret..."
$file_data = Get-Content C:\vault\agent\command_uc\secret.txt
$file_data[2] | Set-Variable -Name "password" -Scope global
Get-Variable "password"

# use this to interrogate the source data file to determine the row where the data resides
# Get-Content C:\vault\agent\command_uc\secret.txt | Measure-Object
