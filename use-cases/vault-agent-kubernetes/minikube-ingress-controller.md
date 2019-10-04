# This Walk through...

... is an add-on to [original walkthrough](https://github.com/raygj/vault-content/blob/master/use-cases/vault-agent-kubernetes/README.md) where I dug in and learned more Kubernetes networking.

the gist of what's changing here:

[Option 1 Section](https://github.com/raygj/vault-content/blob/master/use-cases/vault-agent-kubernetes/minikube-ingress-controller.md#option-1-define-service-to-expose-ui)

- adding labels to pod spec to supporting mapping service

- map service to expose via NodePort

[Option 2 Section](https://github.com/raygj/vault-content/blob/master/use-cases/vault-agent-kubernetes/minikube-ingress-controller.md#option-2-deploy-an-ingress-controller)

- build off of Option 1 Section, but change the service spec to ClusterIP and expose via Ingress Controller

## modify the previous config map

- edit the provided pod spec file `example-k8s-spec.yml` to reflect the location of your Vault server

- backup original file (any time you touch YAML) also, [YAML linter](https://codebeautify.org/yaml-validator) to catch those pesky indentation mistakes

`cp ~/vault-guides/identity/vault-agent-k8s-demo/example-k8s-spec.yml example-k8s-spec.yml.orig`

`nano ~/vault-guides/identity/vault-agent-k8s-demo/example-k8s-spec.yml`

- modify lines 43 and 74 to reflect the ip address of your Vault server, alternatively use DNS **note to self** need to evaluate using Consul DNS here

- manually add "labels" stanza from [here](https://github.com/raygj/vault-content/blob/master/use-cases/vault-agent-kubernetes/example-k8s-spec-jray.yml)

```

  labels:
    app: validate-creds
    role: vault-agent-example
    version: v1
 
```

- note on immatability, the approach for versioning pods is to create a new configuration and increment the version number on the "version" label

- create a ConfigMap named, `example-vault-agent-config` pulling files from `configs-k8s` directory.

`cd ~/vault-guides/identity/vault-agent-k8s-demo/`

`sudo kubectl create configmap example-vault-agent-config --from-file=./configs-k8s/`

- view the created ConfigMap

`sudo kubectl get configmap example-vault-agent-config -o yaml`

## create POD

- Execute the following command to create (and deploy the containers within) the vault-agent-example Pod:

`sudo kubectl apply -f example-k8s-spec.yml --record`

after a minute or so the containers should be active and automatically authenticating against Vault

### verify Pod status

`sudo kubectl get pods --show-labels`

```

NAME                  READY   STATUS    RESTARTS   AGE   LABELS
vault-agent-example   1/1     Running   0          8s    app=validate-creds,role=vault-agent-example,version=v1

```

**note** you will see the various labels defined within the pod spec in Step 2, you will use these to map a services spec in the coming steps

view deployment status: [deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) are the desired state you have declared such as an image to run, the minimum number of instances, etc)

`sudo kubectl get deployment`

**note** i'm not sure why (yet), but the individual containers were never reflected as _deployed_ when issuing this command, however, the containers were up and running. <- need to dig in on K8S to understand this.

- view all pods, all namespaces

`sudo kubectl get pods -o wide --all-namespaces`

## port-forward to connect to nginx instance from the VM

`sudo kubectl port-forward pod/vault-agent-example 8080:80`

at this point, you must leave this terminal open as this is command runs in the foreground and wil supply console log messages as transactions occur.

## open a new SSH session to your minikube VM and connect on 8080

`curl http://127.0.0.1:8080`

this should return a response such as:

```

root@vault-agent-example:/# curl http://localhost
  <html>
  <body>
  <p>Some secrets:</p>
  <ul>
  <li><pre>username: appuser</pre></li>
  <li><pre>password: suP3rsec(et!</pre></li>
  </ul>

  </body>
  </html>
  
```

recall that we are forwarding 8080 of the VM to 80 on the nginx container

if you do not receive this response you need to start troubleshooting port-forwarding as that is the likely culprit; go to the original SSH session where you start port-fowarding in Step 6 and see if there are any errors such as `unable to do port forwarding: socat not found` <- if this error is present you need to install socat, go up to Step 7 in the [Install Minikube](https://github.com/raygj/vault-content/tree/master/use-cases/vault-agent-kubernetes#install-minikube) section

## Option 1: Define Service to Expose UI

in Step 6 we used the `port-forward` command which is good for testing or connecting to a specific service that you might not otherwise expose outside of the cluster, however, it would be helpful to formal expose the UI so it is reachable from a browser

a service is one option for exposing content to the outside world, but is probably on useful if you have a load balancer in front of it and can deal with dyanamic ports. when a service start a random port will be used unless you defined one as `ports.nodePort`

### create service spec file:

`cd ~/vault-guides/identity/vault-agent-k8s-demo/`

`nano vault-agent-example-svc.yml`

```

apiVersion: v1
kind: Service
metadata:
  name: vault-agent-example-svc
  labels:
    app: validate-creds
    role: vault-agent-example
    version: v1
spec:
  selector:
     app: validate-creds
  ports:
  -  port: 8080
     protocol: TCP
     targetPort: 80
     nodePort: 30000
  type: NodePort

```

**notes**

1. metadata.name is arbitrary

2. labels.app|role|version are aribitrary but should match the app this service is supporting (except for version)

3. spec.selector.app is what binds this service to the pod...assumes container within pod is listening on 80

4. spec.ports.nodePort will bind the service to a specific port, must be in range of 30000–32767, in this case 30000

### apply the spec file to create the service:

`sudo kubectl apply -f vault-agent-example-svc.yml`

### validate service was created:

`sudo kubectl get svc`

you should see:

```

NAME                      TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)          AGE
kubernetes                ClusterIP   10.96.0.1        <none>        443/TCP          4d19h
vault-agent-example-svc   NodePort    10.105.114.151   <none>        8080:30193/TCP   81s

```

- use describe service command for details:

`sudo kubectl describe svc vault-agent-example-svc`

- if you need to delete the servcie to modify/recreate it:

`sudo kubectl delete svc vault-agent-example-svc`

### test access from outside-in

using a browser, connect to the UI via `http://< your VM's external IP address >:30000

# Option 2: Deploy an Ingress Controller


```
    internet
        |
   [ Ingress ]
   --|-----|--
   [ Services ]

```

^^ [source](https://kubernetes.io/docs/concepts/services-networking/ingress/#what-is-ingress)

- deploy ingress controller

- modify service spec to support use with ingress controller

**note** ingress relies on DNS, or the request URL to route traffic

## Minikube Ingress Controller

Kubernetes requires an ingress controller to support inbound connectivity to deployed Pods. The [ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/#what-is-ingress) controller is a port-forwarder that accepts connections on one IP address/port and forwards to another IP address/port. In your lab scenario you may have a different set of constraints, but the goal in the following section is to provide a working pattern that can be adopted.

[nodeport-lb-ingress reference](https://medium.com/google-cloud/kubernetes-nodeport-vs-loadbalancer-vs-ingress-when-should-i-use-what-922f010849e0)

### enable NGINX ingress controller:

`sudo minikube addons enable ingress`

### verify it the ingress controller is running (may take a minute or two):

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

### create ingress-nginx.yml resource definition

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
  - host: vaultagent.demo
    http:
      paths:
      - path: /
        backend:
          serviceName: vault-agent-example-svc

```

### modify service spec file:

in the previous section we defined the service using the spec.type NodePort, but when using an ingress controller the service should not be accessible outside of the cluster...so we will change the defintion to clusterIP

`cd ~/vault-guides/identity/vault-agent-k8s-demo/`

`nano vault-agent-example-svc.yml`

```

apiVersion: v1
kind: Service
metadata:
  name: vault-agent-example-svc
  labels:
    app: validate-creds
    role: vault-agent-example
    version: v1
spec:
  selector:
     app: validate-creds
  ports:
  -  port: 8080
     protocol: TCP
     targetPort: 80

```

**notes**

1. spec.type should be set to ClusterIP, it was previously using NodePort in the last iteration

2. spec.ports.nodePort cannot be defined when using ClusterIP, delete this line from the last iteration

#### delete the existing service to modify/recreate it:

`sudo kubectl delete svc vault-agent-example-svc`

### apply the spec file to create the service:

`sudo kubectl apply -f vault-agent-example-svc.yml`

### validate service was created:

`sudo kubectl get svc`

you should see:

```

NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)          AGE
kubernetes                ClusterIP   10.96.0.1       <none>        443/TCP          4d22h
vault-agent-example-svc   ClusterIP   10.104.3.38     <none>        8080/TCP         29m

```

- use describe service command for details:

`sudo kubectl describe svc vault-agent-example-svc`



**notes**

1. metadata.name is arbitrary

2. spec.rules.host is the DNS URL that the ingress controller will terminate, this is the URL we will use to connect via a browser

3. spec.backend.serviceName is arbitrary

4. spec.backend.servicePort is the inbound port for the controller to listen on, in this case 80 

5. spec.backend.serviceName is the service name that the ingress controller will front-end, in this case vault-agent-example-svc service that we created in the last section

6. spec.rules.servicePort is the port on the service that traffic will be directed to, in this case 30000 is the port we assigned in our service spec


### create an ingress resource

`sudo kubectl create -f ingress-nginx.yml`

**note** if you need to modify the ingress controller spec after creating it, use this command - requires VIM skills ;-)

`sudo kubectl edit ingress ingress-nginx`

###. validate ingress resource was created

`sudo kubectl describe ing ingress-nginx`

`sudo kubectl get ingress ingress-nginx`

###. update the hosts file of your local workstation to add DNS hostname for test environment

recall that our ingress-nginx definition has a host rule that will respond to requests from **myminikube.info** that resolve to the NodePort address. the easiest way to do this is to setup a local hosts entry:

`export minikubeip=<your nodeport address>`

`echo "$minikubeip vaultagent.demo" | sudo tee -a /etc/hosts`

ping using name to make sure it resolves:

`ping vaultagent.demo`

9. test from a browser

http://vaultagent.demo

expected result:
```

Some secrets:

username: appuser
password: suP3rsec(et!

```


