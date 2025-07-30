#!/bin/bash
# Alternative deployment with JSON values

RUNNER_LABELS='["self-hosted","linux","ARM64","arm64-runners"]'

helm upgrade --install org-arm64-runners \
  --namespace actions-runner-system \
  --create-namespace \
  --values ./helm/values/organization-runners.yaml \
  --set-string githubConfigSecret.github_token="$TOKEN" \
  --set-string githubConfigUrl="$CONFIG_URL" \
  --set maxRunners=5 \
  --set minRunners=1 \
  --set-json runnerLabels="$RUNNER_LABELS" \
  --wait \
  --timeout=10m \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set
