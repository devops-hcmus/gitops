# Rollback Procedure - GitOps Mutual-Exclusive Environment Scaling

## Quick Rollback (5 minutes)

If you need to immediately disable mutual-exclusive scaling:

### Step 1: Revert Workflow Changes
```bash
cd yas-cd
# Find the commit that modified the workflows
git log --oneline .github/workflows/_gitops-update.yaml | head -5
git log --oneline .github/workflows/update-staging-tag.yml | head -5

# Revert the workflow changes
git revert <commit-hash-for-_gitops-update.yaml>
git revert <commit-hash-for-update-staging-tag.yml>
git push
```

### Step 2: Scale Both Environments to Active
```bash
cd gitops
bash scripts/scale-environment.sh dev 1
bash scripts/scale-environment.sh staging 1
git add clusters/dev/*/values.yaml clusters/staging/*/values.yaml state.yaml
git commit -m "rollback: scale both environments to 1 replica"
git push
```

### Step 3: Verify
- Check ArgoCD UI - both environments should have replicas > 0
- Check kubectl: `kubectl get deployments -n dev` and `kubectl get deployments -n staging`

## Full Rollback (with cleanup)

If you want to completely remove the mutual-exclusive scaling feature:

### Step 1: Revert All Changes
```bash
cd yas-cd
git log --oneline | grep -i "mutual\|scale\|environment" | head -10
git revert <all-related-commit-hashes>
git push
```

### Step 2: Clean Up GitOps Repo
```bash
cd gitops

# Remove state.yaml
git rm state.yaml
git commit -m "cleanup: remove state.yaml"

# Remove helper scripts
git rm scripts/read-state.sh scripts/write-state.sh scripts/scale-environment.sh
git commit -m "cleanup: remove helper scripts"

# Remove documentation
git rm ENVIRONMENT_SCALING.md TROUBLESHOOTING.md
git commit -m "cleanup: remove scaling documentation"

git push
```

### Step 3: Scale Both Environments
```bash
cd gitops
bash scripts/scale-environment.sh dev 1
bash scripts/scale-environment.sh staging 1
git add clusters/dev/*/values.yaml clusters/staging/*/values.yaml
git commit -m "rollback: scale both environments to 1 replica"
git push
```

### Step 4: Verify Complete Rollback
```bash
# Check no state.yaml exists
ls gitops/state.yaml  # Should fail

# Check workflows are reverted
git log --oneline .github/workflows/_gitops-update.yaml | head -3

# Check both environments running
kubectl get deployments -n dev | grep -v NAME
kubectl get deployments -n staging | grep -v NAME
```

## Partial Rollback (Keep State Management, Disable Scaling)

If you want to keep state.yaml but disable automatic scaling:

### Step 1: Revert Workflow Changes Only
```bash
cd yas-cd
git revert <commit-hash-for-_gitops-update.yaml>
git revert <commit-hash-for-update-staging-tag.yml>
git push
```

### Step 2: Manually Scale Both Environments
```bash
cd gitops
bash scripts/scale-environment.sh dev 1
bash scripts/scale-environment.sh staging 1
git add clusters/dev/*/values.yaml clusters/staging/*/values.yaml
git commit -m "manual: scale both environments to 1 replica"
git push
```

### Step 3: Keep State Files for Future Use
- state.yaml remains in gitops repo
- Helper scripts remain available
- Can re-enable scaling by reverting the reverts

## Rollback Verification Checklist

- [ ] Workflows reverted (check GitHub Actions)
- [ ] Both environments have replicas > 0
- [ ] ArgoCD Applications synced successfully
- [ ] Pods running in both dev and staging namespaces
- [ ] No errors in ArgoCD UI
- [ ] Git history shows rollback commits
- [ ] state.yaml removed (if full rollback)
- [ ] Helper scripts removed (if full rollback)

## Troubleshooting Rollback

### Issue: Workflows still using old logic
**Solution:** 
```bash
git log --oneline .github/workflows/ | head -5
# Verify revert commits are present
git show <revert-commit-hash>
```

### Issue: Services still scaled to 0
**Solution:**
```bash
# Manually scale up
bash gitops/scripts/scale-environment.sh dev 1
bash gitops/scripts/scale-environment.sh staging 1
git add clusters/dev/*/values.yaml clusters/staging/*/values.yaml
git commit -m "fix: manually scale up after rollback"
git push
```

### Issue: ArgoCD not syncing after rollback
**Solution:**
```bash
# Force sync all applications
argocd app sync dev-product dev-cart dev-customer ...
argocd app sync staging-product staging-cart staging-customer ...

# Or sync all at once
kubectl patch application -n argocd -p '{"metadata":{"annotations":{"argocd.argoproj.io/compare-result":""}}}' --all
```

## Prevention: Backup Before Major Changes

Before deploying mutual-exclusive scaling to production:

```bash
# Create backup branch
cd gitops
git checkout -b backup/before-mutual-exclusive-scaling
git push origin backup/before-mutual-exclusive-scaling

# Create backup branch in yas-cd
cd yas-cd
git checkout -b backup/before-mutual-exclusive-scaling
git push origin backup/before-mutual-exclusive-scaling
```

Then if rollback is needed, you can reference these backup branches.
