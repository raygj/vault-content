# Minikube Ingress Controller

Kubernetes requires an ingress controller to support inbound connectivity to deployed Pods. The ingress controller is a port-forwarder that accepts connections on one IP address/port and forwards to another IP address/port. In your lab scenario you may have a different set of constraints, but the goal in the following section is to provide a working pattern that can be adopted.

1. enable NGINX ingress controller:

`sudo minikube addons enable ingress`

2. verify it the ingress controller is running (may take a minute or two):

`sudo kubectl get pods -n kube-system`

3. deploy a hello, world app to test:

create hello, world instance

`sudo kubectl create web --image=gcr.io/google-samples/hello-app:1.0 --port=8080`

expose the deployment

`kubectl expose deployment web --target-port=8080 --type=NodePort`

verify the deployment, this will provide the external URL to test with

`sudo kubectl get service web`

output is http://<your VM's IP address>:<some port>

test from a browser that has access to your VM, you should see the hello,world app

4. create ingress for Kubernetes Dashboard

create hello, world instance

`sudo kubectl create dash --image=gcr.io/google-samples/hello-app:1.0 --port=8080`

expose the deployment

`kubectl expose deployment web --target-port=8080 --type=NodePort`

verify the deployment, this will provide the external URL to test with

`sudo kubectl get service web`

output is http://<your VM's IP address>:<some port>

test from a browser that has access to your VM, you should see the hello,world app


`sudo kubectl expose deployment dash --target-port=35845 --type=NodePort

ssh method

sudo kubectl proxy &

ssh -R 8888:127.0.0.1:8001 $jray@192.168.1.205 



sudo kubectl proxy --port=30000 &



## create admin user for dashboard

~/vault-guides/identity/vault-agent-k8s-demo

nano dashboard-adminuser.yaml

apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard

sudo kubectl apply -f dashboard-adminuser.yaml




