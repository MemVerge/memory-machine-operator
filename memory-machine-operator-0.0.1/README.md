# Memory Machine Operator v0.0.1

## Prerequisites - please read before installing the operator

### License Requirement
You need to obtain a license and provide it to **Memory Machine™** by creating a secret named `memory-machine-license` containing the license under `memverge` namespace.
```
$ kubectl create ns memverge
$ kubectl create secret generic memory-machine-license \
    -n memverge \
    --from-file=license=<path-to-your-license-file>
```

### Image Pull Secrets
Since the **Memory Machine™** image is currently private, you need to create a image pull secret named `memverge-github-dockerconfig` **for memverge and each application namespace** containing github token with read access to the images.
```
$ cat <file-contains-github-token> | docker login ghcr.io
$ kubectl create secret generic memverge-github-dockerconfig \
    -n memverge \
    --from-file=.dockerconfigjson=$HOME/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson
```

## Operator Installation
Memory Machine Operator v0.0.1 is available for installation on [OperatorHub](https://operatorhub.io/).

## Memory Machine Container Architecture
To see how the operator will deploy the **Memory Machine™** and other resources in Kubernetes Cluster, please refer to the [Memory Machine Container Model](architecture.md).

## Tutorial & Deployment Example
A example of using **Memory Machine Operator** to deploy the **Memory Machine™** that runs with a test pod can be found [here](example.md)

## Configuration
For a complete list of configuration options, please refer to the [Memory Machine Configuration List](config.md).

### Change Configurations to an existing MemoryMachine
If the Memory Machine (aka DPME pod) is already running in `memverge` namespace, and you would like to change Memory Machine configuration, do the following steps to redeploy the MemoryMachine with the new configuration.

**Note:** Since the follows steps will remove and recreate the DPME pod, be sure that **no** application is running with current DPME pod, otherwise these application will crash.
1. Delete MemoryMachine DaemonSet
```
$ kubectl delete daemonset memory-machine -n memverge
```
2. Apply your new MemoryMachine YAML file to your application space
```
$ kubectl apply -f <path_to_memory_machine_yaml_file>
```
The Operator will deploy the Memory Machine with the new configurations.

## Clean Up Resources created by Memory Machine Operator
If you want to clean up the MemoryMachine, be sure to remove your application from the cluster first, and then delete the MemoryMachine YAML you created previously
```
$ kubectl delete -f <path-to-memory-machine-yaml-file>
```
The operator will detect the deletion of this MemoryMachine and clean up the resources created automatically.

## Remove the Operator
Remove the Memory Machine Operator and Mutating Webhook by running
```
$ operator-sdk cleanup memory-machine-operator 
```