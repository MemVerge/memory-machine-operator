#!/bin/bash
#
# Copyright (C) 2022 MemVerge Inc.
#
# Script to config PMEM devices on OpenShift/k8s nodes.
#
set -euo pipefail

MM_CAP=16
PMEM_EMULATION=0
USE_HUGEPAGE=0
MM_DATA_DIR="/var/memverge"
IMAGE_REPO=""
PULL_SECRET=""

PMEM_CSI_IMAGE="intel/pmem-csi-driver:v1.0.2"
PAUSE_IMAGE="k8s.gcr.io/pause"
NAMESPACE="memverge"

PMEM_CONFIG_SCRIPT=""

function usage() {
    cat <<EOF
Script to config PMEM devices on OpenShift/Kubernetes worker nodes.

usage: ${0} [OPTIONS]

The following flags are optional.

       --mm-capacity  <num>   Total PMEM capacity of Memory Machine. Unit in Giga Byte. Default to 16.
       --pmem-emulation       Use DRAM to emulate PMEM device. Default value false.
       --use-hugepage         Use hugepage DRAM instead of shared memory. Ignored if "pmem-emulation" is false. Default to false.
       --mm-data-dir  <str>   Path of local directory to store Memory Machine data. Default to "/var/memverge".
       --image-repo   <str>   Address of container registry repo to pull images.
       --pull-secret  <str>   Secret to pull container images from the specified repo.
EOF
    exit 1
}

function main() {
  while [[ $# -gt 0 ]]; do
    case ${1} in
      --mm-capacity)
        MM_CAP="$2"
        shift
        ;;
      --pmem-emulation)
        PMEM_EMULATION=1
        ;;
      --use-hugepage)
        USE_HUGEPAGE=1
        ;;
      --mm-data-dir)
        MM_DATA_DIR="$2"
        shift
        ;;
      --image-repo)
        IMAGE_REPO="$2"
        shift
        ;;
      --pull-secret)
        PULL_SECRET="$2"
        shift
        ;;
      *)
        usage
        ;;
      esac
      shift
  done

    PMEM_CONFIG_SCRIPT="#!/bin/bash
# The host's root directory / is mounted as /host in container
mkdir -p /host${MM_DATA_DIR}
"

  if [[ ${PMEM_EMULATION} == 1 ]]; then
    if [[ ${USE_HUGEPAGE} == 1 ]]; then
      SRC_PATH="/dev/hugepages"
    else
      SRC_PATH="/dev/shm"
    fi
    if ! confirm "This operation will erase all data in ${SRC_PATH} directories, please confirm"; then
      exit 0
    fi

    PMEM_CONFIG_SCRIPT="${PMEM_CONFIG_SCRIPT}
# fallocate pmem emulation file
rm -rf ${SRC_PATH}/mm
fallocate -l ${MM_CAP}G ${SRC_PATH}/mm
"
  else
    if ! confirm "This operation will erase all data on ALL PMEM devices, please confirm"; then
      exit 0    
    fi

    PMEM_CONFIG_SCRIPT="${PMEM_CONFIG_SCRIPT}
