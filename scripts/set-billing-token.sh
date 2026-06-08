#!/usr/bin/env bash
# set-billing-token.sh — set/rotate the GH_BILLING_TOKEN secret across all
# build-capable wondering-developer repos in one command.
#
# WHAT this secret now holds: a Bitwarden Secrets Manager MACHINE-ACCOUNT ACCESS
# TOKEN (read-only, scoped to a project that contains only the billing PAT).
# At build time, build-image.yaml's select-runner uses it with bitwarden/sm-action
# to fetch the actual GitHub billing PAT from Bitwarden.
#
# WHY per-repo (not one org secret): GitHub Free does not expose org secrets to
# PRIVATE repos, so a single org secret can't work. The BWS access token is static
# (set once per repo); the PAT that actually expires lives ONLY in Bitwarden, so
# rotating the PAT is a Bitwarden-only change — you do NOT run this script for that.
#
# Run this script only to set up a new repo or rotate the BWS access token itself.
#
# Usage:
#   scripts/set-billing-token.sh <bws-access-token>
#   scripts/set-billing-token.sh            # reads the token from stdin (hidden)
set -euo pipefail

ORG="wondering-developer"
REPOS=(weRead WeTrade HoneyPal adoryn weatherstation WePlan)

TOKEN="${1:-}"
if [ -z "$TOKEN" ]; then
  read -rsp "Paste the Bitwarden SM access token (input hidden): " TOKEN
  echo
fi
[ -n "$TOKEN" ] || { echo "ERROR: empty token" >&2; exit 1; }

for r in "${REPOS[@]}"; do
  printf '%s' "$TOKEN" | gh secret set GH_BILLING_TOKEN --repo "${ORG}/${r}"
  echo "✓ ${ORG}/${r}"
done
echo "Done. Set GH_BILLING_TOKEN (BWS access token) on ${#REPOS[@]} repos."
