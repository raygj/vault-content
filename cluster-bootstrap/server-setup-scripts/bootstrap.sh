#!/bin/sh
# create bootstrap.sh in /tmp, paste in contents of this file, chmod +x bootstrap.sh and execute

# collect ip addr of ethernet NIC(s) and all users
ip addr | grep "ens" > logger
cat /etc/passwd > logger

# gather firewalld info
# https://www.digitalocean.com/community/tutorials/how-to-set-up-a-firewall-using-firewalld-on-centos-7
firewall-cmd --get-default-zone > logger
firewall-cmd --get-active-zones > logger

# install apps and reboot
yum install nano unzip open-vm-tools net-tools nmap epel-release jq -y
reboot