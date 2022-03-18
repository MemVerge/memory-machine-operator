# Memory Machine Operator

## Prerequisites - please read before installing the operator

### Config PMEM
Before using the operator, you need to make sure PMEM devices on the worker nodes are properly configured.

Firstly, label all worker nodes you want to use **Memory Machine™** with `storage=pmem`.
```
$ kubectl label node <node-name> storage=pmem
```
Then, run [`config_pmem.sh`](scripts/config_pmem.sh) script to reserve PMEM capacity (in GiB) for **Memory Machine™**.
```
$ config-pmem.sh --mm-capacity 16
```
If there is no real PMEM device, DRAM can be used to emulate PMEM.
```
$ config-pmem.sh --pmem-emulation --mm-capacity 16
```

### License Requirement
You need to obtain a license and provide it to **Memory Machine™**.

Firstly, label the worker node whose mac address has signed in the license file with label `memory-machine.memverge.com=license-server`.
```
$ kubectl label node <memory-machine-license-node> memory-machine.memverge.com=license-server
```
Then, create a secret named `memory-machine-license` containing the license under `memverge` namespace.
```
$ kubectl create ns memverge
$ kubectl create secret generic memory-machine-license \
    -n memverge \
    --from-file=license=<path-to-your-license-file>
```

### Image Pull Secrets
Since the **Memory Machine™** images are currently private, you need to create an image pull secret named `memverge-github-dockerconfig` for **memverge namespace** containing github token with read access to the images.
```
$ cat <file-contains-github-token> | docker login ghcr.io
$ kubectl create secret generic memverge-github-dockerconfig \
    -n memverge \
    --from-file=.dockerconfigjson=$HOME/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson
$ kubectl patch serviceaccount default \
    -n memverge \
    -p '{"imagePullSecrets": [{"name": "memverge-github-dockerconfig"}]}'
```

## Operator Installation
Memory Machine Operator can be installed using `operator-sdk`.
```
$ operator-sdk run bundle ghcr.io/memverge/memory-machine-operator-bundle:0.0.8 \
    -n memverge \
    --pull-secret-name memverge-github-dockerconfig
```

## Memory Machine Container Architecture
To see how the operator will deploy the **Memory Machine™** and other resources in Kubernetes Cluster, please refer to the [Memory Machine Container Model](architecture.md).

## Tutorial & Deployment Examples
- An example of using **Memory Machine Operator** to deploy the **Memory Machine™** that runs with a test pod can be found [here](example.md)
- An example to deploy a Hazelcast cluster (StatefulSet) on **Memory Machine™** and checkpoint/restore the Hazelcast cluster can be found
[here](tutorials/hazelcast/README.md)

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