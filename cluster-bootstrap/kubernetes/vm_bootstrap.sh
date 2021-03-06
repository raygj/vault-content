#!/bin/bash
# sudo chmod +x bootstrap.sh
# run with sudo

# docker install on Amazon Ubuntu
# https://geekylane.com/install-docker-on-aws-ec2-ubuntu-18-04-script-method/
#curl -fsSL https://get.docker.com -o get-docker.sh
#sudo sh get-docker.sh

# ubuntu docker install
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y unzip nano net-tools jq nmap socat conntrack docker-ce docker-ce-cli containerd.io

# minikube installation
# https://github.com/raygj/vault-content/tree/master/use-cases/vault-agent-kubernetes#install-minikube

cd /usr/local/bin
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64 \
  && chmod +x minikube

egrep -q 'vmx|svm' /proc/cpuinfo && echo yes || echo no

minikube config set vm-driver none

minikube start

# install kubectl

cd /usr/local/bin

curl -LO https://storage.googleapis.com/kubernetes-release/release/` \
curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt`/bin/linux/amd64/kubectl

chmod +x ./kubectl

# install helm

cd /tmp

curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3

chmod 700 get_helm.sh

./get_helm.sh

mv /home/jray/.kube /home/jray/.minikube $HOME
chown -R $USER $HOME/.kube $HOME/.minikube
