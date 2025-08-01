# Kubernetes Cluster Setup for GitHub Actions Runners
# ===================================================

This guide helps you prepare your ARM64 Kubernetes cluster for deploying GitHub's official Actions Runner Controller (ARC) with OCI charts.

## Prerequisites Overview

Before deploying ARC, ensure your ARM64 Kubernetes cluster meets these requirements and has proper security configurations in place.

## Cluster Requirements

### Minimum System Requirements
- **Kubernetes Version**: 1.24+ (recommended: 1.28+)
- **Nodes**: At least 1 ARM64 node with sufficient resources
- **CPU**: 2+ cores per node (4+ cores recommended for production)
- **Memory**: 4GB+ RAM per node (8GB+ recommended for production)
- **Storage**: 20GB+ available storage per node
- **Container Runtime**: Docker or containerd

### Architecture Verification
Your cluster must have ARM64 nodes available:

```bash
# Verify all nodes are ARM64
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.architecture}{"\n"}{end}'

# Should show "arm64" for all nodes
# Expected output:
# node-1  arm64
# node-2  arm64
```

## Pre-Installation Validation

### 1. Cluster Access and Health
```bash
# Test basic cluster connectivity
kubectl cluster-info

# Verify nodes are ready
kubectl get nodes -o wide

# Check system pods are running
kubectl get pods -n kube-system
```

### 2. Container Runtime Verification
```bash
# Check container runtime version
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.containerRuntimeVersion}'

# For Docker-in-Docker support, verify Docker socket availability
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.operatingSystem}'
```

### 3. Network Connectivity Test
Your cluster needs outbound internet access:

```bash
# Test network connectivity from cluster
kubectl run network-test --image=alpine:latest --rm -i --tty -- /bin/sh

# Inside the test pod, run:
ping -c 3 8.8.8.8
nslookup github.com
wget -q --spider https://api.github.com && echo "GitHub API reachable"
wget -q --spider https://ghcr.io && echo "GitHub Container Registry reachable"
exit
```

## Required Network Access

Your cluster must have outbound access to these endpoints:

### Essential Endpoints
- **GitHub API**: `api.github.com:443`
- **GitHub Assets**: `github.com:443` 
- **GitHub Container Registry**: `ghcr.io:443` (for OCI charts and runner images)
- **Docker Hub**: `registry-1.docker.io:443` (for pulling images)

### DNS Resolution
Ensure your cluster can resolve these domains:
```bash
# Test DNS resolution
kubectl run dns-test --image=alpine:latest --rm -i --restart=Never -- nslookup api.github.com
kubectl run dns-test --image=alpine:latest --rm -i --restart=Never -- nslookup ghcr.io
```

## Kubernetes Permissions Setup

### Required Cluster Permissions
Your kubeconfig user needs these permissions to deploy ARC:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: arc-deployment-admin
rules:
# Namespace management
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]

# Pod and deployment management  
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec", "services", "serviceaccounts", "secrets", "configmaps"]
  verbs: ["get", "list", "create", "update", "patch", "delete", "watch"]

- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]

# RBAC management
- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]

# ARC Custom Resources (v0.12+)
- apiGroups: ["actions.github.com"]
  resources: ["*"]
  verbs: ["*"]

# Webhook configurations
- apiGroups: ["admissionregistration.k8s.io"]
  resources: ["mutatingwebhookconfigurations", "validatingwebhookconfigurations"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
```

### Permission Verification
```bash
# Test if you have required permissions
kubectl auth can-i create namespaces
kubectl auth can-i create pods --namespace=actions-runner-system
kubectl auth can-i create secrets --namespace=actions-runner-system
kubectl auth can-i create clusterroles
```

## Security Configuration

### 1. Namespace Security
When ARC creates the namespace, it should have proper security policies:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: actions-runner-system
  labels:
    # Kubernetes Pod Security Standards
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 2. Network Security (Optional but Recommended)
If you use NetworkPolicies, create one for runner pods:

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: arc-runner-network-policy
  namespace: actions-runner-system
spec:
  podSelector:
    matchLabels:
      app: github-runner
  policyTypes:
  - Egress
  egress:
  # Allow HTTPS and HTTP outbound
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
  # Allow DNS
  - to: []
    ports:
    - protocol: UDP
      port: 53
```

### 3. Node Security Best Practices
```bash
# Verify nodes are properly secured
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}'
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kernelVersion}'

# Check for security updates
kubectl describe nodes | grep -i "kernel\|container\|runtime"
```

## Storage Configuration

### Ephemeral Storage (Default)
ARC runners use ephemeral storage by default, which is recommended for security:

```bash
# Verify available storage on nodes
kubectl describe nodes | grep -A5 -B5 "Allocatable"

# Check ephemeral storage
kubectl top nodes
```

### Persistent Storage (Optional)
If you need persistent tool caches, prepare storage classes:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: arc-runner-storage
provisioner: kubernetes.io/no-provisioner  # Adjust for your cluster
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
allowVolumeExpansion: true
```

## Container Image Preparation

### ARM64 Image Compatibility
Verify that your workflows use ARM64-compatible images:

```bash
# Test common images support ARM64
docker manifest inspect alpine:latest | grep arm64
docker manifest inspect node:18-alpine | grep arm64
docker manifest inspect ubuntu:22.04 | grep arm64

# GitHub's runner images are multi-arch and support ARM64
docker manifest inspect ghcr.io/actions/actions-runner:latest | grep arm64
```

### Pre-pull Critical Images (Optional)
For faster startup, consider pre-pulling images on nodes:

```bash
# On each node, pre-pull common images
docker pull ghcr.io/actions/actions-runner:latest
docker pull alpine:latest
docker pull ubuntu:22.04
```

## Validation and Testing

### Cluster Validation Script
Run this comprehensive validation:

```bash
#!/bin/bash
echo "🔍 Validating cluster for GitHub Actions Runner Controller..."

# 1. Cluster connectivity
echo "Testing cluster connectivity..."
if ! kubectl cluster-info > /dev/null 2>&1; then
  echo "❌ Cannot access Kubernetes cluster"
  exit 1
fi
echo "✅ Cluster is accessible"

# 2. ARM64 nodes
echo "Checking ARM64 nodes..."
ARM_NODES=$(kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.architecture}' | grep -c arm64)
if [ "$ARM_NODES" -eq 0 ]; then
  echo "❌ No ARM64 nodes found"
  exit 1
fi
echo "✅ Found $ARM_NODES ARM64 nodes"

# 3. Node resources
echo "Checking node resources..."
kubectl top nodes || echo "⚠️  Metrics server not available - resource monitoring limited"

# 4. Container runtime
RUNTIME=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}')
echo "✅ Container runtime: $RUNTIME"

