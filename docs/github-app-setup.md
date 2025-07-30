# GitHub App Setup for Self-Hosted Runners

## Option 1: GitHub App (Recommended for Organizations)

### 1. Create GitHub App

1. Go to your GitHub organization settings
2. Navigate to **Developer settings** → **GitHub Apps** → **New GitHub App**
3. Fill in the details:
   - **App name**: `YourOrg ARM64 Runners`
   - **Homepage URL**: Your organization URL
   - **Webhook URL**: Leave empty (we don't use webhooks initially)
   - **Webhook secret**: Leave empty

### 2. Set Permissions

**Repository permissions:**
- Actions: Read
- Administration: Read
- Checks: Write
- Contents: Read
- Metadata: Read
- Pull requests: Write

**Organization permissions:**
- Actions: Read
- Administration: Read
- Self-hosted runners: Write

### 3. Generate Private Key

1. In your GitHub App settings, scroll to **Private keys**
2. Click **Generate a private key**
3. Download the `.pem` file

### 4. Install App

1. Go to **Install App** tab
2. Install on your organization
3. Choose **Selected repositories** or **All repositories**
4. Note the **Installation ID** from the URL

### 5. Configure Repository Secrets

Add these secrets to your runner-deployment repository:

```bash
# GitHub App authentication
GITHUB_APP_ID=123456
GITHUB_APP_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----
...your private key content...
-----END RSA PRIVATE KEY-----"
GITHUB_APP_INSTALLATION_ID=12345678

# Alternative: if using organization-level
GITHUB_CONFIG_URL=https://github.com/your-organization

# Alternative: if using repository-level  
GITHUB_CONFIG_URL=https://github.com/your-organization/your-repo
```

## Option 2: Personal Access Token (Simpler Setup)

### 1. Create PAT

1. Go to **GitHub Settings** → **Developer settings** → **Personal access tokens** → **Fine-grained tokens**
2. Create new token with:
   - **Resource owner**: Your organization
   - **Repository access**: Selected repositories (choose your private repos)

### 2. Set Permissions

**Repository permissions:**
- Actions: Write
- Administration: Write
- Contents: Read
- Metadata: Read

**Account permissions:**
- Actions: Write

### 3. Configure Repository Secrets

```bash
GITHUB_TOKEN=ghp_xxxxxxxxxxxxxxxxxxxx
GITHUB_CONFIG_URL=https://github.com/your-organization
```

## Cluster Configuration

### 1. Encode your kubeconfig

```bash
# On your local machine with cluster access:
cat ~/.kube/config | base64 -w 0
```

### 2. Add cluster secret

Add this to your repository secrets:
```bash
KUBECONFIG=<base64-encoded-kubeconfig>
```

## Security Best Practices

1. **Use GitHub App over PAT** - Better security and audit trail
2. **Limit repository access** - Only grant access to repositories that need it
3. **Regular token rotation** - Set up automatic token rotation
4. **Monitor runner usage** - Set up alerts for unusual activity
5. **Use environments** - Protect your production environment with required reviewers

## Testing the Setup

Create a simple test workflow in a private repository:

```yaml
name: Test ARM64 Runner
on: workflow_dispatch

jobs:
  test:
    runs-on: [self-hosted, linux, ARM64, arm64-runners]
    steps:
      - name: Test architecture
        run: |
          echo "Architecture: $(uname -m)"
          echo "OS: $(uname -a)"
          echo "Docker version:"
          docker --version
```

## Troubleshooting

### Common Issues

1. **Runner not appearing**: Check GitHub App permissions and installation
2. **Authentication failed**: Verify token permissions and expiration
3. **Runner can't access cluster**: Check kubeconfig encoding and cluster connectivity
4. **Jobs stuck in queue**: Verify runner labels match job requirements

### Debug Commands

```bash
# Check runner pods
kubectl get pods -n actions-runner-system

# Check runner logs
kubectl logs -n actions-runner-system -l app=github-runner

# Check controller logs
kubectl logs -n actions-runner-system -l app.kubernetes.io/name=actions-runner-controller
```
