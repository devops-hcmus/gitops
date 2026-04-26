#!/bin/bash
# Script to add replicaCount to all service charts that don't have it

set -e

CHARTS_DIR="yas-cd/k8s/charts"
MISSING_REPLICAS=0
ADDED_REPLICAS=0

echo "Checking and adding replicaCount to all charts..."
echo ""

for chart_dir in "$CHARTS_DIR"/*/; do
  chart_name=$(basename "$chart_dir")
  values_file="$chart_dir/values.yaml"

  # Skip if not a chart directory
  if [ ! -f "$values_file" ]; then
    continue
  fi

  # Check if chart has backend dependency
  if grep -q "backend:" "$values_file"; then
    # Check if backend section has replicaCount
    if ! grep -A 10 "^backend:" "$values_file" | grep -q "replicaCount"; then
      echo "Adding replicaCount to $chart_name"
      # Add replicaCount after backend: line
      sed -i '/^backend:/a\  replicaCount: 1' "$values_file"
      ((ADDED_REPLICAS++))
    else
      echo "✓ $chart_name already has replicaCount"
    fi
  elif [ "$chart_name" = "backend" ] || [ "$chart_name" = "swagger-ui" ] || [ "$chart_name" = "ui" ]; then
    if grep -q "^replicaCount:" "$values_file"; then
      echo "✓ $chart_name already has replicaCount"
    else
      echo "Adding replicaCount to $chart_name"
      sed -i '1i replicaCount: 1\n' "$values_file"
      ((ADDED_REPLICAS++))
    fi
  fi
done

echo ""
echo "Summary: Added replicaCount to $ADDED_REPLICAS charts"
