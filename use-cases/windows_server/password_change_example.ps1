$account="domain\user"
$password="[IO.File]::ReadAllText("c:\vault\agent\command_uc\secret.txt")"
$service="name='servicename'"

$svc=gwmi win32_service -filter $service
$svc.StopService()
$svc.change($null,$null,$null,$null,$null,$null,$account,$password,$null,$null,$null)
$svc.StartService()
