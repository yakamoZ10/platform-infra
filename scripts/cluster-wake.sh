#!/usr/bin/env bash
# Bring the node pools back. Values must match terraform.tfvars
# (system_node_count, spot_min_nodes, spot_max_nodes) so Terraform shows no drift.
set -euo pipefail

CLUSTER="${CLUSTER:-platform-dev}"
ZONE="${ZONE:-europe-west3-a}"
SYSTEM_NODES="${SYSTEM_NODES:-1}"
SPOT_MIN="${SPOT_MIN:-1}"
SPOT_MAX="${SPOT_MAX:-3}"

gcloud container clusters resize "$CLUSTER" --zone "$ZONE" --node-pool system --num-nodes "$SYSTEM_NODES" --quiet
gcloud container clusters resize "$CLUSTER" --zone "$ZONE" --node-pool spot --num-nodes "$SPOT_MIN" --quiet
gcloud container node-pools update spot --cluster "$CLUSTER" --zone "$ZONE" \
  --enable-autoscaling --min-nodes "$SPOT_MIN" --max-nodes "$SPOT_MAX" --location-policy ANY --quiet

# Your home IP may have changed overnight (dynamic IP) - check access:
if ! kubectl get nodes >/dev/null 2>&1; then
  echo
  echo "kubectl can't reach the API. If your public IP changed, update"
  echo "terraform/envs/dev/local.auto.tfvars and run: make apply"
  echo "Current IP: $(curl -s https://ifconfig.me)"
else
  kubectl get nodes
fi
