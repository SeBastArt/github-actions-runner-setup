# Personal Access Token Setup für Self-Hosted Runners

Da du einen GitHub Free Plan ohne Organisation verwendest, ist der Personal Access Token (PAT) Ansatz der richtige Weg.

## 1. Personal Access Token erstellen

### Schritt 1: Token generieren

1. Gehe zu **GitHub Settings** → **Developer settings** → **Personal access tokens** → **Tokens (classic)**
2. Klicke auf **Generate new token** → **Generate new token (classic)**
3. Konfiguriere den Token:

**Token Name**: `ARM64-Self-Hosted-Runners`
**Expiration**: `90 days` (oder custom)

**Scopes** (wichtig für private Repos):
```
✅ repo (Full control of private repositories)
  ✅ repo:status
  ✅ repo_deployment  
  ✅ public_repo
  ✅ repo:invite
  ✅ security_events

✅ workflow (Update GitHub Action workflows)

✅ admin:repo_hook (Full control of repository hooks)
  ✅ write:repo_hook
  ✅ read:repo_hook
```

### Schritt 2: Token sichern
⚠️ **Wichtig**: Kopiere den Token sofort - du siehst ihn nur einmal!

## 2. Repository Secrets konfigurieren

In deinem **öffentlichen** runner-deployment Repository:

### Secrets hinzufügen

1. Gehe zu **Settings** → **Secrets and variables** → **Actions**
2. Klicke **New repository secret**

**Benötigte Secrets:**

```bash
# GitHub Authentication
TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
CONFIG_URL=https://github.com/dein-username

# Kubernetes Cluster Access  
KUBECONFIG=<base64-encoded-kubeconfig>
```

### KUBECONFIG vorbereiten

Auf deinem lokalen Rechner mit Cluster-Zugriff:

```bash
# Kubeconfig base64 kodieren
cat ~/.kube/config | base64 -w 0

# Oder für Windows:
certutil -encode ~/.kube/config temp.b64 && type temp.b64 | findstr /v "CERTIFICATE" && del temp.b64
```

## 3. Repository-spezifische vs. User-weite Runner

Du hast zwei Optionen für die `GITHUB_CONFIG_URL`:

### Option A: User-weite Runner (Empfohlen)
```bash
CONFIG_URL=https://github.com/dein-username
```
- Runner sind für **alle** deine Repositories verfügbar
- Einfacher zu verwalten
- Ein Setup für alle privaten Repos

### Option B: Repository-spezifische Runner
```bash  
CONFIG_URL=https://github.com/dein-username/weatherstation
```
- Runner nur für ein spezifisches Repository
- Mehr Sicherheit, aber mehr Aufwand
- Separates Setup pro Repo nötig

**Für dich ist Option A besser**, da du mehrere private Repos hast!

## 4. Test der Konfiguration

Nach dem Deployment kannst du testen:

### In einem privaten Repository:

```yaml
name: Test ARM64 Runner
on: workflow_dispatch

jobs:
  test:
    runs-on: [self-hosted, linux, ARM64, arm64-runners]
    steps:
      - name: Test
        run: |
          echo "Running on: $(uname -m)"
          echo "Node: $(hostname)"
```

## 5. Wichtige Unterschiede zu GitHub App

### PAT Vorteile:
- ✅ Einfacher Setup (kein App erstellen)
- ✅ Funktioniert mit persönlichen Repositories
- ✅ Keine komplexe Konfiguration

### PAT Nachteile:
- ❌ Token läuft ab (muss erneuert werden)
- ❌ Weniger granulare Berechtigungen
- ❌ An deinen persönlichen Account gebunden

## 6. Token-Rotation

Da PATs ablaufen, solltest du:

1. **Kalender-Erinnerung** setzen (z.B. alle 60 Tage)
2. **Neuen Token** mit gleichen Scopes erstellen
3. **Repository Secret** aktualisieren
4. **Alten Token** löschen

## 7. Sicherheits-Tipps

### DO:
- ✅ Minimale nötige Scopes vergeben
- ✅ Kurze Ablaufzeiten (90 Tage max)
- ✅ Regelmäßige Token-Rotation
- ✅ Token in Secrets speichern (nie im Code!)

### DON'T:
- ❌ Token in Logs ausgeben
- ❌ Token mit anderen teilen
- ❌ Unnötige Scopes vergeben
- ❌ Token in public Repositories committen

## 8. Troubleshooting

### "Bad credentials" Fehler:
```bash
# Token prüfen (ersetze mit deinem echten Token)
curl -H "Authorization: token ghp_..." https://api.github.com/repos/dein-username/github-actions-runner-setup
```

### Runner erscheint nicht:
```bash
# In deinem öffentlichen Repo die Logs prüfen:
kubectl logs -n actions-runner-system -l app=github-runner
```

### Permission denied:
- Prüfe Token Scopes
- Prüfe ob Token noch gültig ist
- Prüfe CONFIG_URL

## 9. Monitoring

Du kannst den Runner-Status überwachen:

```bash
# Runner Status
kubectl get runners -n actions-runner-system

# Runner Logs  
kubectl logs -n actions-runner-system -l app=github-runner -f

# GitHub Settings
# Gehe zu Settings → Actions → Runners in deinen Repos
```

Das Setup ist jetzt bereit für deinen Personal Access Token Ansatz! 🚀
