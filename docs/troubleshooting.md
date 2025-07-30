# Troubleshooting Guide

## Häufige Probleme und Lösungen

### 1. Runner erscheinen nicht in GitHub

**Symptome:**
- Deployment erfolgreich, aber keine Runner in GitHub Settings sichtbar
- Jobs bleiben in der Queue hängen

**Mögliche Ursachen & Lösungen:**

```bash
# 1. Prüfe Controller Status
kubectl get pods -n actions-runner-system
kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller

# 2. Prüfe GitHub Token (ersetze mit deinem echten Token)
curl -H "Authorization: token ghp_..." https://api.github.com/user

# 3. Prüfe Runner Scale Set
kubectl get runnerscalesets -n actions-runner-system
kubectl describe runnerscalesets -n actions-runner-system
```

**Häufige Fixes:**
- Token abgelaufen → Neuen PAT erstellen
- Falsche CONFIG_URL → Prüfe URL Format
- Fehlende Permissions → Prüfe Token Scopes

### 2. Authentication Fehler

**Fehler:**
```
Error: Bad credentials
```

**Lösung:**
```bash
# 1. Token testen (ersetze mit deinem echten Token)
curl -H "Authorization: token ghp_..." https://api.github.com/user

# 2. Token Scopes prüfen
curl -H "Authorization: token ghp_..." https://api.github.com/user/repos

# 3. Secret prüfen (im GitHub Repo)
# Settings → Secrets → TOKEN sollte korrekt sein
```

### 3. Pods starten nicht

**Symptome:**
- Runner Pods bleiben in "Pending" oder "ImagePullBackOff"

**Debug Commands:**
```bash
# Pod Status prüfen
kubectl get pods -n actions-runner-system
kubectl describe pod <pod-name> -n actions-runner-system

# Events prüfen
kubectl get events -n actions-runner-system --sort-by='.lastTimestamp'
```

**Häufige Ursachen:**
- **ARM64 Image nicht verfügbar:** Prüfe ob Runner Image ARM64 unterstützt
- **Resource Limits:** Node hat nicht genug CPU/Memory
- **Node Selector:** Kein ARM64 Node verfügbar

**Lösungen:**
```bash
# 1. Node Architecture prüfen
kubectl get nodes -o jsonpath='{.items[*].status.nodeInfo.architecture}'

# 2. Node Resources prüfen  
kubectl describe nodes
kubectl top nodes

# 3. Runner Image prüfen
docker manifest inspect ghcr.io/actions/actions-runner:latest
```

### 4. Docker-in-Docker Probleme

**Fehler:**
```
Cannot connect to the Docker daemon at unix:///var/run/docker.sock
```

**Lösung:**
```bash
# 1. Docker Socket verfügbar?
kubectl exec -it <runner-pod> -n actions-runner-system -- ls -la /var/run/docker.sock

# 2. Permissions prüfen
kubectl exec -it <runner-pod> -n actions-runner-system -- docker ps

# 3. Alternative: Docker-in-Docker Container
# Siehe base-values.yaml für DinD Setup
```

### 5. Network Connectivity Issues

**Symptome:**
- Workflows können nicht auf Internet zugreifen
- Docker pulls schlagen fehl

**Debug:**
```bash
# 1. Connectivity von Pod testen
kubectl run debug-pod --image=alpine -it --rm -- /bin/sh
# Im Pod: ping 8.8.8.8, nslookup github.com

# 2. DNS prüfen
kubectl exec -it <runner-pod> -n actions-runner-system -- nslookup github.com

# 3. Network Policies prüfen
kubectl get networkpolicies -n actions-runner-system
```

### 6. Resource Quotas/Limits

**Fehler:**
```
pods "runner-xyz" is forbidden: exceeded quota
```

**Lösung:**
```bash
# 1. Quota prüfen
kubectl describe quota -n actions-runner-system

# 2. Resource Usage prüfen
kubectl top pods -n actions-runner-system

# 3. Limits in values.yaml anpassen
# Reduziere resources.requests/limits
```

