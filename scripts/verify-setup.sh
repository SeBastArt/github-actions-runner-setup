#!/bin/bash
set -e

echo "🔍 Verifying GitHub Actions Runner Setup..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print status
print_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
        exit 1
    fi
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "ℹ️  $1"
}

# Check if kubectl is configured
print_info "Checking kubectl configuration..."
kubectl cluster-info > /dev/null 2>&1
print_status $? "kubectl is configured and cluster is reachable"

# Check if actions-runner-system namespace exists
print_info "Checking namespace..."
kubectl get namespace actions-runner-system > /dev/null 2>&1
print_status $? "actions-runner-system namespace exists"

# Check if ARC controller is running
print_info "Checking ARC Controller..."
CONTROLLER_READY=$(kubectl get pods -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller --no-headers | grep -c "Running" || echo "0")
if [ "$CONTROLLER_READY" -gt 0 ]; then
    print_status 0 "ARC Controller is running ($CONTROLLER_READY pods)"
else
    print_status 1 "ARC Controller is not running"
fi

# Check if runner scale set exists
print_info "Checking Runner Scale Set..."
SCALE_SET_EXISTS=$(kubectl get runnerscalesets -n actions-runner-system --no-headers 2>/dev/null | wc -l || echo "0")
if [ "$SCALE_SET_EXISTS" -gt 0 ]; then
    print_status 0 "Runner Scale Set exists ($SCALE_SET_EXISTS scale sets configured)"
else
    print_warning "No runner scale set found - this might be normal if no jobs are queued"
fi

# Check node architecture
print_info "Checking cluster architecture..."
ARM_NODES=$(kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.architecture}' | grep -c "arm64" || echo "0")
if [ "$ARM_NODES" -gt 0 ]; then
    print_status 0 "ARM64 nodes detected ($ARM_NODES nodes)"
else
    print_warning "No ARM64 nodes detected - runners may not schedule properly"
fi

# Check if Docker daemon is accessible on nodes
print_info "Checking Docker availability..."
if kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}' | grep -q "docker\|containerd"; then
    print_status 0 "Container runtime is available"
else
    print_warning "Container runtime status unclear"
fi

# Show current runner status
print_info "Current runner status:"
kubectl get runnerscalesets -n actions-runner-system 2>/dev/null || echo "No runner scale sets currently active"
kubectl get runners -n actions-runner-system 2>/dev/null || echo "No individual runners currently active"

echo ""
print_info "Setup verification completed!"

# Instructions for next steps
echo ""
echo "🚀 Next Steps:"
echo "1. Create a GitHub App or Personal Access Token"
echo "2. Configure repository secrets:"
echo "   - KUBECONFIG: Your cluster kubeconfig (base64 encoded)"
echo "   - GITHUB_TOKEN: GitHub App token or PAT"
echo "   - GITHUB_CONFIG_URL: Your GitHub org/repo URL"
echo "3. Run a test workflow in a private repository"

echo ""
echo "📋 Test your setup with a simple workflow:"
echo "   runs-on: [self-hosted, linux, ARM64]"
