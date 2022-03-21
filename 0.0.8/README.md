# Memory Machine Operator

## Prerequisites

The following instructions assume that you have installed the [OpenShift Container Platform](https://access.redhat.com/documentation/en-us/openshift_container_platform/4.10/html-single/installing/index#installation-process_ocp-installation-overview), customized to your requirements.

*Does the user need to have the OpenShift/application cluster created already? If not, when is it created?*

Also, the Kubernetes [Operator SDK](https://sdk.operatorframework.io/docs/installation/) must be installed.

## Configuring the Memory Machine Platform

Before installing Memory Machine™ Operator, do the following:
1. Obtain and install a [Memory Machine License](#obtaining-and-installing-a-memory-machine-license).
2. Configure [PMem](#configuring-pmem).
3. Create a [Secret](#create-an-image-secret) with which to pull the Memory Machine license.

### Obtaining and Installing a Memory Machine License

Obtain a Memory Machine license from MemVerge. To request a license, send an email to: [mvlicense@memverge.com](mailto:mvlicense@memverge.com). Include the MAC address of the node that will contain the Memory Machine pod. This node is the *Memory Machine node*; the license is valid for the entire OpenShift cluster but is installed only on that node.

After you have obtained the license:

1. Label the Memory Machine node as `memory-machine.memverge.com=license-server` by typing the following command:

   ```
   $ kubectl label node <memory-machine-license-node> memory-machine.memverge.com=license-server
   ```
   
   where `<memory-machine-license-node>` is the name or IP address of the Memory Machine node.
    
2. Create a namespace named `memverge` by typing the following:
    
    ```
    $ kubectl create ns memverge
    ```
    
3. Create a Secret named `memory-machine-license` containing the license in the `memverge` namespace as follows:
    
    ```
    $ kubectl create secret generic memory-machine-license \
    -n memverge \
    --from-file=license=<path-to-your-license-file>
   ```
    
    where `<path-to-your-license-file>` is the Memory Machine license file.

### Configuring PMem
    
Before using the Operator, configure the PMem as described in the following steps:

1. Label all worker nodes that you want to use Memory Machine with `storage=pmem`.

   ```
   $ kubectl label node <node-name> storage=pmem
   ```
    
    where `<node-name>` is the worker node's name IP? DNS? Grade-school nickname?

2. On the Memory Machine node, run the [`config-pmem.sh`](scripts/config-pmem.sh) script to reserve PMem capacity (in GiB) for Memory Machine:
    
   ```
   $ config-pmem.sh --mm-capacity <pmem-size>
   ```
    where `pmem-size` is the number of GiB of PMem.
    
If there is no real PMem device, DRAM can be used to emulate PMem. In that case, add the `--pmem-emulation` flag as follows:
    
   ```
   $ config-pmem.sh --pmem-emulation --mm-capacity <pmem-size>
   ```

## Installing the Memory Machine Operator
    
Create an image pull secret named `memverge-github-dockerconfig` and retrieve the Operator image by following these steps:

1. Log into Docker as follows:
    
   ```
   $ cat <file-containing-github-token> | docker login ghcr.io
   ```
   
2. Create the secret as follows:

   ```
   $ kubectl create secret generic memverge-github-dockerconfig \
       -n memverge \
       --from-file=.dockerconfigjson=$HOME/.docker/config.json \
       --type=kubernetes.io/dockerconfigjson
   ```
   
3. Update the pod identity as follows:
    
   ```
   $ kubectl patch serviceaccount default \
       -n memverge \
       -p '{"imagePullSecrets": [{"name": "memverge-github-dockerconfig"}]}'
   ```

4. Install the Memory Machine Operator node by typing the `operator-sdk` command as follows:
    
   ```
   $ operator-sdk run bundle ghcr.io/memverge/memory-machine-operator-bundle:0.0.8 \
       -n memverge \
       --pull-secret-name memverge-github-dockerconfig
   ```

## Memory Machine Container Architecture
    
For information about how the operator deploys Memory Machine and other resources, see [Memory Machine Container Model](architecture.md).

## Deployment Examples
    
The following examples are available:
    
- To deploy Memory Machine using a Memory Machine Operator that runs with a test pod, see [example.md](example.md).
    
- To deploy a Hazelcast cluster (using StatefulSet) on Memory Machine and checkpoint-restore the Hazelcast cluster, see [tutorials/hazelcast/README.md](tutorials/hazelcast/README.md).

## Configuration
For a complete list of configuration options, refer to the [Memory Machine Configuration List](config.md).

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
If you want to clean up the Memory Machine, be sure to remove your application from the cluster first, and then delete the MemoryMachine YAML you created previously
```
$ kubectl delete -f <path-to-memory-machine-yaml-file>
```
The operator will detect the deletion of this MemoryMachine and clean up the resources created automatically.

## Remove the Operator
Remove the Memory Machine Operator and Mutating Webhook by running
```
$ operator-sdk cleanup memory-machine-operator 
```
