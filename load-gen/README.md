# Vault Load Generation Walkthrough

## Background and Goals

Stress-testing Vault is the goal. This guide is a walkthrough meant as a minimal viable installation of OSS tools and refers to telemetry visualization using Grafana templates from this [guide](https://github.com/raygj/vault-content/tree/master/telemetry).

## Pre-Reqs and References:

Setup a Vault-Consul cluster cohabitated install:

[manual on VMs of your choice](https://github.com/raygj/vault-content/tree/master/cluster-bootstrap)

[AWS with Terraform](https://github.com/raygj/vault-content/tree/master/vault-aws-demo-instance)

Info:

[Vault Monitoring Walkthrough](https://github.com/raygj/vault-content/tree/master/telemetry)

[Vault Monitoring](https://learn.hashicorp.com/vault/operations/monitoring)

[Vault Monitoring Guide...source for this walkthrough](https://s3-us-west-2.amazonaws.com/hashicorp-education/whitepapers/Vault/Vault-Consul-Monitoring-Guide.pdf)

## Architecture Used

![image](/telemetry/images/lab_env.png)

you will need an additional Ubuntu host OR you could use the Grafana host if you have the telemetry infrastructure built.

- use Terraform to deploy an Ubuntu 18 load generation host, then follow steps below

# load gen host bootstrap

### install unzip, python3, and pip

```
sudo apt update

sudo apt install unzip python3 python3-pip -y
```

- validated package install is completed successfully

- python3

`python3 --version`

- pip

`python3 -m pip --version`

## prepare test engine

### clone repo

```
mkdir ~/githome

cd ~/githome

git clone https://github.com/tradel/vault-load-testing.git

cd ~/githome/vault-load-testing

```

### install required modules

- review `requirements.txt` and update as needed

```
locustio==0.14.6
click
requests
```

- install dependancies

`pip3 install -r requirements.txt`

## configure tests

- the load generator supports:
  - KV, Transit, PKI, Dynamic DB creds, and TOTP secret engine tests
  - UserPass and AppRole auth tests
- the tests are selected by modifying the `locust.py` file

- backup original file

`cp locustfile.py locustfile.py.orig`

- modify

`nano locustfile.py`

### example configurations

- KV secret engine, Userpass and AppRole auth method

```
from locusts.key_value import KeyValueLocust
from locusts.auth_userpass import UserPassAuthLocust
from locusts.auth_approle import AppRoleLocust

__static__ = [KeyValueLocust]
__auth__ = [UserPassAuthLocust, AppRoleLocust]

__all__ = __static__ + __dynamic__ + __auth__
```

## prepare data

- this step will generate a “testdata.json” file
- use a Vault token with sufficient privileges to mount new paths and write data

`VAULT_TOKEN="<vault token>" ./prepare.py  --host="http://<IP or DNS name of Vault Cluster:8200"`

# execute locust test

Choose headless CLI or web GUI mode

## headless CLI

`cd ~/githome/vault-load-testing`

`locust -H http://<Vault IP or DNS name>:8200 -c 25 -r 5 --no-web`

# UI

`cd ~/githome/vault-load-testing`

`locust -H http://<Vault IP or DNS name>:8200 -c 25 -r 5`

- log into the GUI

`http://<IP of the locust server>:8089`

- enter the number of users and hits, then start swarming

![image](/load-gen/images/locust_ui.png)

# Visualize the Chaos

go to Grafana Vault and Consul Cluster Health dashboards, set time table to “last 5 mins” and watch KPIs as load hits cluster

**Vault Dashboard**

![image](/load-gen/images/vault_dashboard_unhappy.png)


**Consul Dashboard**


![image](/load-gen/images/consul_dashboard_stress.png)


# appendix

## configure DB for dynamic creds if desired

Dynamic Secrets requires MongoDB or MySQL backend connected and available

Set environment vars for DB:

`export MONGODB_URL="mongodb://localhost:27017/admin"`

or

`export MYSQL_URL="root:password@tcp(127.0.0.1:3306)/mysql"`

**note** If you do not have a DB available, copy the original `locustfile.py` and then remove the database lines and DB references in the __dynamic__ line

![image](/load-gen/images/locust_config.png)
