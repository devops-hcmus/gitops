# Troubleshooting Guide - GitOps Mutual-Exclusive Environment Scaling

## Common Issues and Solutions

### Issue 1: State File Conflicts During Concurrent Deployments

**Symptom:** Git push fails with merge conflict in state.yaml

**Root Cause:** Two services deployed simultaneously, both trying to update state.yaml

**Solution:**
```bash
cd gitops
git pull --rebase
# Resolve conflicts manually if needed
git add state.yaml
git commit -m "resolve: state.yaml conflict"
git push
```

The workflow already has retry logic (5 attempts with 5s backoff), so this usually resolves automatically.

### Issue 2: Service Not Scaling Down

**Symptom:** Staging services still have replicas > 0 after dev deployment

**Root Cause:** 
- Service missing from state.yaml
- values.yaml doesn't have `backend.replicaCount` field
- ArgoCD sync failed

**Diagnosis:**
```bash
# Check if service is in state.yaml
yq e '.staging' gitops/state.yaml | grep <service-name>

# Check if values.yaml has replicaCount
yq e '.backend.replicaCount' gitops/clusters/staging/<service>/values.yaml

# Check ArgoCD Application status
kubectl get application -n argocd staging-<service> -o yaml
```

**Solution:**
1. Add service to state.yaml if missing:
   ```bash
   yq e '.staging.<service> = 1' -i gitops/state.yaml
   ```

2. Add replicaCount to values.yaml if missing:
   ```bash
   yq e '.backend.replicaCount = 1' -i gitops/clusters/staging/<service>/values.yaml
   ```

3. Force ArgoCD sync:
   ```bash
   argocd app sync staging-<service>
   ```

### Issue 3: Replicas Not Restoring to Previous Value

**Symptom:** Environment scales up but with wrong replica count (e.g., 0 instead of 1)

**Root Cause:** state.yaml wasn't updated correctly in previous deployment

**Solution:**
1. Check state.yaml history:
   ```bash
   git log -p gitops/state.yaml | head -50
   ```

2. Manually set correct replicas:
   ```bash
   yq e '.dev.<service> = 1' -i gitops/state.yaml
   git add state.yaml
   git commit -m "fix: restore correct replicas for <service>"
   git push
   ```

3. Trigger new deployment to apply changes

### Issue 4: Workflow Fails with "state.yaml not found"

**Symptom:** GitHub Actions workflow fails at state management step

**Root Cause:** state.yaml doesn't exist in gitops repo

**Solution:**
1. Verify state.yaml exists:
   ```bash
   ls -la gitops/state.yaml
   ```

2. If missing, regenerate it:
   ```bash
   bash gitops/scripts/generate-state.sh
   cd gitops
   git add state.yaml
   git commit -m "chore: regenerate state.yaml"
   git push
   ```

### Issue 5: New Service Added But Not Scaling

**Symptom:** New service deployed but doesn't participate in scaling

**Root Cause:** Service not in state.yaml

**Solution:**
1. Add service to state.yaml:
   ```bash
   yq e '.dev.<new-service> = 1' -i gitops/state.yaml
   yq e '.staging.<new-service> = 1' -i gitops/state.yaml
   ```

2. Commit and push:
   ```bash
   git add state.yaml
   git commit -m "chore: add <new-service> to state management"
   git push
   ```

### Issue 6: Both Environments Running Simultaneously

**Symptom:** Both dev and staging have replicas > 0

**Root Cause:** Manual override or workflow didn't execute properly

**Solution:**
1. Check which environment should be active
2. Scale down the inactive one:
   ```bash
   bash gitops/scripts/scale-environment.sh staging 0
   git add clusters/staging/*/values.yaml state.yaml
   git commit -m "fix: scale down staging to single active environment"
   git push
   ```

### Issue 7: ArgoCD Not Syncing Changes

**Symptom:** values.yaml updated but pods not restarting

**Root Cause:** ArgoCD auto-sync disabled or sync failed

**Solution:**
1. Check Application sync policy:
   ```bash
   kubectl get application -n argocd dev-<service> -o yaml | grep -A 5 syncPolicy
   ```

2. Manually trigger sync:
   ```bash
   argocd app sync dev-<service>
   ```

3. Check sync status:
   ```bash
   argocd app get dev-<service>
   ```

### Issue 8: Workflow Timeout

**Symptom:** GitHub Actions workflow times out during scale-environment step

**Root Cause:** Too many services or slow yq operations

**Solution:**
1. Check workflow logs for which service caused timeout
2. Manually scale that service:
   ```bash
   yq e '.backend.replicaCount = 0' -i gitops/clusters/staging/<service>/values.yaml
   ```

3. Commit and push
4. Retry workflow

## Debugging Commands

### View current state
```bash
cat gitops/state.yaml
```

### Check recent changes
```bash
cd gitops
git log --oneline -10 state.yaml
git log --oneline -10 clusters/dev/
git log --oneline -10 clusters/staging/
```

### Verify all services have replicaCount
```bash
for service in gitops/clusters/dev/*/; do
  service_name=$(basename "$service")
  replicas=$(yq e '.backend.replicaCount' "$service/values.yaml")
  echo "$service_name: $replicas"
done
```

### Check ArgoCD Application status
```bash
kubectl get applications -n argocd | grep -E "dev-|staging-"
argocd app list | grep -E "dev-|staging-"
```

### View workflow logs
- GitHub Actions: https://github.com/devops-hcmus/yas-cd/actions
- Look for failed workflow runs
- Check "Update image tag" and "Scale environment" steps

## Prevention Tips

1. **Always verify state.yaml after manual changes**
   ```bash
   git diff gitops/state.yaml
   ```

2. **Test scaling scripts locally before deployment**
   ```bash
   bash gitops/scripts/scale-environment.sh dev 0
   git diff gitops/clusters/dev/
   git checkout gitops/clusters/dev/  # Revert test
   ```

3. **Monitor first few deployments**
   - Watch GitHub Actions logs
   - Check ArgoCD UI for sync status
   - Verify replicas in kubectl

4. **Keep state.yaml in sync**
   - Review state.yaml changes in PRs
   - Don't manually edit without understanding impact
   - Use helper scripts for consistency

5. **Document manual overrides**
   - If you manually scale, update state.yaml
   - Add commit message explaining why
   - Notify team of temporary changes
