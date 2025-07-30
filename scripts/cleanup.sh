#!/bin/bash

# GitHub Actions Runner Cleanup Script
# This script removes the GitHub Actions Runner Controller and all related resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NAMESPACE="actions-runner-system"
ARC_RELEASE_NAME="arc"
RUNNERS_RELEASE_NAME="github-runners"

print_header() {
    echo -e "${BLUE}🧹 $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

confirm_action() {
    echo -e "${YELLOW}This will remove ALL GitHub Actions Runners and the controller from your cluster.${NC}"
    echo -e "${YELLOW}This action cannot be undone!${NC}"
    echo ""
    read -p "Are you sure you want to continue? (type 'yes' to confirm): " -r
    if [[ ! $REPLY =~ ^yes$ ]]; then
        echo "Cleanup cancelled."
        exit 0
    fi
}

check_prerequisites() {
    print_header "Checking prerequisites..."
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed or not in PATH"
        exit 1
    fi
    
    # Check cluster access
    if ! kubectl cluster-info > /dev/null 2>&1; then
        print_error "Cannot access Kubernetes cluster"
        exit 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        print_error "helm is not installed or not in PATH"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

stop_runners() {
    print_header "Stopping active runners..."
    
    # Scale down runner deployments
    if kubectl get deployment -n $NAMESPACE > /dev/null 2>&1; then
        kubectl get deployments -n $NAMESPACE -o name | while read deployment; do
            print_warning "Scaling down $deployment"
            kubectl scale $deployment --replicas=0 -n $NAMESPACE || true
        done
    fi
    
    # Wait for pods to terminate
    print_warning "Waiting for runner pods to terminate..."
    kubectl wait --for=delete pods --all -n $NAMESPACE --timeout=120s || true
    
    print_success "Active runners stopped"
}

remove_helm_releases() {
    print_header "Removing Helm releases..."
    
    # Remove runner scale set
    if helm list -n $NAMESPACE | grep -q $RUNNERS_RELEASE_NAME; then
        print_warning "Removing $RUNNERS_RELEASE_NAME release..."
        helm uninstall $RUNNERS_RELEASE_NAME -n $NAMESPACE || print_error "Failed to remove $RUNNERS_RELEASE_NAME"
    else
        print_warning "$RUNNERS_RELEASE_NAME release not found"
    fi
    
    # Remove ARC controller
    if helm list -n $NAMESPACE | grep -q $ARC_RELEASE_NAME; then
        print_warning "Removing $ARC_RELEASE_NAME release..."
        helm uninstall $ARC_RELEASE_NAME -n $NAMESPACE || print_error "Failed to remove $ARC_RELEASE_NAME"
    else
        print_warning "$ARC_RELEASE_NAME release not found"
    fi
    
    print_success "Helm releases removed"
}

remove_custom_resources() {
    print_header "Removing custom resources..."
    
    # Remove runners
    if kubectl get runners -n $NAMESPACE > /dev/null 2>&1; then
        kubectl delete runners --all -n $NAMESPACE || true
    fi
    
    # Remove horizontal runner autoscalers
    if kubectl get hra -n $NAMESPACE > /dev/null 2>&1; then
        kubectl delete hra --all -n $NAMESPACE || true
    fi
    
    # Remove runner deployments
    if kubectl get runnerdeployments -n $NAMESPACE > /dev/null 2>&1; then
        kubectl delete runnerdeployments --all -n $NAMESPACE || true
    fi
    
    # Remove runner replica sets
    if kubectl get runnerreplicasets -n $NAMESPACE > /dev/null 2>&1; then
        kubectl delete runnerreplicasets --all -n $NAMESPACE || true
    fi
    
    print_success "Custom resources removed"
}

remove_secrets_and_configs() {
    print_header "Removing secrets and configurations..."
    
    # Remove secrets
    kubectl delete secrets --all -n $NAMESPACE || true
    
    # Remove configmaps
    kubectl delete configmaps --all -n $NAMESPACE || true
    
    print_success "Secrets and configurations removed"
}

remove_rbac() {
    print_header "Removing RBAC resources..."
    
    # Remove service accounts
    kubectl delete serviceaccounts --all -n $NAMESPACE || true
    
    # Remove cluster role bindings (be careful with names)
    kubectl get clusterrolebindings -o name | grep -E "(actions-runner|github-runner)" | xargs -r kubectl delete || true
    
    # Remove cluster roles (be careful with names)  
    kubectl get clusterroles -o name | grep -E "(actions-runner|github-runner)" | xargs -r kubectl delete || true
    
    # Remove role bindings
    kubectl delete rolebindings --all -n $NAMESPACE || true
    
    # Remove roles
    kubectl delete roles --all -n $NAMESPACE || true
    
    print_success "RBAC resources removed"
}

remove_webhooks() {
    print_header "Removing webhooks..."
    
    # Remove mutating webhook configurations
    kubectl get mutatingwebhookconfigurations -o name | grep -E "(actions-runner|github-runner)" | xargs -r kubectl delete || true
    
    # Remove validating webhook configurations
    kubectl get validatingwebhookconfigurations -o name | grep -E "(actions-runner|github-runner)" | xargs -r kubectl delete || true
    
    print_success "Webhooks removed"
}

remove_crds() {
    print_header "Removing Custom Resource Definitions..."
    
    print_warning "Removing CRDs will affect ALL ARC installations in the cluster!"
    read -p "Do you want to remove CRDs? This affects other ARC installations too! (y/N): " -r
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Remove ARC CRDs
        kubectl get crd -o name | grep -E "(actions\.summerwind\.dev|actions\.github\.com)" | xargs -r kubectl delete || true
        print_success "CRDs removed"
    else
        print_warning "CRDs left in place"
    fi
}

remove_namespace() {
    print_header "Removing namespace..."
    
    if kubectl get namespace $NAMESPACE > /dev/null 2>&1; then
        print_warning "Removing namespace $NAMESPACE..."
        kubectl delete namespace $NAMESPACE --timeout=120s || print_error "Failed to remove namespace"
        print_success "Namespace removed"
    else
        print_warning "Namespace $NAMESPACE not found"
    fi
}

cleanup_helm_repos() {
    print_header "Cleaning up Helm repositories..."
    
    # Remove ARC helm repo (optional)
    read -p "Do you want to remove the actions-runner-controller Helm repository? (y/N): " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        helm repo remove actions-runner-controller || print_warning "Repository not found"
        print_success "Helm repository removed"
    else
        print_warning "Helm repository left in place"
    fi
}

verify_cleanup() {
    print_header "Verifying cleanup..."
    
    # Check namespace
    if kubectl get namespace $NAMESPACE > /dev/null 2>&1; then
        print_error "Namespace $NAMESPACE still exists"
    else
        print_success "Namespace removed"
    fi
    
    # Check helm releases
    if helm list --all-namespaces | grep -E "(arc|github-runner)"; then
        print_error "Some Helm releases still exist"
    else
        print_success "All Helm releases removed"
    fi
    
    # Check for remaining pods
    REMAINING_PODS=$(kubectl get pods --all-namespaces | grep -E "(runner|actions)" | wc -l || echo "0")
    if [ "$REMAINING_PODS" -gt 0 ]; then
        print_warning "$REMAINING_PODS runner-related pods still exist"
        kubectl get pods --all-namespaces | grep -E "(runner|actions)"
    else
        print_success "No runner pods remaining"
    fi
}

main() {
    echo -e "${BLUE}GitHub Actions Runner Cleanup Script${NC}"
    echo "===================================="
    echo ""
    
    confirm_action
    echo ""
    
    check_prerequisites
    echo ""
    
    stop_runners
    echo ""
    
    remove_helm_releases
    echo ""
    
    remove_custom_resources
    echo ""
    
    remove_secrets_and_configs
    echo ""
    
    remove_rbac
    echo ""
    
    remove_webhooks
    echo ""
    
    remove_crds
    echo ""
    
    remove_namespace
    echo ""
    
    cleanup_helm_repos
    echo ""
    
    verify_cleanup
    echo ""
    
    print_success "Cleanup completed!"
    echo ""
    echo "Next steps:"
    echo "1. If you want to redeploy, run the deployment workflow again"
    echo "2. Check your GitHub repository settings to remove any stale runners"
    echo "3. Update your private repositories to use GitHub-hosted runners temporarily"
}

# Handle script interruption
trap 'echo -e "\n${RED}Cleanup interrupted!${NC}"; exit 1' INT TERM

# Run main function
main "$@"
