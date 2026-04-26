#!/bin/bash
# scale-environment.sh - Scale all services in an environment to specified replica count

set -e

if [ $# -ne 2 ]; then
  echo "Usage: $0 <env> <replicas>"
  echo "Example: $0 staging 0"
  exit 1
fi

ENV=$1
REPLICAS=$2
GITOPS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CLUSTERS_DIR="$GITOPS_DIR/clusters"

if [ ! -d "$CLUSTERS_DIR/$ENV" ]; then
  echo "Error: $CLUSTERS_DIR/$ENV directory not found"
  exit 1
fi

echo "Scaling all services in $ENV to $REPLICAS replicas..."

# Iterate through all services in the environment
for service_dir in "$CLUSTERS_DIR/$ENV"/*/; do
  service=$(basename "$service_dir")
  values_file="$service_dir/values.yaml"

  if [ ! -f "$values_file" ]; then
    echo "Warning: $values_file not found, skipping"
    continue
  fi

  # Update replicaCount in values.yaml
  yq e ".backend.replicaCount = $REPLICAS" -i "$values_file"
  echo "  ✓ $service: replicaCount = $REPLICAS"
done

echo "Done scaling $ENV environment"
