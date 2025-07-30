#!/bin/bash
# Minimale ARC Installation ohne cert-manager

# Namespace erstellen
kubectl create namespace actions-runner-system --dry-run=client -o yaml | kubectl apply -f -

# Einfache ARC Installation mit kubectl
kubectl apply -f https://github.com/actions/actions-runner-controller/releases/download/v0.27.4/actions-runner-controller.yaml

echo "ARC Controller installed without cert-manager dependencies"
