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
#
# 2026-10-01: CI-Fallback. Die CI-Workflows aller Repos laufen jetzt ueber
# select-runner und landen bei Minutenmangel hier. Im upstream-Image fehlen
# dafuer node (Lint-Skripte), pip3, zip; setup-dotnet installiert per Default
# nach /usr/share/dotnet, das der Nicht-root-User runner nicht anlegen darf
# (Test-Run weatherstation 36873608126: "mkdir: Permission denied").
# DOTNET_INSTALL_DIR lenkt setup-dotnet in ein beschreibbares Verzeichnis.
#
# 2026-10-03: g++. HoneyPal baut Firmware-Host-Tests (tests/firmware-host) nativ und unter
# ASan/UBSan; auf diesem Runner fehlte ein C++-Compiler ("c++: command not found",
# HoneyPal PR #198), und sudo ist auch hier gesperrt. g++ zieht libasan/libubsan ueber
# libgcc-*-dev mit. Ohne das Paket faellt HoneyPal auf zig zurueck, dann ohne Sanitizer.
FROM ghcr.io/actions/actions-runner:latest@sha256:e5496277be5d09bc968b3d64911b74e219ac4a3f2edce956a3ecf9271bea1ef4

USER root
RUN apt-get update \
 && apt-get install -y --no-install-recommends gettext-base python3-pip zip xz-utils g++ \
 && rm -rf /var/lib/apt/lists/*

# Node aus dem offiziellen Tarball statt Ubuntu-nodejs: das apt-Paket ist v18
# und bringt kein npm mit (weatherstation-Build ruft ueber das JavaScript-SDK
# `npm install` auf -> "npm: not found", Run 36878169719). Gepinnt + sha256.
ARG NODE_VERSION=v22.23.3
ARG NODE_SHA256=a44aeb94849a299b22df10b9e622ec2f605c2183501bc40590705131de7c740f
RUN curl -fsSLo /tmp/node.tar.xz "https://nodejs.org/dist/${NODE_VERSION}/node-${NODE_VERSION}-linux-arm64.tar.xz" \
 && echo "${NODE_SHA256}  /tmp/node.tar.xz" | sha256sum -c - \
 && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
      --exclude CHANGELOG.md --exclude LICENSE --exclude README.md \
 && rm /tmp/node.tar.xz \
 && node --version && npm --version \
 && g++ --version | head -1
USER runner
ENV DOTNET_INSTALL_DIR=/home/runner/.dotnet
