https://www.udemy.com/course/kubernetes-certified-administrator/learn/lecture/10025316#overview

section 8, intro to services

pod is definied with labels such as `app, role, version` to view pods with labels:

`sudo kubectl get pods --show-labels`

these labels are used to define relationships for services

* the vault-agent-example-v3 pod does not have labels defined, so there is nothing to attach to

* plan, go back to the original pod configuration, but add labels...then create a NodePort service to expose it outside

`sudo kubectl delete pods <pod>`


# edits to original walkthrough adding labels to pod spec and then service spec to expose UI outside of cluster


3. create a config map

In Kubernetes, ConfigMaps allow you to decouple configuration artifacts from image content to keep containerized applications portable. 

- edit the provided pod spec file `example-k8s-spec.yml` to reflect the location of your Vault server

- backup original file (any time you touch YAML) also, [YAML linter](https://codebeautify.org/yaml-validator) to catch those pesky indentation mistakes

`cp ~/vault-guides/identity/vault-agent-k8s-demo/example-k8s-spec.yml example-k8s-spec.yml.orig`

- modify lines 43 and 74 to reflect the ip address of your Vault server, alternatively use DNS **note to self** need to evaluate using Consul DNS here

- manually add "labels" stanza from [here](https://github.com/raygj/vault-content/blob/master/use-cases/vault-agent-kubernetes/example-k8s-spec-jray.yml)

- note on immatability, the approach for versioning pods is to create a new configuration and increment the version number on the "version" label

`nano ~/vault-guides/identity/vault-agent-k8s-demo/example-k8s-spec.yml`

- create a ConfigMap named, `example-vault-agent-config` pulling files from `configs-k8s` directory.

`cd ~/vault-guides/identity/vault-agent-k8s-demo/`

`sudo kubectl create configmap example-vault-agent-config --from-file=./configs-k8s/`

- view the created ConfigMap

`sudo kubectl get configmap example-vault-agent-config -o yaml`

4. create POD

- Execute the following command to create (and deploy the containers within) the vault-agent-example Pod:

`sudo kubectl apply -f example-k8s-spec.yml --record`

after a minute or so the containers should be active and automatically authenticating against Vault

5. verify Pod status

_you could use the dashboard if you have it configured or want to jump through the hoops_

`sudo kubectl get pods --show-labels`

view deployment status: [deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/) are the desired state you have declared such as an image to run, the minimum number of instances, etc)

`sudo kubectl get deployment`

**note** i'm not sure why (yet), but the individual containers were never reflected as _deployed_ when issuing this command, however, the containers were up and running. <- need to dig in on K8S to understand this.
