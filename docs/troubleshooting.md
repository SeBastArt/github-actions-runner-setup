# Troubleshooting Guide for GitHub Actions Runner Controller (ARC)
# =================================================================

This guide helps you diagnose and fix common issues when deploying GitHub's official Actions Runner Controller with OCI charts on ARM64 Kubernetes clusters.

## Quick Diagnosis Commands

Before diving into specific issues, run these commands to get an overview:

```bash
# Check overall cluster and ARC status
kubectl cluster-info
kubectl get all -n actions-runner-system

# Check your ARM64 nodes
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.architecture}'

# View recent events (most helpful for quick diagnosis)
kubectl get events -n actions-runner-system --sort-by='.lastTimestamp'
```

## Common Issues and Solutions

### 1. Runners Not Appearing in GitHub

**Symptoms:**
- Deployment succeeds but no runners visible in GitHub Settings
- Jobs stuck in queue with "Waiting for a runner to pick up this job"

**Quick Diagnosis:**
```bash
# Check controller status
kubectl get pods -n actions-runner-system
kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller

# Check AutoscalingRunnerSet (ARC v0.12+)
kubectl get autoscalingrunnerset -n actions-runner-system
kubectl describe autoscalingrunnerset -n actions-runner-system
```

**Common Causes & Fixes:**
- **Token expired** → Create new Organization Token with admin:org + repo permissions
- **Wrong CONFIG_URL** → Must be Organization URL: `https://github.com/YOUR_ORG`
- **Missing permissions** → Token needs admin:org and repo scopes
- **Wrong API endpoint** → Verify token with: `curl -H "Authorization: token ghp_..." https://api.github.com/orgs/YOUR_ORG`

### 2. Authentication Errors

**Error Messages:**
```
Error: Bad credentials
Error: Not Found
Error: API rate limit exceeded
```

**Solutions:**
```bash
# Test your Organization Token
curl -H "Authorization: token ghp_..." https://api.github.com/orgs/YOUR_ORG

# Check token permissions (should list runners)
curl -H "Authorization: token ghp_..." https://api.github.com/orgs/YOUR_ORG/actions/runners

# Verify CONFIG_URL format
echo $CONFIG_URL  # Should be https://github.com/YOUR_ORG
```

**Fix Steps:**
1. Generate new Organization Token in GitHub Organization Settings
2. Ensure admin:org and repo permissions are granted
3. Update TOKEN secret in your GitHub repository
4. Redeploy using the workflow

### 3. Pods Won't Start (Pending/ImagePullBackOff)

**Symptoms:**
- Runner pods stuck in "Pending" or "ImagePullBackOff"
- No runners scaling up despite jobs in queue

**Diagnosis:**
```bash
# Check pod status and events
kubectl get pods -n actions-runner-system
kubectl describe pod <pod-name> -n actions-runner-system

# Check node resources and architecture
kubectl get nodes -o wide
kubectl describe nodes
kubectl top nodes
```

**Common Causes:**
- **No ARM64 nodes available** → Verify: `kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.architecture}'`
- **Resource constraints** → Check node CPU/memory availability
- **Image pull issues** → Verify network connectivity to GitHub Container Registry

**Solutions:**
```bash
# Verify ARM64 node selector is working
kubectl get autoscalingrunnerset -n actions-runner-system -o yaml | grep -A5 nodeSelector

# Check if nodes meet resource requirements
kubectl describe autoscalingrunnerset -n actions-runner-system | grep -A10 "Resources"

# Test image pull manually
docker pull ghcr.io/actions/actions-runner:latest
```

### 4. Docker-in-Docker Not Working

**Error Messages:**
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
docker: command not found
```

**Root Cause:**
This setup uses `containerMode.type: "dind"` which automatically provisions Docker-in-Docker sidecars.

**Verification:**
```bash
# Check if containerMode is properly configured
kubectl get autoscalingrunnerset <name> -o yaml | grep -A5 -B5 dind

# Verify docker:dind sidecar is running
kubectl describe autoscalingrunnerset <name> | grep -A10 "Init Containers"
kubectl describe pod <runner-pod> | grep -A10 docker
```

**Fix:**
```bash
# Ensure values/base.yaml contains:
# containerMode:
#   type: "dind"

# Redeploy if missing
helm upgrade --install production-runners \
  --namespace actions-runner-system \
  --values ./values/base.yaml \
  --values ./values/production.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

### 5. Jobs Stuck in Queue

**Most Common Cause: Wrong Runner Targeting**

In ARC v0.12+, you MUST use the runnerScaleSetName, not label arrays:

```yaml
# ❌ WRONG (deprecated in ARC v0.12+)
runs-on: [self-hosted, linux, ARM64, arm64-runners]

# ✅ CORRECT  
runs-on: production-arm64  # Must match runnerScaleSetName in values/production.yaml
```

**Other Causes:**
```bash
# Check if runners are actually online
kubectl get autoscalingrunnerset -n actions-runner-system
kubectl get pods -n actions-runner-system

# Verify scaling limits
kubectl describe autoscalingrunnerset | grep -A5 "Min\|Max"
```

