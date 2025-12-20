# Blue-Green Deployment Demo Guide

## Overview

The `go-demo` application uses **Blue-Green** deployment strategy with Argo Rollouts. This allows you to:

- Deploy a new version (green) alongside the current version (blue)
- Test the new version via the preview service before promoting
- Instantly switch traffic to the new version when ready

## Current Setup

- **Active Service**: `go-demo` (port 80) - serves production traffic
- **Preview Service**: `go-demo-preview` (port 8080) - serves new version for testing
- **Auto-Promotion**: Disabled (`autoPromotionEnabled: false`) - requires manual promotion

## How to Trigger a Blue-Green Deployment

### Method 1: Update the Image (via ArgoCD)

1. Update the image tag in `k8s-app/go-demo/rollout.yaml`:

   ```yaml
   containers:
     - name: go-demo
       image: golang:1.24-alpine  # Change from 1.23 to 1.24
   ```

2. Commit and push to your Git repository
3. ArgoCD will automatically sync the change
4. Argo Rollouts will create a new ReplicaSet (green) with the new image

### Method 2: Update via kubectl (for testing)

```bash
# Update the image
kubectl set image rollout/go-demo go-demo=golang:1.24-alpine

# Or patch the rollout
kubectl patch rollout go-demo --type=json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "golang:1.24-alpine"}]'
```

## What Happens During Blue-Green Deployment

1. **New Version Deployed**: Argo Rollouts creates a new ReplicaSet (green) with the new image
2. **Preview Service**: The `go-demo-preview` service points to the new pods
3. **Active Service**: The `go-demo` service continues pointing to the old pods (blue)
4. **Testing**: You can test the new version via the preview service
5. **Promotion**: When ready, promote the green version to become active

## How to Promote (Switch Traffic to New Version)

### Via kubectl (Recommended)

```bash
# Promote the preview to active
kubectl argo rollouts promote go-demo

# Or using kubectl patch
kubectl patch rollout go-demo --type=merge -p='{"status":{"promoteFull":true}}'
```

### Via ArgoCD UI

1. Go to the `go-demo` application in ArgoCD
2. Click on the Rollout resource
3. Look for the "Promote" button or action
4. Click to promote the preview version to active

## Monitoring the Blue-Green Deployment

### Check Rollout Status

```bash
# View rollout status
kubectl get rollout go-demo

# Detailed status
kubectl describe rollout go-demo

# View rollout status with Argo Rollouts plugin (if installed)
kubectl argo rollouts get rollout go-demo
```

### Check Pods

```bash
# See both blue and green pods
kubectl get pods -l app=go-demo

# Check which ReplicaSet is active
kubectl get replicaset -l app=go-demo
```

### Check Services

```bash
# Active service (production traffic)
kubectl get svc go-demo

# Preview service (new version for testing)
kubectl get svc go-demo-preview

# Check service endpoints
kubectl get endpoints go-demo
kubectl get endpoints go-demo-preview
```

## Testing the Preview Version

### Via Port Forward

```bash
# Forward preview service to localhost
kubectl port-forward svc/go-demo-preview 8080:8080

# Test in another terminal
curl http://localhost:8080
```

### Via Ingress (if configured)

If you have an Ingress pointing to the preview service, you can access it via the ALB URL.

## Rollback

If the new version has issues, you can abort the promotion:

```bash
# Abort the rollout (keeps blue version active)
kubectl argo rollouts abort go-demo
```

## Key Features

- **Instant Traffic Switch**: Zero-downtime deployment with immediate traffic shift
- **Full Testing**: Test new version completely before switching traffic
- **Manual Control**: You decide when to promote, ensuring confidence
- **Easy Rollback**: Can abort promotion and keep blue version active
- **Separate Environments**: Blue and green run independently

## Example Workflow

1. **Deploy new version**:

   ```bash
   kubectl set image rollout/go-demo go-demo=golang:1.24-alpine
   ```

2. **Wait for green pods to be ready**:

   ```bash
   kubectl get pods -l app=go-demo -w
   ```

3. **Test preview version**:

   ```bash
   kubectl port-forward svc/go-demo-preview 8080:8080
   curl http://localhost:8080
   ```

4. **Promote to active**:

   ```bash
   kubectl argo rollouts promote go-demo
   ```

5. **Verify traffic switched**:

   ```bash
   kubectl get endpoints go-demo
   # Should show new pod IPs
   ```

6. **Old version scales down** (after `scaleDownDelaySeconds: 30`):

   ```bash
   kubectl get pods -l app=go-demo
   # Old pods should be terminating
   ```
