#!/bin/sh
# telemetry definition for Consul
# cd /tmp
# nano consul-telem.sh
# chmod +x consul-telem.sh
# ./consul-telem.sh

cat << EOF > /etc/consul.d/consul-telem.json
{
  "telemetry": {
    "dogstatsd_addr": "localhost:8125",
    "disable_hostname": true
 }
}
EOF