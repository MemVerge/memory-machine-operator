#!/usr/bin/env bash

export NAMESPACE=demo

oc create namespace $NAMESPACE

envsubst '$NAMESPACE' < memorymachine.yml | oc apply -f -
sleep 5 # wait a bit for resources in memverge namespace to show up
oc -n memverge rollout status daemonset memory-machine
oc -n memverge rollout status statefulset memory-machine-etcd
oc -n memverge rollout status statefulset memory-machine-management-center
# wait for m3c to update license
for run in {1..10}; do
    if oc mvmcli usage | grep "Invalid license, PMEM allocator disabled" 1>/dev/null; then
        echo "Waiting for Memory Machine license to update"
        sleep 10
    else
        break
    fi
done

oc label namespace $NAMESPACE memverge=enabled

echo -n "Hazelcast License Key: "
read -s hz_license
echo ""
oc -n $NAMESPACE create secret generic hz-license-key-secret --from-literal=key=${hz_license}

# read Kubernetes api token from namespace's default token or input a token from CLI 
token_name=$(oc -n ${NAMESPACE} get secret | grep -m 1 default-token | awk '{print $1}')
if [[ -z $token_name ]]; then
    echo -n "Kubernetes API token: "
    read -s k8s_token
    echo ""
else
    k8s_token=$(kubectl -n demo get secret $token_name -o jsonpath={.data.token} | base64 -d)
fi
oc -n $NAMESPACE create secret generic hz-k8s-api-token --from-literal=token=${k8s_token}

envsubst '$NAMESPACE' < statefulset.yml | oc apply -f -

envsubst '$NAMESPACE' < mancenter.yml | oc apply -f -

# On OpenShift, it seems we need to use oc to expose the service correctly to external clients.
oc -n $NAMESPACE expose svc/management-center-service

oc -n $NAMESPACE apply -f client.yml
