#!/bin/bash
# Add replicaCount to all service charts

cd /home/dang/HCMUS/year3/semester2/devops/pj2

for values_file in yas-cd/k8s/charts/*/values.yaml; do
  chart_name=$(basename $(dirname "$values_file"))

  # Skip if already has replicaCount
  if grep -q "replicaCount:" "$values_file"; then
    echo "✓ $chart_name already has replicaCount"
    continue
  fi

  # Check if it has backend: section
  if grep -q "^backend:" "$values_file"; then
    echo "Adding replicaCount to $chart_name"
    # Add replicaCount after backend: line
    sed -i '/^backend:/a\  replicaCount: 1' "$values_file"
  fi
done

echo "Done!"
