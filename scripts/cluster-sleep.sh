#!/usr/bin/env bash
# Scale all node pools to 0 when you stop working (saves ~all compute cost).
# The control plane stays (free tier), so manifests, Argo CD state and PVCs survive.
# Still billed while asleep: static IP, Cloud NAT, persistent disks (cents/day).
set -euo pipefail

CLUSTER="${CLUSTER:-platform-dev}"
ZONE="${ZONE:-europe-west3-a}"

echo "Disabling autoscaling on spot pool..."
gcloud container node-pools update spot --cluster "$CLUSTER" --zone "$ZONE" --no-enable-autoscaling --quiet

for pool in spot system; do
  echo "Scaling $pool -> 0"
  gcloud container clusters resize "$CLUSTER" --zone "$ZONE" --node-pool "$pool" --num-nodes 0 --quiet
done

echo "Cluster is asleep. Wake it with ./scripts/cluster-wake.sh"
