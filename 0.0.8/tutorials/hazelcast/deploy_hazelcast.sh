#!/usr/bin/env bash

export NAMESPACE=demo

kubectl label namespace $NAMESPACE memverge=enabled

echo -n "Hazelcast License Key: "
read -s hz_license
kubectl -n $NAMESPACE create secret generic hz-license-key-secret --from-literal=key=${hz_license}

envsubst '$NAMESPACE' < statefulset.yml | kubectl apply -f -

envsubst '$NAMESPACE' < mancenter.yml | kubectl apply -f -

# On OpenShift, it seems we need to use oc to expose the service correctly to external clients.
oc -n $NAMESPACE expose svc/management-center-service

kubectl -n $NAMESPACE apply -f client.yml
