#!/usr/bin/env bash

export NAMESPACE=demo

docker_config="$HOME/.docker/config.json"
which docker 2>&1 >/dev/null
docker_installed=$?
if [[ $docker_installed -eq 0 ]]; then
    if ! grep -q "ghcr.io" $docker_config; then
        docker login ghcr.io
    fi
elif [[ -e $docker_config ]]; then
    echo -e "$docker_config exists, but docker is not installed"
    exit 1
else
    mkdir -p $(dirname $docker_config)
    echo "login ghcr.io"
    echo -n "username: "
    read ghcr_username
    echo -n "personal access token (PAT): "
    read -s ghcr_pat
    ghcr_auth=$(echo -n "$ghcr_username:$ghcr_pat" | base64)
    cat >$docker_config <<EOF
{
        "auths": {
                "ghcr.io": {
                        "auth": "$ghcr_auth"
                }
        }
}
EOF
fi

oc create namespace memverge

oc -n memverge create secret generic memverge-github-dockerconfig --from-file=.dockerconfigjson=$docker_config --type=kubernetes.io/dockerconfigjson

oc -n memverge patch serviceaccount default -p '{"imagePullSecrets": [{"name": "memverge-github-dockerconfig"}]}'

oc -n memverge create secret generic memory-machine-license --from-file=license=mm-license.lic

operator-sdk run bundle ghcr.io/memverge/memory-machine-operator-bundle:0.0.8 --pull-secret-name memverge-github-dockerconfig -n memverge
if [[ $docker_installed -ne 0 ]]; then
    rm $docker_config
fi

oc apply -f scc.yml

oc create namespace $NAMESPACE

envsubst '$NAMESPACE' < memorymachine.yml | oc apply -f -