# 5. Network connectivity
echo "Testing GitHub connectivity..."
if kubectl run connectivity-test --image=alpine:latest --rm -i --restart=Never -- wget -q --spider https://api.github.com; then
  echo "✅ GitHub API is accessible"
else
  echo "❌ Cannot reach GitHub API - check firewall/network policies"
fi

if kubectl run connectivity-test --image=alpine:latest --rm -i --restart=Never -- wget -q --spider https://ghcr.io; then
  echo "✅ GitHub Container Registry is accessible"
else
  echo "❌ Cannot reach GitHub Container Registry"
fi

# 6. Permissions check
echo "Checking permissions..."
if kubectl auth can-i create pods --namespace=actions-runner-system; then
  echo "✅ Pod creation permissions available"
else
  echo "❌ Insufficient permissions for pod creation"
fi

if kubectl auth can-i create secrets --namespace=actions-runner-system; then
  echo "✅ Secret creation permissions available"
else
  echo "❌ Insufficient permissions for secret creation"
fi

echo ""
echo "🎉 Cluster validation completed!"
echo ""
echo "Next steps:"
echo "1. Create GitHub Organization Token with admin:org + repo permissions"
echo "2. Set up GitHub Environment Protection in your deployment repository"
echo "3. Deploy ARC using the GitHub Actions workflow"
echo "4. Test with a simple workflow targeting your runner"
```

### Save and run this script:
```bash
# Save as validate-cluster.sh and make executable
chmod +x validate-cluster.sh
./validate-cluster.sh
```

## Common Issues and Fixes

### Permission Denied Errors
```bash
# Check current context and permissions
kubectl config current-context
kubectl auth can-i '*' '*' --all-namespaces

# If using managed Kubernetes (EKS, GKE, AKS), ensure you have admin role
```

### Image Pull Errors
```bash
# Check if images can be pulled
kubectl run test-pull --image=ghcr.io/actions/actions-runner:latest --rm -i --restart=Never

# Check node image cache
kubectl describe nodes | grep -A10 -B10 "Images"
```

### Network Connectivity Issues
```bash
# Test from a pod in the cluster
kubectl run debug-pod --image=alpine:latest -it --rm -- /bin/sh
# Inside pod: ping 8.8.8.8, nslookup api.github.com, wget https://github.com

# Check cluster DNS
kubectl get pods -n kube-system | grep dns
kubectl logs -n kube-system -l k8s-app=kube-dns
```

## Post-Validation Next Steps

After successful validation:

### ✅ Prerequisites Complete
1. **Cluster Access**: ✅ Verified
2. **ARM64 Nodes**: ✅ Available  
3. **Permissions**: ✅ Configured
4. **Network**: ✅ GitHub accessible
5. **Container Runtime**: ✅ Ready

### 🚀 Ready for Deployment
1. **Create Organization Token** with admin:org and repo permissions
2. **Set up Environment Protection** in your deployment repository
3. **Deploy ARC** using the provided GitHub Actions workflow
4. **Test deployment** with the test-runners.yml workflow

### 🔒 Security Checklist
- [ ] Environment Protection configured in GitHub repository
- [ ] Branch Protection Rules enabled
- [ ] Secrets stored at Environment level (not repository level)
- [ ] Network policies configured (if required)
- [ ] Node security patches up to date

Your ARM64 Kubernetes cluster is now ready for secure GitHub Actions Runner deployment!