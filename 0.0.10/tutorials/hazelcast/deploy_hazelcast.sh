#!/usr/bin/env bash

export NAMESPACE=demo

kubectl create namespace $NAMESPACE

envsubst '$NAMESPACE' < memorymachine.yml | kubectl apply -f -
sleep 5 # wait a bit for resources in memverge namespace to show up
kubectl -n memverge rollout status daemonset memory-machine
kubectl -n memverge rollout status statefulset memory-machine-etcd
kubectl -n memverge rollout status statefulset memory-machine-management-center
# wait for m3c to update license
for run in {1..10}; do
    if kubectl mvmcli usage | grep "Invalid license, PMEM allocator disabled" 1>/dev/null; then
        echo "Waiting for Memory Machine license to update"
        sleep 10
    else
        break
    fi
done

kubectl label namespace $NAMESPACE memverge=enabled

echo -n "Hazelcast License Key: "
read -s hz_license
kubectl -n $NAMESPACE create secret generic hz-license-key-secret --from-literal=key=${hz_license}

envsubst '$NAMESPACE' < statefulset.yml | kubectl apply -f -

envsubst '$NAMESPACE' < mancenter.yml | kubectl apply -f -

# On OpenShift, it seems we need to use oc to expose the service correctly to external clients.
oc -n $NAMESPACE expose svc/management-center-service

kubectl -n $NAMESPACE apply -f client.yml
