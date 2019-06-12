#!/bin/sh
# firewalld service definition for Consul connectivity
# cd /tmp
# nano firewallsetup.sh
# chmod +x firewallsetup.sh
# ./firewallsetup.sh


cat << EOF > /etc/firewalld/services/consul.xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>Consul</short>
  <description>TCP connectivity required for HashiCorp Consul cluster communication.</description>
  <port protocol="tcp" port="8300"/>
  <port protocol="tcp" port="8301"/>
  <port protocol="udp" port="8301"/>  
  <port protocol="tcp" port="8302"/>
  <port protocol="udp" port="8302"/>  
  <port protocol="tcp" port="8500"/>
  <port protocol="tcp" port="8600"/>
  <port protocol="udp" port="8600"/>
</service>
EOF

cat << EOF > /etc/firewalld/services/vault.xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>Vault</short>
  <description>TCP connectivity required for HashiCorp Vault cluster communication.</description>
  <port protocol="tcp" port="8200"/>
  <port protocol="tcp" port="8201"/>
</service>
EOF

cat << EOF > /etc/firewalld/services/telegraf.xml
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>telegraf</short>
  <description>TCP connectivity required for outbound Telegraf agent.</description>
  <port protocol="tcp" port="8086"/>
</service>
EOF

# add custom services to default zone
# assumes public zone

firewall-cmd --zone=public --add-service=consul --permanent
firewall-cmd --zone=public --add-service=vault --permanent
firewall-cmd --zone=public --add-service=https --permanent
firewall-cmd --zone=public --add-service=http --permanent
firewall-cmd --zone=public --add-service=telegraf --permanent
firewall-cmd --complete-reload

# troubleshooting commands
# https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-using-firewalld-on-centos-7
# 
# firewall-cmd --state # verify service is running and reachable
# firewall-cmd --get-default-zone # identify the default zone
# systemctl restart network
# systemctl reload firewalld
# firewall-cmd --zone=public --list-all
# firewall-cmd --zone=public --list-services
# firewall-cmd --get-services