### 7. Helm Deployment Fehler

**Fehler:**
```
Error: failed to create resource: the server could not find the requested resource
```

**Lösung:**
```bash
# 1. CRDs installiert?
kubectl get crd | grep actions

# 2. ARC Controller erst installieren
helm upgrade --install arc actions-runner-controller/actions-runner-controller

# 3. Dann Runner Scale Set
helm upgrade --install github-runners actions-runner-controller/gha-runner-scale-set
```

### 8. Jobs bleiben in Queue

**Symptome:**
- Workflow startet nicht
- "Waiting for a runner to pick up this job"

**Mögliche Ursachen:**
```bash
# 1. Runner Labels stimmen nicht überein
# In Workflow: runs-on: [self-hosted, linux, ARM64, arm64-runners]
# Müssen mit runnerLabels in values.yaml übereinstimmen

# 2. Keine verfügbaren Runner
kubectl get runnerscalesets -n actions-runner-system
kubectl get runners -n actions-runner-system

# 3. Runner Scale Set Limits
# Prüfe maxRunners in values.yaml
```

### 9. Cleanup nach Fehlern

**Kompletter Neustart:**
```bash
# 1. Cleanup Script ausführen
./scripts/cleanup.sh

# 2. Namespace manuell löschen (falls hängen bleibt)
kubectl delete namespace actions-runner-system --force --grace-period=0

# 3. CRDs löschen (vorsichtig!)
kubectl get crd | grep actions | awk '{print $1}' | xargs kubectl delete crd

# 4. Neu deployen
# Führe deploy-runners.yml Workflow aus
```

## Debug Commands Cheat Sheet

```bash
# Cluster Status
kubectl cluster-info
kubectl get nodes -o wide

# Namespace Status
kubectl get all -n actions-runner-system

# Controller Logs
kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller -f

# Runner Logs
kubectl logs -n actions-runner-system -l app=github-runner -f

# Events
kubectl get events -n actions-runner-system --sort-by='.lastTimestamp'

# Resource Usage
kubectl top nodes
kubectl top pods -n actions-runner-system

# Custom Resources
kubectl get runnerscalesets -n actions-runner-system -o yaml
kubectl describe runnerscalesets -n actions-runner-system
kubectl get runners -n actions-runner-system -o yaml
kubectl describe runners -n actions-runner-system

# Helm Status
helm list -n actions-runner-system
helm status arc -n actions-runner-system
helm status github-runners -n actions-runner-system
```

## Performance Tuning

### Für bessere Performance:

```yaml
# In production.yaml
template:
  spec:
    containers:
    - name: runner
      resources:
        requests:
          cpu: "1000m"      # Mehr CPU
          memory: "2Gi"     # Mehr Memory
        limits:
          cpu: "4000m"
          memory: "8Gi"

# Mehr parallele Runner
maxRunners: 10
minRunners: 2

# Schnelleres Scaling
scaleDownDelaySecondsAfterScaleOut: 120
```

### Für ARM64 spezifische Optimierungen:

```yaml
# Native ARM64 builds nutzen
template:
  spec:
    containers:
    - name: runner
      env:
      - name: DOCKER_BUILDKIT
        value: "1"
      - name: BUILDX_EXPERIMENTAL  
        value: "1"
```

## Support

Wenn alle Troubleshooting-Schritte fehlschlagen:

1. **GitHub Issues:** https://github.com/actions/actions-runner-controller/issues
2. **Kubernetes Events:** `kubectl get events --all-namespaces`
3. **System Logs:** Prüfe Node-Logs auf dem ARM64 Cluster
4. **GitHub Status:** https://www.githubstatus.com/

## Logging Level erhöhen

Für detaillierteres Debugging:

```yaml
# In base-values.yaml
log:
  level: debug  # statt info
  format: json  # für strukturierte Logs
```

Dann neu deployen und Logs prüfen:
```bash
kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller -f
```
