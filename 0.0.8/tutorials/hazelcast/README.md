# Hazelcast Cluster Example

## Preparation
- Assume you have the following software installed:
    - oc
    - operator-sdk
    - [kubectl-mvmcli](../../scripts/kubectl-mvmcli)

- Follow instructions [here](../../README.md) to
    - config PMEM devices on worker nodes to use **Memory Machine™**
    - label the worker node for **Memory Machine™** license server

## Deploy Memory Machine
```
$ deploy_mm.sh
```

## Deploy Hazelcast Cluster (StatefulSet)
```
$ deploy_hazelcast.sh
```

## Show Memory Machine Usage
```
$ oc mvmcli usage
```

## List Cluster Members Running on Memory Machine
```
$ oc mvmcli list
```

## Add Data into Hazelcast Cluster
```
$ oc -n demo exec --it hz-client -- bash
$ python /home/client.py --help
```

## Snapshot Hazelcast Cluster (StatefulSet)
```
$ oc mvmcli clustersnap create hz-snap-test --namespace demo --statefulset hz --profile hazelcast --profile-options '--nopause'
```

## List Snapshots Have Taken
```
$ oc mvmcli clustersnap list
```

## Restore Hazelcast Cluster (StatefulSet) From a Snapshot
```
$ oc mvmcli clustersnap restore hz-snap-test
```

## Delete Cluster Snapshots
```
$ oc mvmcli clustersnap delete hz-snap-test
```