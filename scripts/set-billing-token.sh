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
# WHERE the BWS access token itself lives: als Login/Secure-Note im Bitwarden
# PASSWORD MANAGER (normaler Tresor, Eintrag "BWS Access Token ci-github") —
# NICHT im Secrets Manager, dessen Zugang er ja gerade aufschliesst. Er ist
# ausserdem jederzeit regenerierbar: Secrets Manager -> Maschinenkonten ->
# ci-github-Konto -> neuen Access-Token erzeugen, dann dieses Script einmal
# laufen lassen (alte Tokens dabei im Maschinenkonto widerrufen).
#
# Usage:
#   scripts/set-billing-token.sh <bws-access-token>
#   scripts/set-billing-token.sh            # reads the token from stdin (hidden)
set -euo pipefail

ORG="wondering-developer"
# 2026-07-02: WeLink ergaenzt — hatte das Secret nur manuell gesetzt und waere
# bei der naechsten Rotation still uebersprungen worden (Fallback = in-cluster-
# Builds, s. build-image.yaml select-runner). HoneyPal fehlte das Secret am
# 2026-07-02 komplett (einziges Repo mit in-cluster-Builds); nach Neu-Setzen
# per Re-Run verifiziert: build-Jobs wieder auf ubuntu-24.04-arm.
REPOS=(weRead WeTrade HoneyPal adoryn weatherstation WePlan WeLink)

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
