#!/bin/bash
# write-state.sh - Update replica count in state.yaml for a given env/service

set -e

if [ $# -ne 3 ]; then
  echo "Usage: $0 <env> <service> <replicas>"
  echo "Example: $0 dev product 1"
  exit 1
fi

ENV=$1
SERVICE=$2
REPLICAS=$3
GITOPS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="$GITOPS_DIR/state.yaml"

if [ ! -f "$STATE_FILE" ]; then
  echo "Error: $STATE_FILE not found"
  exit 1
fi

# Use yq to update the value
yq e ".$ENV.$SERVICE = $REPLICAS" -i "$STATE_FILE"

echo "Updated $ENV.$SERVICE to $REPLICAS replicas"
