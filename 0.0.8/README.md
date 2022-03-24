# Memory Machine Operator

## Memory Machine Architecture
    
Before continuing, we recommend that you read [Memory Machine Container Architecture](architecture.md) to understand how Memory Machine™ Container is organized.

## Prerequisites

The following instructions assume that you have installed the [OpenShift Container Platform](https://access.redhat.com/documentation/en-us/openshift_container_platform/4.10/html-single/installing/index#installation-process_ocp-installation-overview), customized to your requirements. 

You must have a Kubernetes cluster deployed, and the `kubectl` command-line tool must be configured to communicate with your cluster.

The [Operator SDK](https://sdk.operatorframework.io/docs/installation/) is a framework used to develop and run Operators. You will use the `operator-sdk` command to run the Memory Machine Operator, so you must have the Operator SDK installed.

## Configuring the Memory Machine Platform

Before installing Memory Machine Operator, complete the steps described below.

1. Obtain and install a [Memory Machine License](#obtaining-and-installing-a-memory-machine-license).
2. Configure [PMem](#configuring-pmem).

### Obtaining and Installing a Memory Machine License

Obtain a Memory Machine license from MemVerge. To request a license, send an email to [mvlicense@memverge.com](mailto:mvlicense@memverge.com). Include the MAC address of the node that will contain the cluster Memory Machine Management Center pod. The license is valid for the entire cluster but is installed only on the node containing the Memory Machine Management Center pod.

Unless otherwise noted, type all commands on a client node that communicates with your cluster.

After you obtain the license:

1. Label the Memory Machine Management Center node as `memory-machine.memverge.com=license-server` by typing the following command:

   ```
   $ kubectl label node <memory-machine-license-node> memory-machine.memverge.com=license-server
   ```
   
   where `<memory-machine-license-node>` is the name of the Memory Machine node.
    
2. Create a namespace called `memverge` by typing the following:
    
    ```
    $ kubectl create ns memverge
    ```
    
3. Create a Secret for the Memory Machine license with the name `memory-machine-license` in the `memverge` namespace as follows:
    
    ```
    $ kubectl create secret generic memory-machine-license \
    -n memverge \
    --from-file=<license=<path-to-your-license-file>
   ```
    
    where `<path-to-your-license-file>` is the Memory Machine license file.

### Configuring PMem
    
Configure the PMem as described in the following steps:

1. For each worker node that you want to use with Memory Machine, label the worker node with `storage=pmem` as follows:

   ```
   $ kubectl label node <node-name> storage=pmem
   ```
    
    where `<node-name>` is the name of the worker node.

2. Run the [`config-pmem.sh`](scripts/config-pmem.sh) script to reserve PMem capacity (in GiB) for Memory Machine:
    
   ```
   $ config-pmem.sh --mm-capacity <pmem-size>
   ```
   where `pmem-size` is the number of GiB of PMem. The value of `pmem-size` cannot exceed the PMem capacity available on the node.
    
   If there is no physical PMem device, DRAM can be used to emulate PMem. In that case, add the `--pmem-emulation` flag as follows:
   
   ```
   $ config-pmem.sh --pmem-emulation --mm-capacity <pmem-size>
   ```

## Installing the Memory Machine Operator
    
Create an image-pull secret named `memverge-github-dockerconfig` and retrieve the Operator image by following these steps:

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
   
3. Patch the Service Account `default` as follows:
    
   ```
   $ kubectl patch serviceaccount default \
       -n memverge \
       -p '{"imagePullSecrets": [{"name": "memverge-github-dockerconfig"}]}'
   ```

4. Install the Memory Machine Operator by typing the `operator-sdk` command as follows:
    
   ```
   $ operator-sdk run bundle ghcr.io/memverge/memory-machine-operator-bundle:0.0.8 \
       -n memverge \
       --pull-secret-name memverge-github-dockerconfig
   ```

## Deployment Examples
    
The following examples are available:
    
- To deploy Memory Machine using a Memory Machine Operator that runs with a test pod, see [example.md](example.md).
    
- To deploy a Hazelcast cluster on Memory Machine and checkpoint-restore the Hazelcast cluster, see [tutorials/hazelcast/README.md](tutorials/hazelcast/README.md).

## Maintaining the Memory Machine Cluster

### Configuration Options
For a complete list of configuration options, refer to the [Memory Machine Configuration List](config.md).

#### Changing Configurations on Existing Memory Machine Pods
To change the configuration of running Memory Machine pods, redeploy the Memory Machine pods with the new configuration as follows:

1. Stop all applications running on your cluster.

2. Delete the Memory Machine DaemonSet as follows:
   
   ```
   $ kubectl delete daemonset memory-machine -n memverge
   ```
   
3. Edit the `memorymachine.yml` file to change the Memory Machine configuration.

4. Apply the new Memory Machine YAML file to the application space as follows:

   ```
   $ kubectl apply -f <path_to_memory_machine_yaml_file>
   ```
   
   where `<path_to_memory_machine_yaml_file>` is the new Memory Machine YAML file.
   
   The Operator deploys Memory Machine with the new configuration.

### Removing Memory Machine Resources

To remove resources created by Memory Machine Operator, do the following:

1. Remove your applications from the cluster.

2. Delete the Memory Machine YAML file as follows:

   ```
   $ kubectl delete -f <path-to-memory-machine-yaml-file>
   ```
   
   where `<path-to-memory-machine-yaml-file>` is the Memory Machine YAML file.
   
The operator detects the deletion of Memory Machine and removes the resources automatically.

### Removing the Operator

Remove the Memory Machine Operator and Mutating Webhook by using the following command:

```
$ operator-sdk cleanup memory-machine-operator 
```
