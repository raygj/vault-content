# Background and Goals

Vault and Consul contain telemetry capabilities that support monitoring for health and utilization. This guide is a walkthrough meant as a minimal viable installation of OSS tools to support telemetry visualization using Grafana templates. There are alternatives including using [Prometheus](https://prometheus.io/) or Splunk.

# Pre-Reqs and References:

Setup a Vault-Consul cluster cohabitated install:

[manual on VMs of your choice](https://github.com/raygj/vault-content/tree/master/cluster-bootstrap)

[AWS with Terraform](https://github.com/raygj/vault-content/tree/master/vault-aws-demo-instance)

Info:

[Vault Monitoring](https://learn.hashicorp.com/vault/operations/monitoring)

[Vault Monitoring Guide...source for this walkthrough](https://s3-us-west-2.amazonaws.com/hashicorp-education/whitepapers/Vault/Vault-Consul-Monitoring-Guide.pdf)

# Architecture Used

The [HashiCorp guide](https://s3-us-west-2.amazonaws.com/hashicorp-education/whitepapers/Vault/Vault-Consul-Monitoring-Guide.pdf) is written for Ubuntu Vault/Consul servers, but at this time my Vault/Consul cluster is CentOS 7, so the guide will be written with that in mind. This is the architecture the guide will be based on:

![image](/telemetry/images/lab_env.png)

# Start on the Ubuntu Telemetry/Monitoring Server

## Deploy Ubuntu instance that will server as the monitoring host

### Install nano, unzip, wget and open-vm-tools

`sudo apt-get install <package> -y`

## Verify if firewall is active, if so, add required ports to support connectivity inbound from Telegraf agents

`sudo ufw status` (used to manage iptables)

`sudo iptables -L`

## Install InfluxDB, guide [HERE](https://computingforgeeks.com/install-influxdb-on-ubuntu-18-04-and-debian-9/)

```

echo "deb https://repos.influxdata.com/ubuntu bionic stable" | sudo tee /etc/apt/sources.list.d/influxdb.list

sudo curl -sL https://repos.influxdata.com/influxdb.key | sudo apt-key add -

sudo apt-get update

sudo apt-get install -y influxdb

sudo systemctl enable --now influxdb

sudo systemctl is-enabled influxdb

systemctl status influxdb

```

## Install Grafana

```

curl -s https://packagecloud.io/install/repositories/grafana/stable/script.deb.sh | sudo bash

sudo apt-get update -y

sudo apt-get install grafana -y

sudo systemctl daemon-reload

sudo systemctl enable grafana-server

sudo systemctl start grafana-server

sudo systemctl status grafana-server

```

### Access Grafana

http://your-server-ip:3000

Default username/password: admin/admin

#### Create InfluxDB user for Telegraf agents

```

influx

CREATE USER "telegraf" WITH PASSWORD 'metrics' WITH ALL PRIVILEGES

show users

exit

```

# Move to the Vault/Consul servers

## Gracefully stop Vault and then Consul services

```

sudo systemctl stop vault

sudo systemctl stop consul

```

## Install Telegraf on Vault/Consul servers

`nano /etc/yum.repos.d/influxdata.repo`

```

[influxdb]
name = InfluxDB Repository - RHEL \$releasever
baseurl = https://repos.influxdata.com/rhel/\$releasever/\$basearch/stable
enabled = 1
gpgcheck = 1
gpgkey = https://repos.influxdata.com/influxdb.key

```

`yum install telegraf -y`

### Modify Telegraf config file on Vault/Consul servers

Suggest using scp to copy template up to each server rather than hand-editing, grab a copy [HERE](https://github.com/raygj/vault-content/blob/master/telemetry/misc_configs_snippets/telegraf.conf)


```

rm -rf /etc/telegraf/telegraf.conf

nano /etc/telegraf/telegraf.conf

systemctl restart telegraf

systemctl status telegraf

```

### Test telegraf config

`telegraf -config /etc/telegraf/telegraf.conf -test`

## Create Consul telemetry config file

```

cat << EOF > /etc/consul.d/consul-telem.json
{
  "telemetry": {
    "dogstatsd_addr": "localhost:8125",
    "disable_hostname": true
 }
}
EOF

```

## Modify Vault config file to include telemetry stanza

```

cp /etc/vault.d/vault-no-tls.hcl cp /etc/vault.d/vault-no-tls.hcl.orig

nano /etc/vault.d/vault-no-tls.hcl

telemetry {
  dogstatsd_addr   = "localhost:8125"
  disable_hostname = true
}

```

## In the following order start Consul, Vault and Telegraf services

`sudo systemctl start consul/vault/telegraf`

_Repeat on the other nodes in the cluster_

# Move back to the Ubuntu Telemetry/Monitoring Server

## Check InfluxDB for data from Telegraf agent

```

influx -username ‘telegraf’ -password 'metrics'

show databases

use telegraf

show measurements 

```

**NOTE** at this point you should see consul, OS (CPU/disk/process) and Vault KPIs

`exit`

## Setup Grafana to visualize data

### Configuring the data source

Before we can create dashboards, we need to tell Grafana where to get data from. From the Grafana home screen, click "Create your first data source", or go to the sidebar menu and choose Configuration > Data Sources and then click "Add a data source".

Fill in the settings as follows:

```

Name: any name you like. Default: checked.
Type: InfluxDB.

HTTP:
URL: http://localhost:8086
Access: direct

Auth: leave all options unchecked.

Advanced HTTP Settings: leave options at defaults. InfluxDB Details:

Database: telegraf User: telegraf Password: telegraf

Min time interval: 10s (matches the Telegraf agent interval setting)

```

Make sure your screen looks like this screenshot, ![image](/telemetry/images/configure_data_source.png) 


...then click "Save & Test". You should see messages indicating that "Data source is working" and "Data source saved". If not, double check your entries.

### Import the sample dashboards

Templates are located [HERE](https://github.com/raygj/vault-content/tree/master/telemetry/dashboard_templates)

We have provided sample dashboards for Vault and Consul here. To import them into your own Grafana server:

1. Download the dashboards to your machine.
2. Open the Grafana web interface. In the sample project, this would be at http://localhost:3000.
3. Click the "plus" icon to open the Create menu, and select Import.
4. Click the green "Upload JSON File" button.
5. Browse to the first dashboard file and upload it.
6. From the dropdown list, select the data source you created earlier.
7. Click "Import".

GOTCHA: make sure the values of the datacenter= and role= tags match the values specified in the Grafana dashboard templates. If they do not match, data will not be displayed. You can verify the active tag values by checking your Telegraf config or issuing systemctl status telegraf and noting the output, such as:

![image](/telemetry/images/dc_tag_gotcha.png)

Now you should be able to see beautiful dashboards full of Vault and Consul metrics. If there are errors, you might need to customize each dashboard slightly. Depending on the versions of Vault and Consul you have, some metrics may not be available or may have been renamed.

# Vault Dashboard

![image](/telemetry/images/vault_dashboard.png)

# Consul Dashboard

![image](/telemetry/images/consul_dashboard.png)