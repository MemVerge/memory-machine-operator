#!/usr/bin/env bash

export NAMESPACE=demo

oc label namespace $NAMESPACE memverge=enabled

echo -n "Hazelcast License Key: "
read -s hz_license
oc -n $NAMESPACE create secret generic hz-license-key-secret --from-literal=key=${hz_license}

envsubst '$NAMESPACE' < statefulset.yml | oc apply -f -

envsubst '$NAMESPACE' < mancenter.yml | oc apply -f -

oc -n $NAMESPACE expose svc/management-center-service

oc -n $NAMESPACE apply -f client.yml
