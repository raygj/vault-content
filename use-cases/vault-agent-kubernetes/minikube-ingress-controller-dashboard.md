# Minikube Ingress Controller

Kubernetes requires an ingress controller to support inbound connectivity to deployed Pods. The [ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/#what-is-ingress) controller is a port-forwarder that accepts connections on one IP address/port and forwards to another IP address/port. In your lab scenario you may have a different set of constraints, but the goal in the following section is to provide a working pattern that can be adopted.

1. enable NGINX ingress controller:

`sudo minikube addons enable ingress`

2. verify it the ingress controller is running (may take a minute or two):

`sudo kubectl get pods -n kube-system`

```

NAME                                        READY   STATUS    RESTARTS   AGE
coredns-5644d7b6d9-5c8zr                    1/1     Running   0          3d14h
coredns-5644d7b6d9-6ct5d                    1/1     Running   0          3d14h
etcd-minikube                               1/1     Running   0          3d14h
kube-addon-manager-minikube                 1/1     Running   0          3d14h
kube-apiserver-minikube                     1/1     Running   0          3d14h
kube-controller-manager-minikube            1/1     Running   1          3d14h
kube-proxy-srjv8                            1/1     Running   0          3d14h
kube-scheduler-minikube                     1/1     Running   0          3d14h
nginx-ingress-controller-57bf9855c8-lhc8m   1/1     Running   0          18h
storage-provisioner                         1/1     Running   0          3d14h

```

3. deploy a hello, world app to test:

create hello, world instance

`sudo kubectl create web --image=gcr.io/google-samples/hello-app:1.0 --port=8080`

expose the deployment

`kubectl expose deployment web --target-port=8080 --type=NodePort`

verify the deployment, this will provide the external URL to test with

`sudo kubectl get service web`

output is http://<your Pod's IP address>:<some port>

```

NAME   TYPE       CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
web    NodePort   10.111.129.88   <none>        8080:31342/TCP   18h

```

4. test connectivity from the VM to the container

`curl http://10.111.129.88:8080`

you should see:

```

Hello, world!
Version: 1.0.0
Hostname: web-9bbd7b488-94nwc

```

now...how to forward traffic from outside the cluster?

5. create ingress-nginx.yml 

`nano ~/vault-guides/identity/vault-agent-k8s-demo/ingress-nginx.yml`

```

apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: ingress-nginx
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  backend:
    serviceName: default-http-backend
    servicePort: 80
  rules:
  - host: myminikube.info
    http:
      paths:
      - path: /
        backend:
          serviceName: web
          servicePort: 8080

```

6. create an ingress resource

`sudo kubectl create -f ingress-nginx.yml`

7. validate ingress resource was created

`sudo kubectl describe ing ingress-nginx`

8. update the hosts file of your local workstation to add DNS hostname for test environment

recall that our ingress-nginx definition has a host rule that will respond to requests from **myminikube.info** that resolve to the NodePort address. the easiest way to do this is to setup a local hosts entry:

`export minikubeip=<your nodeport address>`

`echo "$minikubeip myminikube.info" | sudo tee -a /etc/hosts`

ping using name to make sure it resolves:

`ping myminikube.info`

9. test from a browser

http://myminikube.info

```

Hello, world!
Version: 1.0.0
Hostname: web-9bbd7b488-94nwc

```
# Extending the Concept

exposing the vault-agent-example pod from the [vault agent auto-auth](https://github.com/raygj/vault-content/tree/master/use-cases/vault-agent-kubernetes)walkthrough

