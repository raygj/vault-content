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

The [HashiCorp guide](https://s3-us-west-2.amazonaws.com/hashicorp-education/whitepapers/Vault/Vault-Consul-Monitoring-Guide.pdf) is written for Ubuntu Vault/Consul servers, but at this time my Vault/Consul cluster is CentOS 7, so this is the architecture the guide will be based on:

![image](/telemetry/images/lab_env.png)