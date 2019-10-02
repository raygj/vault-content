# Minikube Ingress Controller

Kubernetes requires an ingress controller to support inbound connectivity to deployed Pods. The [ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/#what-is-ingress) controller is a port-forwarder that accepts connections on one IP address/port and forwards to another IP address/port. In your lab scenario you may have a different set of constraints, but the goal in the following section is to provide a working pattern that can be adopted.

[nodeport-lb-ingress reference](https://medium.com/google-cloud/kubernetes-nodeport-vs-loadbalancer-vs-ingress-when-should-i-use-what-922f010849e0)

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

5. create ingress-nginx.yml resource definition

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

expected result:
```
Hello, world!
Version: 1.0.0
Hostname: web-9bbd7b488-94nwc
```
```

# Extending the Concept

using the ingress-nginx defintion above to expose another service (besides the hello world, web service we created above). kubernetes documentation on [services](https://kubernetes.io/docs/concepts/services-networking/connect-applications-service/#creating-a-service)

exposing the vault-agent-example pod from the [vault agent auto-auth](https://github.com/raygj/vault-content/tree/master/use-cases/vault-agent-kubernetes) walkthrough, assuming that work is functional, this section is about using the Ingress Controller to expose the test app and validate a pattern that can be used for future demos.

[good overview reference](https://medium.com/@Oskarr3/setting-up-ingress-on-minikube-6ae825e98f82)

0. view existing services

`sudo kubectl get svc`

at this point you should have `kubernetes` and `web` services:

```
NAME         TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
kubernetes   ClusterIP   10.96.0.1       <none>        443/TCP          3d17h
web          NodePort    10.111.129.88   <none>        8080:31342/TCP   22h
```

1. add a service defintion to the existing pod configuration by modifying the existing config map

- backup original file (any time you touch YAML) also, [YAML linter](https://codebeautify.org/yaml-validator) to catch those pesky indentation mistakes

`cp ~/vault-guides/identity/vault-agent-k8s-demo/example-k8s-spec.yml example-k8s-spec-v1.yml`

- create a new (immutability) version of the file as v2

`cp ~/vault-guides/identity/vault-agent-k8s-demo/example-k8s-spec.yml example-k8s-spec-v2.yml`

- increment name to `vault-agent-example-v2` on line 5

- remove nginx container lines 83 to 92, copy this config a new text file

`nano ~/vault-guides/identity/vault-agent-k8s-demo/example-k8s-spec-v2.yml`

2. remove existing pod

`kubectl delete pods vault-agent-example --now`

this will take a little while, use `sudo kubectl get pods` to check the status

3. create new pod using new version of config you just created

- create a ConfigMap named, `example-vault-agent-config-v2` pulling files from `configs-k8s` directory.

`cd ~/vault-guides/identity/vault-agent-k8s-demo/`

`sudo kubectl create configmap example-vault-agent-config-v2 --from-file=./configs-k8s/`

- view the created ConfigMap

`sudo kubectl get configmap example-vault-agent-config-v2 -o yaml`

4. create Pod with v2 of the ConfigMap

- Execute the following command to create (and deploy the containers within) the vault-agent-example Pod:

`sudo kubectl apply -f example-k8s-spec-v2.yml --record`

after a minute or so the containers should be active and automatically authenticating against Vault

5. verify Pod status

_you could use the dashboard if you have it configured or want to jump through the hoops_

`sudo kubectl get pods --show-labels`

view deployment status: [deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) are the desired state you have declared such as an image to run, the minimum number of instances, etc)

`sudo kubectl get deployment`

we just created a new configmap that removed the nginx container and started a new pod, with a new version

6. create nginx service

`nano ~/vault-guides/identity/vault-agent-k8s-demo/nginx-srv.yml`

```

apiVersion: v1
kind: Service
metadata:
  name: nginx-svc
spec:
  selector:
    run: example-vault-agent-config-v3
  ports:
     - protocol: "TCP"
       port: 80
       targetPort: 80

  volumeMounts:
    - name: shared-data
      mountPath: /usr/share/nginx/html

```

7. build service

`sudo kubectl apply -f ./nginx-srv.yml`

7. verify the service has been created

`sudo kubectl describe svc nginx-svc`
