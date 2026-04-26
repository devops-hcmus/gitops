# GitOps Mutual-Exclusive Environment Scaling

## Overview

This implementation enables automatic scaling of dev and staging environments to ensure only one environment runs at a time, reducing resource consumption by ~50%.

## How It Works

### State Management
- **state.yaml**: Tracks the replica count for each service in each environment
- Located at: `gitops/state.yaml`
- Format: YAML with `dev:` and `staging:` sections

### Deployment Flow

#### Dev Deployment (push to main)
1. Service CI builds and pushes image
2. `_gitops-update.yaml` workflow:
   - Reads current dev replicas from state.yaml
   - Updates dev service values with new image tag and restored replicas
   - Scales ALL staging services to replicas: 0
   - Saves dev replicas to state.yaml
   - Commits and pushes changes

#### Staging Deployment (create tag)
1. Tag creation triggers `update-staging-tag.yml` workflow
2. Workflow:
   - Reads current staging replicas from state.yaml
   - Updates ALL staging services with new tag and restored replicas
   - Scales ALL dev services to replicas: 0
   - Saves staging replicas to state.yaml
   - Updates ArgoCD Application targetRevision
   - Commits and pushes changes

### State Restoration

When deploying to an environment that was previously scaled down:
- Script reads the last known replica count from state.yaml
- Restores that replica count during deployment
- Example: If dev was scaled to 0, next dev deploy restores it to 1

## Helper Scripts

Located in `gitops/scripts/`:

### read-state.sh
```bash
bash scripts/read-state.sh <env> <service>
# Example: bash scripts/read-state.sh dev product
# Output: 1
```

### write-state.sh
```bash
bash scripts/write-state.sh <env> <service> <replicas>
# Example: bash scripts/write-state.sh dev product 2
```

### scale-environment.sh
```bash
bash scripts/scale-environment.sh <env> <replicas>
# Example: bash scripts/scale-environment.sh staging 0
```

## Manual Override

To manually override the automatic scaling:

### Scale an environment up
```bash
cd gitops
bash scripts/scale-environment.sh dev 1
git add clusters/dev/*/values.yaml state.yaml
git commit -m "manual: scale dev to 1 replica"
git push
```

### Scale an environment down
```bash
cd gitops
bash scripts/scale-environment.sh staging 0
git add clusters/staging/*/values.yaml state.yaml
git commit -m "manual: scale staging to 0 replicas"
git push
```

### Run both environments simultaneously (temporary)
Edit `state.yaml` and set both environments to desired replicas, then manually update values files.

## Monitoring

### Check current state
```bash
cat gitops/state.yaml
```

### View ArgoCD UI
- Navigate to ArgoCD dashboard
- Check Application sync status for each environment
- Verify replicas in Deployments tab

### Git history
```bash
cd gitops
git log --oneline state.yaml
git log --oneline clusters/dev/
git log --oneline clusters/staging/
```

## Troubleshooting

### State file conflicts
If you see git merge conflicts in state.yaml:
1. Pull latest: `git pull --rebase`
2. Resolve conflicts manually
3. Commit and push

### Service not scaling
1. Check if service exists in state.yaml
2. Verify values.yaml has `backend.replicaCount` field
3. Check ArgoCD Application sync status
4. Review workflow logs in GitHub Actions

### Replicas not restoring
1. Verify state.yaml has correct replica count
2. Check if values.yaml is being updated correctly
3. Review workflow execution logs

## Rollback

To disable mutual-exclusive scaling and return to previous behavior:

1. Revert workflow changes:
   ```bash
   git revert <commit-hash-for-workflow-changes>
   ```

2. Manually scale both environments to desired replicas:
   ```bash
   bash scripts/scale-environment.sh dev 1
   bash scripts/scale-environment.sh staging 1
   ```

3. Commit and push

## Known Limitations

- Cannot run both dev and staging simultaneously (by design)
- Manual override required for concurrent environment testing
- State file must be manually managed if services are added/removed
- No automatic cleanup of removed services from state.yaml
