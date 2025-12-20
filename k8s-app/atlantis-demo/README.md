# Atlantis Demo Configuration

## Prerequisites

Atlantis requires GitHub authentication to function. You must configure the following before deploying:

### 1. Create GitHub Personal Access Token

1. Go to <https://github.com/settings/tokens>
2. Click "Generate new token" → "Generate new token (classic)"
3. Set expiration and required scopes:
   - `repo` - Full control of private repositories
   - `admin:repo_hook` - Full control of repository hooks
   - `write:repo_hook` - Write repository hooks
4. Generate and copy the token (starts with `ghp_`)

### 2. Update Secret

Edit `secret.yaml` and replace the placeholder values:

```yaml
stringData:
  github-user: "your-github-username"  # Replace REQUIRED
  github-token: "ghp_your_token_here"   # Replace REQUIRED
  webhook-secret: ""                    # Optional, leave empty for now
```

### 3. Apply the Secret

```bash
# Update the secret in Kubernetes
kubectl apply -f secret.yaml

# Or update via kubectl
kubectl create secret generic atlantis-demo-secrets \
  --from-literal=github-user='your-username' \
  --from-literal=github-token='ghp_your_token' \
  --from-literal=webhook-secret='' \
  --dry-run=client -o yaml | kubectl apply -f -
```

### 4. Restart the Rollout

After updating the secret, restart the rollout:

```bash
kubectl rollout restart rollout/atlantis-demo
```

## Configuration

### ConfigMap

The `configmap.yaml` contains:

- `repo-allowlist`: Which repositories Atlantis can access (default: `github.com/*`)
- `repo-config.json`: Workflow and policy configuration

### Environment Variables

Atlantis uses these environment variables (set in `rollout.yaml`):

- `ATLANTIS_REPO_ALLOWLIST` - Repository allowlist
- `ATLANTIS_DATA_DIR` - Data directory for Atlantis state
- `ATLANTIS_REPO_CONFIG_JSON` - Repository configuration JSON
- `ATLANTIS_GH_USER` - GitHub username (from secret)
- `ATLANTIS_GH_TOKEN` - GitHub token (from secret)
- `ATLANTIS_GH_WEBHOOK_SECRET` - Webhook secret (from secret, optional)

## Troubleshooting

### Container CrashLoopBackOff

If the container is crashing with authentication errors:

1. **Check secret exists:**

   ```bash
   kubectl get secret atlantis-demo-secrets
   ```

2. **Verify secret values:**

   ```bash
   kubectl get secret atlantis-demo-secrets -o jsonpath='{.data.github-user}' | base64 -d
   kubectl get secret atlantis-demo-secrets -o jsonpath='{.data.github-token}' | base64 -d
   ```

3. **Check pod logs:**

   ```bash
   kubectl logs -l app=atlantis-demo --tail=50
   ```

4. **Ensure values are not "REQUIRED" placeholder:**
   - The secret must have actual GitHub username and token
   - Values cannot be empty or the placeholder text

### Missing Authentication Error

If you see: `--gh-user/--gh-token ... must be set`

- The secret values are empty or not set correctly
- Update the secret with actual GitHub credentials
- Restart the rollout after updating

## Accessing Atlantis

Once deployed and running:

1. Get the ALB URL:

   ```bash
   kubectl get ingress atlantis-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
   ```

2. Access Atlantis UI at: `http://<alb-url>`

3. Configure webhook in your GitHub repository:
   - URL: `http://<alb-url>/events`
   - Content type: `application/json`
   - Secret: (use webhook-secret if configured)

## Blue-Green Deployment

This demo uses Blue-Green deployment strategy:

- **Active Service**: `atlantis-demo` - Production traffic
- **Preview Service**: `atlantis-demo-preview` - New version for testing
- **Promotion**: Manual (set `autoPromotionEnabled: false`)

To promote a new version:

```bash
kubectl argo rollouts promote atlantis-demo
```