**Runner Visibility Settings (GitHub Organization):**
1. Go to **GitHub Organization** → **Settings** → **Actions** → **Runners**
2. Click on your runner (e.g., `production-arm64`)
3. Set **Repository access** → **Selected repositories** or **All repositories**
4. Enable **Runner visibility** → ✅ **Public repositories** + ✅ **Private repositories**

### 6. OCI Chart Specific Issues (ARC v0.12+)

**Error: "More than one gha-rs-controller deployment found"**
```bash
# Solution: Explicit controller service account reference
helm upgrade --install production-runners \
  --set controllerServiceAccount.name="arc-controller-gha-rs-controller" \
  --set controllerServiceAccount.namespace="actions-runner-system" \
  --namespace actions-runner-system \
  --values ./values/base.yaml \
  --values ./values/production.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

**Values Files Not Applied:**
```bash
# Debug: Check what values are actually applied
helm get values production-runners -n actions-runner-system

# Test without installation
helm template test-release \
  --values ./values/base.yaml \
  --values ./values/production.yaml \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
```

### 7. Network Connectivity Issues

**Symptoms:**
- Workflows can't reach internet
- Docker pulls fail
- Git operations timeout

**Diagnosis:**
```bash
# Test connectivity from a runner pod
kubectl exec -it <runner-pod> -n actions-runner-system -- nslookup github.com
kubectl exec -it <runner-pod> -n actions-runner-system -- curl -I https://github.com

# Test from cluster (create debug pod)
kubectl run debug-pod --image=alpine -it --rm -- /bin/sh
# Inside pod: ping 8.8.8.8, nslookup github.com, wget https://github.com
```

**Required Outbound Access:**
- `api.github.com:443` (GitHub API)
- `github.com:443` (GitHub assets)
- `ghcr.io:443` (GitHub Container Registry)
- `registry-1.docker.io:443` (Docker Hub)

### 8. Resource Quotas and Limits

**Error Messages:**
```
pods "runner-xyz" is forbidden: exceeded quota
Insufficient memory
Insufficient cpu
```

**Solutions:**
```bash
# Check current resource usage
kubectl top nodes
kubectl top pods -n actions-runner-system

# Check quotas
kubectl describe quota -n actions-runner-system

# Adjust limits in values/production.yaml
template:
  spec:
    containers:
    - name: runner
      resources:
        requests:
          cpu: "100m"      # Reduce if needed
          memory: "256Mi"  # Reduce if needed
        limits:
          cpu: "2000m"     # Adjust based on available resources
          memory: "4Gi"    # Adjust based on available resources
```

## Complete Cleanup and Fresh Start

If you're experiencing persistent issues:

```bash
# 1. Run cleanup script
./scripts/cleanup.sh

# 2. Manual namespace cleanup if needed
kubectl delete namespace actions-runner-system --force --grace-period=0

# 3. Clean up CRDs (careful!)
kubectl get crd | grep actions | awk '{print $1}' | xargs kubectl delete crd

# 4. Fresh deployment
# Use deploy-runners.yml workflow with clean environment
```

## Debug Commands Reference

```bash
# Cluster Overview
kubectl cluster-info
kubectl get nodes -o wide
kubectl get all -n actions-runner-system

# Controller Logs
kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller -f

# Runner Logs
kubectl logs -n actions-runner-system -l app=github-runner -f

# Events (most useful for troubleshooting)
kubectl get events -n actions-runner-system --sort-by='.lastTimestamp'

# Custom Resources (ARC v0.12+)
kubectl get autoscalingrunnerset -n actions-runner-system -o yaml
kubectl describe autoscalingrunnerset -n actions-runner-system

# Resource Usage
kubectl top nodes
kubectl top pods -n actions-runner-system

# Helm Status
helm list -n actions-runner-system
helm status production-runners -n actions-runner-system
```

## Performance Optimization

### For Better Performance:
```yaml
# In values/production.yaml
template:
  spec:
    containers:
    - name: runner
      resources:
        requests:
          cpu: "1000m"      # More CPU
          memory: "2Gi"     # More memory
        limits:
          cpu: "4000m"
          memory: "8Gi"

# More parallel runners
maxRunners: 10
minRunners: 2

# Faster scaling
scaleDownDelaySecondsAfterScaleOut: 120
```

### ARM64 Specific Optimizations:
```yaml
# Use native ARM64 builds
template:
  spec:
    containers:
    - name: runner
      env:
      - name: DOCKER_BUILDKIT
        value: "1"
      - name: BUILDX_EXPERIMENTAL  
        value: "1"
```

## Getting Help

When all troubleshooting steps fail:

1. **GitHub Issues**: https://github.com/actions/actions-runner-controller/issues
2. **Check GitHub Status**: https://www.githubstatus.com/
3. **Enable Debug Logging**:
   ```yaml
   # In values/base.yaml
   log:
     level: debug  # instead of info
     format: json  # for structured logs
   ```
   Then check logs: `kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller -f`

4. **System Events**: `kubectl get events --all-namespaces`

## Remember

- **Always use Environment Protection** for production deployments
- **Monitor resource usage** regularly
- **Rotate tokens** periodically
- **Keep runners updated** by redeploying regularly
- **Test in staging** before production changes

This troubleshooting guide should help you resolve most common issues. For complex problems, gather logs and system information before seeking help.