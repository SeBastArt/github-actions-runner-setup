# Eigenes Runner-Image: upstream actions-runner + gettext-base (envsubst).
#
# WARUM: sigstore/cosign-installer v4 ruft `envsubst` auf, das im upstream
# ghcr.io/actions/actions-runner-Image fehlt -> sign-Job exit 127 ->
# unsignierte Images (Vorfall 2026-07-02, WeLink-Run 28611664582). Upstream
# offen (cosign-installer #222, Fix-PR #236 unmerged), sudo im Runner-Pod ist
# durch allowPrivilegeEscalation:false blockiert -> Install zur Laufzeit
# unmoeglich. Deshalb backen wir envsubst ins Image.
#
# Base-Digest = derselbe Pin wie zuvor direkt in values/{base,production}.yaml
# (Tag-Mover-Schutz, s. Kommentar dort). Beim Upstream-Digest-Bump: hier
# aktualisieren, Workflow build-runner-image.yaml dispatchen, neuen eigenen
# Digest in values/ pinnen, deploy-runners.yml dispatchen.
FROM ghcr.io/actions/actions-runner:latest@sha256:0cfdcc701ce933c6d243c6b0b2da767366dc9f2e99961d4c3754b0b78084cdda

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends gettext-base \
 && rm -rf /var/lib/apt/lists/*
USER runner
