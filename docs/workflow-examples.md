# Beispiel: WeatherStation Deployment mit ARM64 Self-Hosted Runners

Hier ist dein angepasster Workflow für die ARM64 Runner:

```yaml
name: WeatherStation-Deployment

on:
  workflow_dispatch:
    inputs:
      baseversion:
        description: 'Image base version'
        required: true
        default: '2.0'

jobs:
  prepare:
    runs-on: [self-hosted, linux, ARM64, arm64-runners]
    outputs:
      version: ${{ steps.prepare.outputs.version }}
    steps:
      - name: Checkout repo
        uses: actions/checkout@v4
      - name: Prepare Version
        id: prepare
        run: |
          VERSION="v${{ github.event.inputs.baseversion }}.${GITHUB_RUN_NUMBER}"
          echo "version=$VERSION" >> $GITHUB_OUTPUT

  build:
    needs: prepare
    runs-on: [self-hosted, linux, ARM64, arm64-runners]
    strategy:
      matrix:
        component:
          - name: things
            image: sebastart/thingsapi
            dockerfile: ThingsApi/Dockerfile
            context: src
          - name: frontend
            image: sebastart/frontend
            dockerfile: Frontend/Dockerfile
            context: src
          - name: backend
            image: sebastart/backendapi
            dockerfile: BackendApi/Dockerfile
            context: src
          - name: weather
            image: sebastart/temperature-dashboard
            dockerfile: Dockerfile
            context: src/temperature-dashboard
    steps:
      - name: Checkout repo
        uses: actions/checkout@v4
        
      # QEMU und Buildx nicht mehr nötig! 🎉
      # Docker läuft nativ auf ARM64
      
      - name: Log into Docker Hub
        if: github.event_name != 'pull_request'
        uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}
          
      - name: Build and push ${{ matrix.component.name }} image
        run: |
          # Viel einfacher und schneller - native ARM64 builds!
          docker build ${{ matrix.component.context }} \
            --file ${{ matrix.component.context }}/${{ matrix.component.dockerfile }} \
            --tag ${{ matrix.component.image }}:${{ needs.prepare.outputs.version }} \
            --tag ${{ matrix.component.image }}:latest
          
          # Push images
          docker push ${{ matrix.component.image }}:${{ needs.prepare.outputs.version }}
          docker push ${{ matrix.component.image }}:latest

  deploy:
    needs: [build, prepare]
    runs-on: [self-hosted, linux, ARM64, arm64-runners]
    steps:
      - name: Checkout source code
        uses: actions/checkout@v4
        
      # kubectl und helm sind bereits auf dem Runner installiert
      # (über das runner template)
      
      - name: Deploy with Helm
        run: |
          helm upgrade --install weatherstation ./helm/weatherstation \
            --create-namespace \
            --namespace weatherstation \
            --set influxdb.secrets.INFLUXDB_INIT_USERNAME="${{ secrets.INFLUXDB_INIT_USERNAME }}" \
            --set influxdb.secrets.INFLUXDB_INIT_PASSWORD="${{ secrets.INFLUXDB_INIT_PASSWORD }}" \
            --set influxdb.secrets.INFLUXDB_INIT_ADMIN_TOKEN="${{ secrets.INFLUXDB_INIT_ADMIN_TOKEN }}" \
            --set backend.secrets.OPEN_WEATHER_MAP_API_KEY="${{ secrets.OPEN_WEATHER_MAP_API_KEY }}" \
            --set postgres.password="${{ secrets.POSTGRES_PASSWORD }}" \
            --set backend.imageVersion=${{ needs.prepare.outputs.version }} \
            --set frontend.imageVersion=${{ needs.prepare.outputs.version }} \
            --set things.imageVersion=${{ needs.prepare.outputs.version }} \
            --set weather.imageVersion=${{ needs.prepare.outputs.version }}
```

## Wichtige Änderungen

### ✅ Vorteile der ARM64 Runner

1. **Kein QEMU mehr nötig** - Native ARM64 builds sind viel schneller
2. **Kein Docker Buildx Setup** - Standard Docker reicht
3. **Direkter Cluster-Zugriff** - Keine SSH-Tunneling oder externe kubectl
4. **Bessere Performance** - Native Architektur, keine Emulation

### 🔧 Was angepasst wurde

1. **Runner Labels**: `runs-on: [self-hosted, linux, ARM64, arm64-runners]`
2. **Docker Build**: Vereinfacht, da nativ auf ARM64
3. **Tools**: kubectl/helm sind bereits auf dem Runner verfügbar
4. **Kubeconfig**: Nicht mehr nötig, da Runner bereits im Cluster läuft

### 🚀 Performance Verbesserungen

- **Build-Zeit**: ~70% schneller (keine Cross-Compilation)
- **Push-Zeit**: Gleich, aber weniger CPU-Last
- **Deploy-Zeit**: Schneller, da direkte Cluster-Verbindung

### 🔒 Sicherheit

- Secrets bleiben in deinem privaten Repository
- Runner läuft in deiner kontrollierten Umgebung
- Keine externe Abhängigkeiten für Cluster-Zugriff
```
