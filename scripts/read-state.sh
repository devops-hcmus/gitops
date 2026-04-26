#!/bin/bash
# read-state.sh - Read replica count from state.yaml for a given env/service

set -e

if [ $# -ne 2 ]; then
  echo "Usage: $0 <env> <service>"
  echo "Example: $0 dev product"
  exit 1
fi

ENV=$1
SERVICE=$2
GITOPS_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="$GITOPS_DIR/state.yaml"

if [ ! -f "$STATE_FILE" ]; then
  echo "Error: $STATE_FILE not found"
  exit 1
fi

# Use yq to read the value
REPLICAS=$(yq e ".$ENV.$SERVICE" "$STATE_FILE")

if [ "$REPLICAS" = "null" ] || [ -z "$REPLICAS" ]; then
  echo "Warning: $SERVICE not found in $ENV environment, defaulting to 1" >&2
  echo "1"
else
  echo "$REPLICAS"
fi
