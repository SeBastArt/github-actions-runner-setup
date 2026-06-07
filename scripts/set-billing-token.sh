#!/usr/bin/env bash
# set-billing-token.sh — set/rotate the GH_BILLING_TOKEN secret across all
# build-capable wondering-developer repos in one command.
#
# WHY a per-repo loop instead of ONE organization secret:
#   The wondering-developer org is on the GitHub *Free* plan and the repos are
#   PRIVATE. GitHub does NOT make organization-level secrets/variables available
#   to private repos on Free — they only reach public repos there. So an org
#   secret silently resolves to empty in these workflows (select-runner then logs
#   "No gh-billing-token" and falls back to self-hosted). A real org secret would
#   require upgrading to GitHub Team/Enterprise. Until then, this script keeps the
#   per-repo secrets in sync from a single place.
#
# The token is a fine-grained PAT (resource owner = the org) with
#   Organization permissions -> Administration: Read-only
# which is what the enhanced billing usage API requires.
#
# Usage:
#   scripts/set-billing-token.sh <new-pat>
#   scripts/set-billing-token.sh            # reads the token from stdin (hidden)
set -euo pipefail

ORG="wondering-developer"
REPOS=(weRead WeTrade HoneyPal adoryn weatherstation WePlan)

TOKEN="${1:-}"
if [ -z "$TOKEN" ]; then
  read -rsp "Paste GH_BILLING_TOKEN (input hidden): " TOKEN
  echo
fi
[ -n "$TOKEN" ] || { echo "ERROR: empty token" >&2; exit 1; }

for r in "${REPOS[@]}"; do
  printf '%s' "$TOKEN" | gh secret set GH_BILLING_TOKEN --repo "${ORG}/${r}"
  echo "✓ ${ORG}/${r}"
done
echo "Done. Set GH_BILLING_TOKEN on ${#REPOS[@]} repos."
