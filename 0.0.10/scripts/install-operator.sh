#!/usr/bin/env bash
#
# Copyright (C) 2022 MemVerge Inc.
#
# Script to deploy Memory Machine Operator.
#
set -euo pipefail

BUNDLE_IMAGE=""
INDEX_IMAGE=""
MM_LICENSE=""

NAMESPACE="memverge"
DOCKER_CONFIG="$HOME/.docker/config.json"

function usage() {
    cat <<EOF
Script to install Memory Machine Operator.

usage: ${0} [OPTIONS]

       --bundle-image <str>   Memory Machine Operator bundle image.
       --index-image  <str>   Index image in which to inject bundle (optional).
       --mm-license   <str>   Path of Memory Machine license file.
EOF
    exit 1
}

function main() {
    while [[ $# -gt 0 ]]; do
        case ${1} in
            --bundle-image)
                BUNDLE_IMAGE="$2"
                shift
                ;;
            --index-image)
                INDEX_IMAGE="$2"
                shift
                ;;
            --mm-license)
                MM_LICENSE="$2"
                shift
                ;;
            *)
                usage
                ;;
            esac
            shift
    done

    if [[ -z $BUNDLE_IMAGE ]]; then
        echo "--bundle-image is required!"
        usage
        exit 1
    fi

    if [[ -z $MM_LICENSE ]]; then
        echo "--mm-license is required!"
        usage
        exit 1
    fi

    if [[ ! -f $MM_LICENSE ]]; then
        echo "Memory Machine license file $MM_LICENSE doesn't exist!"
        exit 1
    fi

    image_registry=$(echo $BUNDLE_IMAGE | awk -F"/" '{print $1}')
    login_registry $image_registry

    install_operator

}

function login_registry() {
    image_registry=$1
    echo "login $image_registry"
    docker_version=$(docker -v 2>/dev/null)
    if [[ $docker_version == *"docker"* ]]; then
        docker login $image_registry
    elif [[ $docker_version == *"podman"* ]]; then
        docker login $image_registry --authfile $DOCKER_CONFIG
    else
        mkdir -p $(dirname $DOCKER_CONFIG)
        echo -n "username: "
        read registry_username
        echo -n "password or token: "
        read -s registry_password
        registry_auth=$(echo -n "$registry_username:$registry_password" | base64)
        cat >$DOCKER_CONFIG <<EOF
{
        "auths": {
                "${image_registry}": {
                        "auth": "$registry_auth"
                }
        }
}
EOF
    fi
}

function install_operator() {

    kubectl create namespace $NAMESPACE

    kubectl -n $NAMESPACE create secret generic memverge-dockerconfig --from-file=.dockerconfigjson=$DOCKER_CONFIG --type=kubernetes.io/dockerconfigjson

    kubectl -n $NAMESPACE patch serviceaccount default -p '{"imagePullSecrets": [{"name": "memverge-dockerconfig"}]}'

    kubectl -n $NAMESPACE create secret generic memory-machine-license --from-file=license=$MM_LICENSE

    if [[ -z $INDEX_IMAGE ]]; then
        operator-sdk run bundle $BUNDLE_IMAGE --pull-secret-name memverge-dockerconfig -n $NAMESPACE
    else
        operator-sdk run bundle $BUNDLE_IMAGE --pull-secret-name memverge-dockerconfig -n $NAMESPACE --index-image $INDEX_IMAGE
    fi

    kubectl apply -f $(dirname "$0")/scc.yml
}

main $@
