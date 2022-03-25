# Tutorial: Deploy Your Application with Memory Machine Operator
This guide assumes that you have installed the Memory Machine Operator.

1. Create a namespace `test` where you would deploy the test application
```
$ kubectl create ns test
```

2. Create an image pulling secret in your application namespace as well.
```
$ kubectl create secret generic memverge-dockerconfig \
    -n test \
    --from-file=.dockerconfigjson=$HOME/.docker/config.json \
    --type=kubernetes.io/dockerconfigjson
```

3. Label the nodes where you want to deploy the DPME pod with label `storage=pmem`
```
$ kubectl label node <node-name> storage=pmem
```
This label indicates that the node has available PMEM

4. Create local shared folder (on every node) for communication between DPME pod and application pods. The default local shared path is `/tmp/memverge`, so we will make that directory. You could create a different directory and set `localSharedPath` field in the MemoryMachine YAML file in step 4. For more info, see [MemoryMachine Configuration List](config.md)
```
$ mkdir /tmp/memverge
```

5. Create MemoryMachine YAML file
```
apiVersion: mm.memverge.com/v1alpha1
kind: MemoryMachine
metadata:
  name: memorymachine-sample
  namespace: test
spec:
  mmVersion: "2.4.0"
  controlVersion: "2.4.0"
```
Explanation of parameters:
- apiVersion: memverge.memverge.com/v1alpha1 : version of resource API is v1alpha1
- kind: MemoryMachine : the resource we create belongs to the type MemoryMachine
- metadata: contains the metadata for the resource
    - name: name of the MemoryMachine, in this case the name is `memorymachine-sample`
    - namespace: namespace in which the MemoryMachine is running, should be the same as the application namespace
- spec: contains the configurations for MemoryMachine running in this namespace, details about available configurations can be found [in this document](config.md).

6. Apply the above MemoryMachine YAML using the following command
```
$ kubectl apply -f <path-to-memory-machine-yaml-file>
```
This command will create the MemoryMachine Custom Resource (CR) in your application namespace.

You can check the MemoryMachine CR by listing the resources in `test` namespace
```
$ kubectl get memorymachines -n test
```
You should see the `memorymachine-sample` in the list of outputs

The creation of MemoryMachine CR will trigger the operator, which will create the DPME pod. Wait for around 20 seconds and check the DPME pod has been created by using the following command
```
$ kubectl get pods -n memverge
```
The name of the DPME pod should be `memory-machine` followed by a random hash, e.g. `memory-machine-56sbt`

Now we have deployed the DPME pod in the cluster. Time to run the example application pod with the DPME pod.

7. Label your application namespace with `memverge=enabled`
```
$ kubectl label namespace test memverge=enabled
```
This step labels your application namespace, so that the webhook will intercept pod creation requests in that namespace.

8. Create the following example application pod YAML file
```
apiVersion: v1
kind: Pod
metadata:
  name: mm-single-model-test-container
  namespace: test
  annotations: 
    memory-machine.memverge.com/inject-env: "yes"
spec:
  containers:
  - name: test-container 
    command: ["/bin/sh", "-c", "sleep infinity"]
    image: centos:8
    imagePullPolicy: IfNotPresent
    volumeMounts:
    - mountPath: /home/test-dir
      name: test-volume
    env:
    - name: PATH
      value: "/bin:/sbin:/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:/etc/memverge:/opt/memverge/sbin"
    - name: TEST_ENV
      value: "injection-test-env-var"
    resources:
      requests:
        memory: 100Mi
      limits:
        memory: 2Gi
  volumes:
  - name: test-volume
    emptyDir: {}
```

9. Apply the YAML file to create the example application pod
```
$ kubectl apply -f <path-to-application-pod-yaml-file>
```
Check that the application pod is created successfully
```
$ kubectl get pods -n test
```
You should see a pod named "mm-single-model-test-container" under `running` state in the list


10. Use the tool kubectl-mvmcli to show PMEM usage of the node running the application
```
$ kubectl-mvmcli show-usage --node <node-name>
```
Delete the application pod, and check the PMEM usage again. 
```
# delete application pod
$ kubectl delete -f <path-to-application-pod-yaml-file>

# make sure the application pod has terminated
$ kubectl get pods -n test

# check PMEM usage
$ kubectl-mvmcli show-usage --node <node-name>
```
The PMEM usage after we delete the pod should be less than the PMEM usage before we delete the pod. This means that the application pod is consuming PMEM.

11. Clean up resources created by the Memory Machine Operator
To remove resources created by Memory Machine Operator, i.e. DPME pod, Persistent Volumes, etc., simply delete the MemoryMachine YAML we created in step 4
```
$ kubectl delete -f <path-to-memory-machine-yaml-file>
```
Memory Machine Operator will automatically remove the resources it created.
