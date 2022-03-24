# Install Memory Machine Operator With Your Own Private Container Registry

## Mirror Operator Image to Private Registry

```bash
IMG="<your-registry>/<repo>/memory-machine-operator:0.0.10"
docker pull ghcr.io/memverge/memory-machine-operator:0.0.10
docker tag ghcr.io/memverge/memory-machine-operator:0.0.10 $IMG
docker push $IMG
```

## Build and Push Bundle Image to Private Registry

```bash
IMG="<your-registry>/<repo>/memory-machine-operator:0.0.10"
BUNDLE_IMG="<your-registry>/<repo>/memory-machine-operator-bundle:0.0.10"
sed -i "/              - image:/c\              - image: $IMG" bundle/manifests/memory-machine-operator.clusterserviceversion.yaml
docker build -f bundle.Dockerfile -t $BUNDLE_IMG .
docker push $BUNDLE_IMG
```
