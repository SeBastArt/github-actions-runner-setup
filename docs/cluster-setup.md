# Kubernetes Cluster Setup for GitHub Actions Runners

## Prerequisites

Before deploying the GitHub Actions Runner Controller, ensure your ARM64 Kubernetes cluster meets these requirements.

## Cluster Requirements

### Minimum Resources
- **Nodes**: At least 1 ARM64 node
- **CPU**: 2+ cores per node recommended  
- **Memory**: 4GB+ RAM per node recommended
- **Storage**: 20GB+ available storage

### Kubernetes Version
- **Supported**: Kubernetes 1.24+
- **Recommended**: Kubernetes 1.28+

## Pre-Installation Checklist

### 1. Verify Cluster Access

```bash
# Test cluster connectivity
kubectl cluster-info

# Verify ARM64 nodes
kubectl get nodes -o wide
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.architecture}'
```

### 2. Check Container Runtime

```bash
# Verify container runtime (Docker or containerd)
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.containerRuntimeVersion}'

# For Docker socket access (if needed)
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.operatingSystem}'
```

### 3. Verify Network Connectivity

```bash
# Test internet access from cluster
kubectl run test-pod --image=alpine:latest --rm -i --tty -- /bin/sh
# Inside pod: ping 8.8.8.8, nslookup github.com, exit
```

## Required Cluster Permissions

Your kubeconfig user needs these permissions:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: github-actions-runner-admin
rules:
# Namespace management
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]

# Pod and deployment management  
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec"]
  verbs: ["get", "list", "create", "update", "patch", "delete", "watch"]

- apiGroups: ["apps"]
  resources: ["deployments", "replicasets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]

# Service accounts and RBAC
- apiGroups: [""]
  resources: ["serviceaccounts", "secrets", "configmaps"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]

- apiGroups: ["rbac.authorization.k8s.io"]
  resources: ["roles", "rolebindings", "clusterroles", "clusterrolebindings"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]

# Custom resources (for ARC)
- apiGroups: ["actions.summerwind.dev", "actions.github.com"]
  resources: ["*"]
  verbs: ["*"]

# Admission controllers
- apiGroups: ["admissionregistration.k8s.io"]
  resources: ["mutatingwebhookconfigurations", "validatingwebhookconfigurations"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
```

## Network Requirements

### Outbound Connectivity

Your cluster needs outbound access to:

- **GitHub API**: `api.github.com:443`
- **GitHub Assets**: `github.com:443`
- **Docker Hub**: `registry-1.docker.io:443` (for pulling runner images)
- **Helm Charts**: `actions-runner-controller.github.io:443`

### Internal Connectivity

- Pods need to communicate within the cluster
- If using Docker-in-Docker, ensure proper networking setup

## Storage Requirements

### Persistent Volumes (Optional)

If you want persistent tool caches:

```yaml
apiVersion: v1
kind: StorageClass
metadata:
  name: runner-storage
provisioner: kubernetes.io/no-provisioner
volumeBindingMode: WaitForFirstConsumer
reclaimPolicy: Delete
```

### Temporary Storage

Ensure nodes have sufficient ephemeral storage for:
- Container images
- Build artifacts  
- Tool caches

## Security Considerations

### 1. Node Security

```bash
# Ensure nodes are properly secured
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kubeletVersion}'

# Check for security updates
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.kernelVersion}'
```

### 2. Pod Security Standards

Create a policy for runner pods:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: actions-runner-system
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### 3. Network Policies (Optional)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: runner-network-policy
  namespace: actions-runner-system
spec:
  podSelector:
    matchLabels:
      app: github-runner
  policyTypes:
  - Egress
  egress:
  - to: []
    ports:
    - protocol: TCP
      port: 443
    - protocol: TCP
      port: 80
    - protocol: UDP
      port: 53
```

## ARM64 Specific Setup

### 1. Verify Architecture Support

```bash
# Check all nodes are ARM64
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.nodeInfo.architecture}{"\n"}{end}'
```

### 2. Container Image Compatibility

Ensure your workflow uses ARM64-compatible images:

```yaml
# In your workflows, verify images support arm64
docker manifest inspect alpine:latest
docker manifest inspect node:18-alpine
```

### 3. Cross-Platform Builds (Future)

If you need to build for AMD64 later:

```bash
# Install buildx on runner nodes (optional)
# This will be handled in the runner configuration
```

## Validation Script

Run this script to validate your cluster setup:

```bash
#!/bin/bash
echo "Validating cluster for GitHub Actions Runners..."

# Check cluster access
if ! kubectl cluster-info > /dev/null 2>&1; then
  echo "❌ Cannot access Kubernetes cluster"
  exit 1
fi

# Check ARM64 nodes
ARM_NODES=$(kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.architecture}' | grep -c arm64)
if [ "$ARM_NODES" -eq 0 ]; then
  echo "❌ No ARM64 nodes found"
  exit 1
fi
echo "✅ Found $ARM_NODES ARM64 nodes"

# Check container runtime
RUNTIME=$(kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}')
echo "✅ Container runtime: $RUNTIME"

# Check outbound connectivity
if kubectl run connectivity-test --image=alpine:latest --rm -i --restart=Never -- wget -q --spider https://api.github.com; then
  echo "✅ GitHub API accessible"
else
  echo "❌ Cannot reach GitHub API"
fi

echo "Cluster validation completed!"
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   kubectl auth can-i create pods --namespace=actions-runner-system
   ```

2. **Image Pull Errors**
   ```bash
   kubectl describe pod <pod-name> -n actions-runner-system
   ```

3. **Network Issues**
   ```bash
   kubectl exec -it <pod-name> -n actions-runner-system -- nslookup api.github.com
   ```

### Debug Commands

```bash
# Check node conditions
kubectl describe nodes

# Check system pods
kubectl get pods -n kube-system

# Check resource usage
kubectl top nodes
kubectl top pods -n actions-runner-system
```

## Next Steps

After validating your cluster:

1. ✅ Cluster meets requirements
2. ✅ Permissions configured
3. ✅ Network connectivity verified
4. → Proceed with GitHub App setup
5. → Deploy ARC using the workflow
