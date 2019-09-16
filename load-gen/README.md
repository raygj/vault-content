# Vault Load Generation

# Background and Goals

Stress-testing Vault is the goal. This guide is a walkthrough meant as a minimal viable installation of OSS tools and refers to telemetry visualization using Grafana templates from this [guide](https://github.com/raygj/vault-content/tree/master/telemetry).

# Pre-Reqs and References:

Setup a Vault-Consul cluster cohabitated install:

[manual on VMs of your choice](https://github.com/raygj/vault-content/tree/master/cluster-bootstrap)

[AWS with Terraform](https://github.com/raygj/vault-content/tree/master/vault-aws-demo-instance)

Info:

[Vault Monitoring Walkthrough](https://github.com/raygj/vault-content/tree/master/telemetry)

[Vault Monitoring](https://learn.hashicorp.com/vault/operations/monitoring)

[Vault Monitoring Guide...source for this walkthrough](https://s3-us-west-2.amazonaws.com/hashicorp-education/whitepapers/Vault/Vault-Consul-Monitoring-Guide.pdf)

# Architecture Used

The [HashiCorp guide](https://s3-us-west-2.amazonaws.com/hashicorp-education/whitepapers/Vault/Vault-Consul-Monitoring-Guide.pdf) is written for Ubuntu Vault/Consul servers, but at this time my Vault/Consul cluster is CentOS 7, so the guide will be written with that in mind. This is the architecture the guide will be based on:

![image](/telemetry/images/lab_env.png)

For this guide, you will need an additional Ubuntu host OR you could use the Grafana host if you have the telemetry infrastructure built.

# Deploy Ubuntu 18 instance that will serve as the load generation host

## Bootstrap

### Install unzip, pip3, and optionally open-vm-tools

```

sudo apt-get update

sudo apt-get install unzip -y

sudo apt install python3-pip -y

sudo apt-get install open-vm-tools -y

```

### Verify if firewall is active

```

sudo ufw status (used to manage iptables)

sudo iptables -L

```

## Clone repo

```

mkdir /home/<user name>/githome

cd /<user-name>/githome 

git clone https://github.com/tradel/vault-load-testing.git

cd /home/<user name>/githome/vault-load-testing

```

### Install requirements

`pip3 install -r requirements.txt`

Dynamic Secrets requires MongoDB or MySQL backend connected and available

Set environment vars for DB:

```

export MONGODB_URL="mongodb://localhost:27017/admin"

export MYSQL_URL="root:password@tcp(127.0.0.1:3306)/mysql"

```

If you do not have a DB available, copy the original locustfile.py and then remove the database lines and DB references in the __dynamic__ line

![image](/load-gen/images/locust_config.png)

## Set VAULT_TOKEN environment variable

`export VAULT_TOKEN=< some token with appropriate policy>`

### Run Prepare script with target of Vault cluster (IP or DNS name)

#### OPTIONAL: Consul DNS on the load-gen host

go [here](https://github.com/raygj/consul-content) for more info on Consul DNS used for service discovery

unzip /tmp/consul_1.4.3_linux_amd64.zip -d /home/<user name>/consul/

# setup log dir

```

mkdir -p /home/<user>/consul/log

touch /home/<user>/consul/log/output.log

mkdir /tmp/consul

```

##### Start consul, running in background

`sudo /home/<user>/consul/consul agent -data-dir="/tmp/consul" -bind=<local IP> -client=<local IP> >> /home/<user>/consul/log/output.log &`


check log for startup result

`tail -20 /home/<user>/consul/log/output.log`

join agent client to existing server cluster
`/home/<user>/consul/consul join -http-addr=<ip of this machine>:8500 <ip of the consul server agent>`

verify join on consul cluster

`consul members`

validate consul DNS from client

`dig @< IP of local Consul agent in client mode> -p 8600 vault.service.dc1.consul. ANY`

## NEXT STEP - create test data locally

This step will generate a “testdata.json” file that can be reused on other load-gen servers

`VAULT_TOKEN="<vault token>" ./prepare.py  --host="http://<IP or DNS name of Vault Cluster:8200"`

Modify PATH variable to point to Python3.6

```

nano ~/.profile

# set PATH so it includes user's private bin if it exists
if [ -d "$HOME/.local/bin" ] ; then
    PATH="$HOME/.local/bin/python3.6:$PATH"
fi

```

reload profile

`source ~/.profile`

# Execute locust

Choose headless CLI or web GUI mode

## headless CLI only

```

cd /home/<user name>/githome/vault-load-testing

locust -H http://<Vault IP or DNS name>:8200 -c 25 -r 5 --no-web

```

# Web GUI

```

cd /home/<user name>/githome/vault-load-testing

locust -H http://<Vault IP or DNS name>:8200 -c 25 -r 5

```

Log into the GUI: http://<IP of the locust server>:8089

Enter the number of users and hits, then start swarming

![image](/load-gen/images/locust_ui.png)

# Visualize the Chaos

Go to Grafana Vault and Consul Cluster Health dashboards, set time table to “last 5 mins” and watch KPIs as load hits cluster

**Vault Dashboard**

![image](/load-gen/images/vault_dashboard_unhappy.png)


**Consul Dashboard**


![image](/load-gen/images/consul_dashboard_stress.png)