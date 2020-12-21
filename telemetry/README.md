# Background and Goals

Vault and Consul contain telemetry capabilities that support monitoring for health and utilization. Additionally, Vault audit logs contain data that should be monitored for events that indicate missue or missconfiguration that may impact the health or performance of the Vault cluster.

This guide is a walkthrough meant as a minimal viable installation of OSS tools to support telemetry and visualization using Grafana templates. There are alternatives including [Splunk](https://www.hashicorp.com/blog/splunk-app-for-monitoring-hashicorp-vault) and [Prometheus](https://medium.com/@mwieczorek/yet-another-vault-monitoring-with-prometheus-blog-post-f525c862baca).

# Pre-Reqs and References:

Setup a Vault-Consul cluster (cohabitated install) or Vault Integrated Storage cluster(s):

There are plenty of resources and guides a minimally vialble Vault cluster (single node) with Integrated Storage is an easy way to stand up a stafeful cluster with very low infrastructure overhead. By standing up and maintaining a Vault cluster, albeit a single or 3 node cluster, will allow for continue education and enablement as you continue to develop and add use cases. While you are enable these use cases, the telemetry and audit services will be helpful for troubleshooting and gaining insight info operating a Vault cluster.

[manual on VMs of your choice](https://github.com/raygj/vault-content/tree/master/cluster-bootstrap)

[AWS with Terraform](https://github.com/raygj/vault-content/tree/master/vault-aws-demo-instance)

Info:

[Vault Monitoring](https://learn.hashicorp.com/vault/operations/monitoring)

[Vault Monitoring Guide...source for this walkthrough](https://s3-us-west-2.amazonaws.com/hashicorp-education/whitepapers/Vault/Vault-Consul-Monitoring-Guide.pdf)

The [HashiCorp guide](https://s3-us-west-2.amazonaws.com/hashicorp-education/whitepapers/Vault/Vault-Consul-Monitoring-Guide.pdf)

This is the architecture the guide will be based on:

![image](/telemetry/images/lab_env.png)

# Start on the Ubuntu Telemetry/Monitoring Server

## Deploy Ubuntu instance that will serve as the monitoring host

### bootstrap

- install nano, unzip, wget as needed

## Install InfluxDB, guide [HERE](https://computingforgeeks.com/install-influxdb-on-ubuntu-18-04-and-debian-9/)

```
echo "deb https://repos.influxdata.com/ubuntu bionic stable" | sudo tee /etc/apt/sources.list.d/influxdb.list

sudo curl -sL https://repos.influxdata.com/influxdb.key | sudo apt-key add -

sudo apt-get update
sudo apt-get install influxdb

sudo systemctl enable --now influxdb

sudo systemctl influxdb
```

#### Create InfluxDB user for Telegraf agents

```

influx

CREATE USER "telegraf" WITH PASSWORD 'metrics' WITH ALL PRIVILEGES

show users

exit

```
## Install Grafana, guide [HERE](https://grafana.com/docs/grafana/latest/installation/debian/)

```
sudo apt-get install -y apt-transport-https
sudo apt-get install -y software-properties-common wget
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -

echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list

sudo apt-get update
sudo apt-get install grafana -y

sudo systemctl enable --now grafana-server

sudo systemctl grafana-server
```

### Access Grafana

http://your-server-ip:3000

Default username/password: admin/admin

# Move to the Vault/Consul servers

## Gracefully stop Vault and then Consul services

```

sudo systemctl stop vault

sudo systemctl stop consul

```

## Install Telegraf on Vault/Consul servers, guide [HERE](https://docs.influxdata.com/telegraf/v1.16/introduction/installation/)

```
wget -qO- https://repos.influxdata.com/influxdb.key | sudo apt-key add -
source /etc/lsb-release
echo "deb https://repos.influxdata.com/${DISTRIB_ID,,} ${DISTRIB_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/influxdb.list

# Before adding Influx repository, run this so that apt will be able to read the repository.

sudo apt-get update && sudo apt-get install apt-transport-https

# Add the InfluxData key

wget -qO- https://repos.influxdata.com/influxdb.key | sudo apt-key add -
source /etc/os-release
test $VERSION_ID = "7" && echo "deb https://repos.influxdata.com/debian wheezy stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
test $VERSION_ID = "8" && echo "deb https://repos.influxdata.com/debian jessie stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
test $VERSION_ID = "9" && echo "deb https://repos.influxdata.com/debian stretch stable" | sudo tee /etc/apt/sources.list.d/influxdb.list
test $VERSION_ID = "10" && echo "deb https://repos.influxdata.com/debian buster stable" | sudo tee /etc/apt/sources.list.d/influxdb.list

sudo apt-get update && sudo apt-get install telegraf
sudo systemctl start telegraf

```
### Modify Telegraf config file on Vault/Consul servers

Grab a copy of the Telegraf config [HERE](https://raw.githubusercontent.com/raygj/vault-content/master/telemetry/misc_configs_snippets/telegraf.conf)

**Update relevant config items:**

Global Tags
Outputs.influxdb > urls should be updated to point to the InfluxDB/Granfana host, for example urls = ["http://vault-telem-server:8086"] # required''

- if you are using Integrated Storage, remove the [inputs.consul] block...unless you are running Consul for service registry/discovery

urls = ["http://192.168.1.69:8086"] # required


```
sudo cp /etc/telegraf/telegraf.conf /etc/telegraf/telegraf.conf.orig

sudo rm -rf /etc/telegraf/telegraf.conf

sudo nano /etc/telegraf/telegraf.conf

sudo systemctl  restart telegraf

sudo systemctl  status telegraf


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

cp /etc/vault.d/vault-tls.hcl cp /etc/vault.d/vault-tls.hcl.orig

sudo nano /etc/vault.d/vault-tls.hcl

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

```
...
datadog.dogstatsd.client.packets_dropped_writer
datadog.dogstatsd.client.packets_sent
disk
diskio
kernel
linux_sysctl_fs
mem
net
netstat
processes
procstat
procstat_lookup
swap
system
vault.runtime.alloc_bytes
vault.runtime.free_count
vault.runtime.gc_pause_ns
...
```

`exit`

## Setup Grafana to visualize data

### Configuring the data source

Before we can create dashboards, we need to tell Grafana where to get data from. From the Grafana home screen, click "Create your first data source", select InfluxDB

Fill in the settings as follows:

```

Name: any name you like. Default: checked.
Type: InfluxQL

HTTP:
URL: http://localhost:8086
Access: default/direct

Auth: leave all options unchecked.

Advanced HTTP Settings: leave options at defaults. InfluxDB Details:

Database: telegraf
User: telegraf
Password: telegraf
HTTP Method: get

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

Now you should be able to see beautiful dashboards full of Vault (and Consul) metrics. If there are errors, you might need to customize each dashboard slightly - use the inpsect feature of Graphana to look at the query string, validate the data is being tracked and taged by Telegraf by running queries against InfluxDB directly...or use a SQL explorer of some kind.

# Vault Dashboard

![image](/telemetry/images/vault_dashboard.png)

# Consul Dashboard

![image](/telemetry/images/consul_dashboard.png)
