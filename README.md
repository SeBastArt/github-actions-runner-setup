# GitHub Actions Runner Setup for ARM64 Kubernetes

This repository contains the setup for deploying **GitHub's official Actions Runner Controller (ARC)** on ARM64 Kubernetes clusters using the new OCI registry charts.

## Architecture

```
GitHub → Personal Access Token → ARC Controller → ARM64 Runner Pods
```

## Features

- ✅ ARM64 native builds (no QEMU needed)
- ✅ Auto-scaling runners
- ✅ Ephemeral security (runners destroyed after each job)
- ✅ Infrastructure as Code with Helm
- ✅ Support for private repositories
- ✅ **ARC v0.12+ Compatible** (installation name targeting)

## Quick Start

1. Create Personal Access Token (see [docs/pat-setup.md](./docs/pat-setup.md))
2. Configure repository secrets: TOKEN, CONFIG_URL, KUBECONFIG
3. Run the deployment workflow
4. Test with a private repository using `runs-on: arm64-runners`

## **CRITICAL: ARC v0.12+ Breaking Changes**

**⚠️ IMPORTANT**: ARC v0.12+ does **NOT** support custom `runnerLabels`. 

### ❌ OLD Syntax (WILL NOT WORK):
```yaml
jobs:
  build:
    runs-on: [self-hosted, linux, ARM64, arm64-runners]
```

### ✅ NEW Syntax (ARC v0.12+ ONLY):
```yaml
jobs:
  build:
    runs-on: arm64-runners  # Use installation name directly
```

**Why**: GitHub removed custom labels support in ARC v0.12+. Runners are now targeted by **installation name only**. Automatic labels (self-hosted, linux, ARM64) are still applied based on runtime detection.

## Security Model

- This public repository contains NO cluster secrets
- Cluster access is configured via repository secrets (KUBECONFIG, TOKEN, CONFIG_URL)
- All sensitive data is base64-encoded and stored in GitHub Secrets

## Repository Structure

```
├── .github/workflows/
│   ├── deploy-runners.yml        # Main deployment workflow
│   └── test-runners.yml          # Test the runner setup
├── helm/
│   └── values/
│       ├── base-values.yaml      # Base ARC configuration
│       └── production.yaml       # Production overrides
├── docs/
│   ├── github-app-setup.md       # GitHub App creation guide
│   ├── cluster-setup.md          # Kubernetes preparation
│   └── troubleshooting.md        # Common issues
└── scripts/
    ├── verify-setup.sh           # Setup verification
    └── cleanup.sh                # Cleanup script
```
