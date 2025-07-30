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

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# Check if kubectl is configured
print_info "Checking kubectl configuration..."
if kubectl cluster-info > /dev/null 2>&1; then
    print_success "kubectl is configured and cluster is reachable"
else
    print_status 1 "kubectl is not configured or cluster is not reachable"
fi

# Check if actions-runner-system namespace exists
print_info "Checking namespace..."
if kubectl get namespace actions-runner-system > /dev/null 2>&1; then
    print_success "actions-runner-system namespace exists"
else
    print_status 1 "actions-runner-system namespace does not exist"
fi

# Check if ARC controller is running
print_info "Checking ARC Controller..."
RUNNING_PODS=$(kubectl get pods -n actions-runner-system --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l)
TOTAL_PODS=$(kubectl get pods -n actions-runner-system --no-headers 2>/dev/null | wc -l)

if [ "$RUNNING_PODS" -gt 0 ] && [ "$TOTAL_PODS" -gt 0 ]; then
    print_success "ARC Controller is running ($RUNNING_PODS/$TOTAL_PODS pods running)"
    
    # Show pod details
    echo "Pod details:"
    kubectl get pods -n actions-runner-system
else
    if [ "$TOTAL_PODS" -gt 0 ]; then
        print_warning "ARC pods exist but not all are running ($RUNNING_PODS/$TOTAL_PODS)"
        kubectl get pods -n actions-runner-system
    else
        print_status 1 "No ARC Controller pods found"
    fi
fi

# Check available Custom Resource Definitions
print_info "Checking available ARC Custom Resources..."
ARC_CRDS=$(kubectl api-resources 2>/dev/null | grep -E "(actions\.github\.com|actions\.summerwind\.dev)" | wc -l)
if [ "$ARC_CRDS" -gt 0 ]; then
    print_success "ARC Custom Resource Definitions are installed ($ARC_CRDS CRDs)"
    echo "Available ARC resources:"
    kubectl api-resources 2>/dev/null | grep -E "(actions\.github\.com|actions\.summerwind\.dev)" || echo "None found"
else
    print_warning "No ARC Custom Resource Definitions found"
fi

# Check for runner scale sets with multiple possible resource names
print_info "Checking Runner Scale Sets..."
SCALE_SETS_FOUND=0

# Try AutoscalingRunnerSet
if kubectl get autoscalingrunnerset -n actions-runner-system --no-headers > /dev/null 2>&1; then
    ARS_COUNT=$(kubectl get autoscalingrunnerset -n actions-runner-system --no-headers 2>/dev/null | wc -l)
    if [ "$ARS_COUNT" -gt 0 ]; then
        print_success "AutoscalingRunnerSet found ($ARS_COUNT sets)"
        kubectl get autoscalingrunnerset -n actions-runner-system
        SCALE_SETS_FOUND=1
    fi
fi

# Try EphemeralRunnerSet
if kubectl get ephemeralrunnerset -n actions-runner-system --no-headers > /dev/null 2>&1; then
    ERS_COUNT=$(kubectl get ephemeralrunnerset -n actions-runner-system --no-headers 2>/dev/null | wc -l)
    if [ "$ERS_COUNT" -gt 0 ]; then
        print_success "EphemeralRunnerSet found ($ERS_COUNT sets)"
        kubectl get ephemeralrunnerset -n actions-runner-system
        SCALE_SETS_FOUND=1
    fi
fi

# Try legacy RunnerScaleSet
if kubectl get runnerscalesets -n actions-runner-system --no-headers > /dev/null 2>&1; then
    RSS_COUNT=$(kubectl get runnerscalesets -n actions-runner-system --no-headers 2>/dev/null | wc -l)
    if [ "$RSS_COUNT" -gt 0 ]; then
        print_success "RunnerScaleSet found ($RSS_COUNT sets)"
        kubectl get runnerscalesets -n actions-runner-system
        SCALE_SETS_FOUND=1
    fi
fi

if [ "$SCALE_SETS_FOUND" -eq 0 ]; then
    print_warning "No Runner Scale Sets found - this might be normal if none are configured yet"
fi

# Check node architecture
print_info "Checking cluster architecture..."
ARM_NODES=$(kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.architecture}' 2>/dev/null | grep -o "arm64" | wc -l)
TOTAL_NODES=$(kubectl get nodes --no-headers 2>/dev/null | wc -l)

if [ "$ARM_NODES" -gt 0 ]; then
    print_success "ARM64 nodes detected ($ARM_NODES/$TOTAL_NODES nodes)"
else
    print_warning "No ARM64 nodes detected - runners may not schedule properly"
fi

# Check if Container runtime is available
print_info "Checking container runtime..."
if kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.containerRuntimeVersion}' 2>/dev/null | grep -q "containerd\|docker\|cri-o"; then
    print_success "Container runtime is available"
else
    print_warning "Container runtime status unclear"
fi

# Show all resources in the namespace
print_info "All resources in actions-runner-system namespace:"
kubectl get all -n actions-runner-system 2>/dev/null || echo "No resources found"

# Show recent events
print_info "Recent events in actions-runner-system namespace:"
kubectl get events -n actions-runner-system --sort-by='.lastTimestamp' 2>/dev/null | tail -5 || echo "No events found"

echo ""
print_success "Setup verification completed!"

# Instructions for next steps
echo ""
echo "🚀 Next Steps:"
echo "1. If no Runner Scale Sets are found, check the deployment logs"
echo "2. To test your runners, create a workflow with: runs-on: [self-hosted, linux, ARM64]"
echo "3. Check GitHub repository settings for registered runners"

echo ""
echo "📋 Test your setup with a simple workflow:"
echo "   runs-on: [self-hosted, linux, ARM64]"
