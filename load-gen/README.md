Load Generation

Deploy Ubuntu 18 instance that will serve as the load generation host
Install unzip, pip3, and optionally open-vm-tools

sudo apt-get update
sudo apt-get install unzip -y
sudo apt install python3-pip -y
sudo apt-get install open-vm-tools -y

Verify if firewall is active
sudo ufw status (used to manage iptables)
sudo iptables -L

Clone repo
mkdir /home/<user name>/githome
cd /<user-name>/githome 
git clone https://github.com/tradel/vault-load-testing.git
cd /home/<user name>/githome/vault-load-testing

Install requirements

pip3 install -r requirements.txt

Dynamic Secrets requires MongoDB or MySQL backend connected and available
Set environment vars for DB:
export MONGODB_URL="mongodb://localhost:27017/admin"
export MYSQL_URL="root:password@tcp(127.0.0.1:3306)/mysql"

If you do not have a DB available, copy the original locustfile.py and then remove the database lines and DB references in the __dynamic__ line


Set VAULT_TOKEN environment variable
Run Prepare script with target of Vault cluster (IP or DNS name)
OPTIONAL: Consul DNS on the load-gen host
OPTIONAL
unzip /tmp/consul_1.4.3_linux_amd64.zip -d /home/<user name>/consul/
# setup log dir
mkdir /home/<user>/consul/
mkdir /home/<user>/consul/log/
touch /home/<user>/consul/log/output.log
mkdir /tmp/consul
#
# start consul, running in background
sudo /home/<user>/consul/consul agent -data-dir="/tmp/consul" -bind=<local IP> -client=<local IP> >> /home/<user>/consul/log/output.log &
#
# check log for startup result
tail -20 /home/<user>/consul/log/output.log
#
# join agent client to existing server cluster
 /home/<user>/consul/consul join -http-addr=<ip of this machine>:8500 <ip of the consul server agent>
#
# verify join on consul cluster
consul members
# validate consul DNS from client
dig @< IP of local Consul agent in client mode> -p 8600 vault.service.dc1.consul. ANY



NEXT STEP - create test data locally, generates a “testdata.json” file that can be reused on other load-gen servers

VAULT_TOKEN="<vault token>" ./prepare.py  --host="http://<IP or DNS name of Vault Cluster:8200"

Modify PATH variable to point to Python3.6
nano ~/.profile

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin/python3.6:$PATH"
fi

Save and logout of session

Execute locust
Headless CLI only

cd /home/<user name>/githome/vault-load-testing
locust -H http://<Vault IP or DNS name>:8200 -c 25 -r 5 --no-web

Web GUI
cd /home/<user name>/githome/vault-load-testing
locust -H http://<Vault IP or DNS name>:8200 -c 25 -r 5

Log into the GUI: http://<IP of the locust server>:8089
Enter the number of users and hits, then start swarming

![image](/load-gen/images/locust.png)


