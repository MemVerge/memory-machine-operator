#!/usr/bin/env bash
#
# Copyright (C) 2022 MemVerge Inc.
#
# Script to mirror images required by Memory Machine to your own private container registry.
#
set -euo pipefail

PRIVATE_IMG_REPO=""

DOCKER_CONFIG="$HOME/.docker/config.json"

function usage() {
    cat <<EOF
Script to mirror images required by Memory Machine to your own private container registry.

usage: ${0} --image-repo <your-private-registry-repo>
EOF
    exit 1
}

function main() {
    while [[ $# -gt 0 ]]; do
        case ${1} in
            --image-repo)
                PRIVATE_IMG_REPO="$2"
                shift
                ;;
            *)
                usage
                ;;
            esac
            shift
    done

    if [[ -z $PRIVATE_IMG_REPO ]]; then
        echo "--image-repo is required!"
        exit 1
    fi

    login_registry "ghcr.io"

    private_registry=$(echo $PRIVATE_IMG_REPO | awk -F"/" '{print $1}')
    login_registry $private_registry

    mirror_operator_and_build_bundle "ghcr.io/memverge/memory-machine-operator:0.0.10"

    mirror_image "ghcr.io/memverge/memory-machine:2.4.0"
    mirror_image "ghcr.io/memverge/mmagent:2.4.0"
    mirror_image "ghcr.io/memverge/mmctl:2.4.0"
    mirror_image "k8s.gcr.io/etcd:3.4.13-0"
    mirror_image "docker.io/intel/pmem-csi-driver:v1.0.2"
    mirror_image "k8s.gcr.io/pause"
    mirror_image "quay.io/operator-framework/opm"

}

function login_registry() {
    image_registry=$1
    echo "login $image_registry"
    set +e
    docker_version=$(docker -v 2>/dev/null)
    set -e
    if [[ $docker_version == *"Docker"* ]]; then
        docker login $image_registry
    elif [[ $docker_version == *"podman"* ]]; then
        docker login $image_registry --authfile $DOCKER_CONFIG
    else
        mkdir -p $(dirname $DOCKER_CONFIG)
        echo -n "username: "
        read registry_username
        echo -n "password or token: "
        read -s registry_password
        echo ""
        registry_auth=$(echo -n "$registry_username:$registry_password" | base64)
        if [[ ! -f $DOCKER_CONFIG ]]; then
        cat >$DOCKER_CONFIG <<EOF
{
        "auths": {
        }
}
EOF
        fi
        jq "if .\"auths\".\"$image_registry\"? then .\"auths\".\"$image_registry\".\"auth\"=\"$registry_auth\" else .\"auths\" += { \"$image_registry\": { \"auth\": \"$registry_auth\" } } end" \
            "$DOCKER_CONFIG" > "$DOCKER_CONFIG.tmp" && mv "$DOCKER_CONFIG.tmp" "$DOCKER_CONFIG"
    fi
}

function mirror_image() {
    original_image_path=$1
    image_name=$(echo $original_image_path | awk -F"/" '{print $NF}')
    new_image_path="$PRIVATE_IMG_REPO/$image_name"

    docker pull $original_image_path
    docker tag $original_image_path $new_image_path
    docker push $new_image_path
}

function mirror_operator_and_build_bundle() {
    mirror_image $1

    operator_version=$(echo $original_image_path | awk -F":" '{print $NF}')
    operator_img="$PRIVATE_IMG_REPO/memory-machine-operator:$operator_version"
    bundle_img="$PRIVATE_IMG_REPO/memory-machine-operator-bundle:$operator_version"
    sed -i "/              - image:/c\              - image: $operator_img" bundle/manifests/memory-machine-operator.clusterserviceversion.yaml
    docker build -f bundle.Dockerfile -t $bundle_img .
    docker push $bundle_img
}

(cd $(dirname "$0")/../bundle_build && main $@)