# umount existing pmems
pmems=(\$(ndctl list | grep pmem | awk -F : '{print \$2}' | sed 's/\"//g; s/,//g'))
if [[ \${#pmems[@]} == 0 ]]; then
  echo \"No PMEMs on this host\"
  exit 1
fi
for pmem in \${pmems[*]}; do
  umount -f /mnt/\${pmem} || true
  rm -rf /mnt/\${pmem}
done

# reconfigure ALL PMEM namespaces to fsdax
namespaces=(\$(ndctl list | grep namespace | awk -F : '{print \$2}' | sed 's/\"//g; s/,//g'))
for ns in \${namespaces[*]}; do
  ndctl create-namespace -f -e \${ns} --mode fsdax
  echo \"Successfully reconfigured \${ns} to fsdax mode\"
done

# mount pmems and allocate mm files
MM_CAP_PER_PMEM=\$((${MM_CAP}/\${#pmems[@]}))
for pmem in \${pmems[*]}; do
  mkdir /mnt/\${pmem}
  mkfs.xfs -f -i size=2048 -d su=2m,sw=1 -m reflink=0 /dev/\${pmem}
  mount -t xfs -o noatime,nodiratime,nodiscard,dax /dev/\${pmem} /mnt/\${pmem}
  rm -rf /mnt/\${pmem}/*
  mount | grep \${pmem}
  xfs_io -c 'extsize 2m' /mnt/\${pmem}
  fallocate -l \${MM_CAP_PER_PMEM}G /mnt/\${pmem}/mm
  echo \"Successfully mounted \${pmem} and allocated /mnt/\${pmem}/mm\" 
done
"
  fi

  if [ ! -z "$IMAGE_REPO" ]; then
    PMEM_CSI_IMAGE="$IMAGE_REPO/pmem-csi-driver:v1.0.2"
    PAUSE_IMAGE="$IMAGE_REPO/pause"
  fi

  config_pmem
}

function confirm() {
  local response
  # call with a prompt string or use a default
  read -r -p "$1 [y/N]: " response
  case "$response" in
      [yY][eE][sS]|[yY]) 
          true
          ;;
      *)
          false
          ;;
  esac
}

function config_pmem() {
  PMEM_CONFIG_YAML="
# Use a ServiceAccount to bind privileged SCC, to allow privileged container.
apiVersion: v1
kind: ServiceAccount
metadata:
  name: memverge-pmem-config
  namespace: ${NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: memverge-pmem-config-role-binding
  namespace: ${NAMESPACE}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:openshift:scc:privileged
subjects:
- kind: ServiceAccount
  name: memverge-pmem-config
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: memverge-pmem-config
  namespace: ${NAMESPACE}
data:
  pmem-config.sh: |-
    {{PMEM_CONFIG_SCRIPT}}
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: memverge-pmem-config
  namespace: ${NAMESPACE}
  labels:
    app: pmem-config-daemon
spec:
  selector:
    matchLabels:
      app: pmem-config-daemon
  template:
    metadata:
      labels:
        app: pmem-config-daemon
    spec:
      nodeSelector:
        storage: pmem
      serviceAccountName: memverge-pmem-config
      imagePullSecrets:
      - name: ${PULL_SECRET}
      hostPID: true
      initContainers:
      - name: pmem-config
        # Use intel's pmem-csi-driver image for convenience, because it has ndctl installed.
        image: ${PMEM_CSI_IMAGE}
        command: [/home/pmem-config.sh]
        securityContext:
          privileged: true
          runAsUser: 0
        volumeMounts:
        - name: dev
          mountPath: /dev
        - name: sys
          mountPath: /sys
        - name: mnt
          mountPath: /mnt
          # Need bidirectional propagation, so that the mount happened inside the container actually
          # happens on th host as well.
          mountPropagation: Bidirectional
        - name: host
          mountPath: /host
        - name: pmem-config
          mountPath: /home/pmem-config.sh
          subPath: pmem-config.sh
      containers:
      - name: pause
        image: ${PAUSE_IMAGE}
      volumes:
      - name: dev
        hostPath:
          path: /dev
          type: Directory
      - name: sys
        hostPath:
          path: /sys
          type: Directory
      - name: mnt
        hostPath:
          path: /mnt
          type: Directory
      - name: host
        hostPath:
          path: /
          type: Directory
      - name: pmem-config
        configMap:
          name: memverge-pmem-config
          # Make pmem-config.sh script executable
          defaultMode: 0500
"

  # Add the content of the pmem config script to the yaml file's ConfigMap
  readarray -t <<<"${PMEM_CONFIG_SCRIPT}"
  PMEM_CONFIG_SCRIPT="    ${MAPFILE[0]}"
  for (( i=1; i<${#MAPFILE[@]}; i++ )); do
    PMEM_CONFIG_SCRIPT="${PMEM_CONFIG_SCRIPT}
    ${MAPFILE[$i]}"
  done
  PMEM_CONFIG_YAML=$(echo "${PMEM_CONFIG_YAML}" | awk -v r="${PMEM_CONFIG_SCRIPT}" '{gsub(/    {{PMEM_CONFIG_SCRIPT}}/,r)}1')

  # Delete existing resources (maybe leftover from a previous failed run)
  set +e
  echo "${PMEM_CONFIG_YAML}" | kubectl delete -f - 2>/dev/null
  PODS=$(kubectl -n ${NAMESPACE} get pods 2>/dev/null | grep memverge-pmem-config | awk '{print $1}')
  for POD in ${PODS}; do
    kubectl -n ${NAMESPACE} delete pod ${POD} --now=true --wait=true --timeout=30s 2>/dev/null
  done
  set -e

  # Apply the DaemonSet and wait for pods to be running
  echo "${PMEM_CONFIG_YAML}" | kubectl apply -f -
  wait_for_pods memverge-pmem-config 60 # 60 seconds timeout
  echo "${PMEM_CONFIG_YAML}" | kubectl delete -f -
}

function wait_for_pods() {
  echo -n "waiting for $1 pods to run"

  local daemonset_name="$1"
  local timeout="$2"
  local now="$(date +%s)"
  local deadline=$(($now+$timeout))

  sleep 5 # wait a bit for pods showing up
  PODS=$(kubectl -n ${NAMESPACE} get pods | grep ${daemonset_name} | awk '{print $1}')

  # Because the PMEM config actually happens in the init container of each pod, once the pod becomes
  # running, it means that the init container has finished without error, and the PMEMs have been
  # configured successfully on this node.
  for POD in ${PODS}; do
    while [[ $(kubectl -n ${NAMESPACE} get pod ${POD} -o go-template --template "{{.status.phase}}") != "Running" ]]; do
      if [ "$(date +%s)" -gt "${deadline}" ]; then
        echo
        echo "Timeout waiting for ${daemonset_name} daemonset to start."
        echo "Please check daemonset using 'kubectl logs ${POD} -c pmem-config' for more information"
        return 1
      fi
      sleep 1
      echo -n "."
    done
  done

  # At this point all pods are running. It is safe to say that all PMEMs have been configured
  # successfully.
  echo
  echo "Successfully configured all PMEMs"
  return 0
}

main $@
