# Vault Audit Logging and Correlation with ELK Stack

## Deploy an ELK target

[elastic install reference](https://www.elastic.co/guide/en/elasticsearch/reference/current/deb.html)
[elsastic beats reference](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-installation-configuration.html)

### install Java 8 SDK

sudo apt remove openjdk-8-jdk

java -version

### install Elastic

sudo wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

sudo apt-get install apt-transport-https

sudo echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee /etc/apt/sources.list.d/elastic-7.x.list

sudo apt-get update && sudo apt-get install elasticsearch

sudo /bin/systemctl daemon-reload

sudo /bin/systemctl enable elasticsearch.service

#### configure elastic using elasticsearch.yml

sudo cp /etc/elasticsearch/elasticsearch.yml /etc/elasticsearch/elasticsearch.yml.orig

sudo rm -rf /etc/elasticsearch/elasticsearch.yml

sudo nano /etc/elasticsearch/elasticsearch.yml

```
cluster.initial_master_nodes: ["192.168.1.69"]
discovery.seed_hosts: ["192.168.1.69"]
network.host: "192.168.1.69"
node.data: true
path.data: /var/lib/elasticsearch
path.logs: /var/log/elasticsearch
```

sudo systemctl start elasticsearch

sudo systemctl status elasticsearch

- assuming service started cleanly, verify listener

curl -X GET "localhost:9200/?pretty"

### install Kibana

sudo wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -

sudo echo "deb https://artifacts.elastic.co/packages/7.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-7.x.list

sudo apt-get update && sudo apt-get install kibana

sudo /bin/systemctl daemon-reload
sudo /bin/systemctl enable kibana.service
sudo systemctl start kibana.service

sudo systemctl status kibana.service

#### configure kibana using kibana.yml

sudo cp /etc/kibana/kibana.yml /etc/kibana/kibana.yml.orig

sudo rm -rf /etc/kibana/kibana.yml

sudo nano /etc/kibana/kibana.yml

```
...
server.port: 5601
server.host: "192.168.1.69"
...
# The Kibana server's name.  This is used for display purposes.
server.name: "kibana-vault-ent-lab"
...
# The URLs of the Elasticsearch instances to use for all your queries.
elasticsearch.hosts: ["http://192.168.1.69:9200"]
...
```

sudo systemctl restart kibana.service

sudo systemctl status kibana.service

- access Kibana

http://YOURDOMAIN.com:5601

http://192.168.1.69:5601

#### troubleshooting

- [yaml linter](http://www.yamllint.com)for those hard-to-find spaces

## Vault Node Configuration
Your logging strategy should include more than one audit target as Vault will not process transactions if audit is enabled, but non of the configured audit targets are available.

### enable Vault audit logging
- enable audit with a root or admin-policy backed token in Vault

vault audit enable file file_path=/var/log/vault_audit.log

- setup audit target dir; this will be the target that Filebeat watches

sudo touch /var/log/vault_audit.log
sudo chown vault:vault /var/log/vault_audit.log

- note on clean log rotation in the [Vault docs](https://www.vaultproject.io/docs/audit/file#log-file-rotation)

...configure your log rotation software to send the vault process a signal hang up `/ SIGHUP` after each rotation of the log file.

### using files for manual troubleshooting locally

- tail audit log with JQ for real time debugging

`sudo tail -f /var/log/vault_audit.log | jq`

- real time view of "non-empty" errors

`sudo tail -f /var/log/vault_audit.log | jq 'select(.error != null) | select(.error != "") | [.time,.error] | @sh' $AUDIT_LOG_FILE`

### install and configure Filebeat

#### install
sudo curl -L -O https://artifacts.elastic.co/downloads/beats/filebeat/filebeat-7.10.1-amd64.deb
sudo dpkg -i filebeat-7.10.1-amd64.deb

#### configure
[reference filebeat config options](https://www.elastic.co/guide/en/beats/filebeat/current/filebeat-input-log.html#filebeat-input-log-config-json)

sudo cp /etc/filebeat/filebeat.yml /etc/filebeat/filebeat.yml.orig

sudo rm -rf /etc/filebeat/filebeat.yml

sudo nano /etc/filebeat/filebeat.yml

```
---
filebeat.inputs:
  -
    json.add_error_key: true
    json.keys_under_root: true
    paths:
      - /var/log/vault_audit.log
    type: log
output.elasticsearch:
  hosts:
    - "192.168.1.69:9200"
```

sudo systemctl restart filebeat

sudo systemctl status filebeat

- look for an entry such as the following to indicate logs are being read and parsed

```
log/harvester.go:302        Harvester started for file: /var/log/vault_audit.log

pipeline/output.go:151#011Connection to backoff(elasticsearch(http://192.168.1.69:9200)) established

vault-ent-node-2 filebeat[22164]: 2020-12-21T00:47:18.305Z        INFO        [monitoring]        log/log.go:145        Non-zero metrics in the last 30s        {"monitoring": {"metrics"
```


## Validate data in Kibana

- create an index, used the suggested Filebeat index
- validate time format
- data should be imported

Kibana | Discover | Search
