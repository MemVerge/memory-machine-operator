# Install Memory Machine Operator With Your Own Private Container Registry

## Mirror Operator Image to Your Private Registry

```bash
OPERATOR_IMG="<your-registry>/<repo>/memory-machine-operator:0.0.10"
docker pull ghcr.io/memverge/memory-machine-operator:0.0.10
docker tag ghcr.io/memverge/memory-machine-operator:0.0.10 $OPERATOR_IMG
docker push $OPERATOR_IMG
```

## Build and Push Bundle Image to Your Private Registry

```bash
OPERATOR_IMG="<your-registry>/<repo>/memory-machine-operator:0.0.10"
BUNDLE_IMG="<your-registry>/<repo>/memory-machine-operator-bundle:0.0.10"
sed -i "/              - image:/c\              - image: $OPERATOR_IMG" bundle/manifests/memory-machine-operator.clusterserviceversion.yaml
docker build -f bundle.Dockerfile -t $BUNDLE_IMG .
docker push $BUNDLE_IMG
```

## Install Operator from Your Private Registry

```
$ operator-sdk run bundle <your-registry>/<repo>/memory-machine-operator-bundle:0.0.10 \
    -n memverge \
    --pull-secret-name memverge-dockerconfig
```
