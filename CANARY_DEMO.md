# Canary Deployment Demo Guide

## Overview

The `nginx-demo` application uses **Canary** deployment strategy with Argo Rollouts. This allows you to:

- Gradually shift traffic from old version to new version
- Monitor the new version with real production traffic
- Automatically progress through traffic percentages
- Rollback easily if issues are detected

## Current Setup

- **Stable Service**: `nginx-demo-stable` - serves the stable/current version
- **Canary Service**: `nginx-demo-canary` - serves the new version during rollout
- **Traffic Routing**: AWS ALB (Application Load Balancer) manages traffic splitting
- **Steps**: 25% → 50% → 75% → 100% (with pause points)

## How to Trigger a Canary Deployment

### Method 1: Update the Image (via ArgoCD)

1. Update the image tag in `k8s-app/nginx-demo/rollout.yaml`:

   ```yaml
   containers:
     - name: nginx-demo
       image: nginx:1.26-alpine  # Change from stable to 1.26-alpine
   ```

2. Commit and push to your Git repository
3. ArgoCD will automatically sync the change
4. Argo Rollouts will start the canary deployment with 25% traffic

### Method 2: Update via kubectl (for testing)

```bash
# Update the image
kubectl set image rollout/nginx-demo nginx-demo=nginx:1.26-alpine

# Or patch the rollout
kubectl patch rollout nginx-demo --type=json -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "nginx:1.26-alpine"}]'
```

## What Happens During Canary Deployment

1. **New ReplicaSet Created**: Argo Rollouts creates a new ReplicaSet with the new image
2. **25% Traffic**: ALB routes 25% of traffic to canary pods, 75% to stable pods
3. **Pause**: Rollout pauses for manual verification (or automatic after duration)
   - **To resume after verification**: Run `kubectl argo rollouts resume nginx-demo`
   - Or use ArgoCD UI: Click on the Rollout → Click "Resume" button
4. **50% Traffic**: If healthy, traffic increases to 50%
5. **75% Traffic**: Traffic increases to 75%
6. **100% Traffic**: Full traffic shift to new version
7. **Stable Updated**: Canary becomes the new stable version

## Traffic Splitting Steps

The canary deployment follows these steps (defined in `rollout.yaml`):

```yaml
steps:
  - setWeight: 25      # Start with 25% traffic to canary
  - pause: {}          # Pause for manual verification
  - setWeight: 50      # Increase to 50% traffic
  - pause: { duration: 30s }  # Pause for 30 seconds
  - setWeight: 75      # Increase to 75% traffic
  - pause: { duration: 30s }  # Pause for 30 seconds
  - setWeight: 100     # Full traffic to new version
```

## Monitoring the Canary Deployment

### Check Rollout Status

```bash
# View rollout status
kubectl get rollout nginx-demo

# Detailed status
kubectl describe rollout nginx-demo

# View rollout status with Argo Rollouts plugin (if installed)
kubectl argo rollouts get rollout nginx-demo
```

### Check Pods

```bash
# See both stable and canary pods
kubectl get pods -l app=nginx-demo

# Check which ReplicaSet is stable vs canary
kubectl get replicaset -l app=nginx-demo
```

### Check Services

```bash
# Stable service (majority of traffic)
kubectl get svc nginx-demo-stable

# Canary service (new version traffic)
kubectl get svc nginx-demo-canary

# Check service endpoints
kubectl get endpoints nginx-demo-stable
kubectl get endpoints nginx-demo-canary
```

### Check Traffic Distribution

```bash
# View ALB target group weights (via AWS CLI)
aws elbv2 describe-target-groups --region <region> \
  --query 'TargetGroups[?contains(TargetGroupName, `nginx-demo`)].{Name:TargetGroupName,Port:Port}'

# Check Ingress status
kubectl get ingress nginx-demo -o yaml
```

## Testing During Canary

### Via ALB URL

```bash
# Get the ALB URL
ALB_URL=$(kubectl get ingress nginx-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Make multiple requests to see traffic distribution
for i in {1..10}; do
  curl -s http://$ALB_URL/ | grep -o "nginx/[0-9.]*"
done
```

### Via Port Forward

```bash
# Forward stable service
kubectl port-forward svc/nginx-demo-stable 8080:80

# Forward canary service (in another terminal)
kubectl port-forward svc/nginx-demo-canary 8081:80

# Test both
curl http://localhost:8080  # Stable version
curl http://localhost:8081   # Canary version
```

## Manual Control

### Resume After Manual Verification

**When the rollout pauses at a step (like at 25% traffic), you need to manually resume it to continue:**

**Via kubectl (Recommended):**

```bash
# Resume the rollout to continue to next step
kubectl argo rollouts resume nginx-demo

# Verify it's resuming
kubectl get rollout nginx-demo -w
```

**Via ArgoCD UI:**

1. Go to the `nginx-demo` application in ArgoCD
2. Click on the Rollout resource (the one showing "Suspended" status)
3. Look for the "Resume" button in the actions menu
4. Click "Resume" to continue the deployment

**Via kubectl patch:**

```bash
# Alternative method using kubectl patch
kubectl patch rollout nginx-demo --type=merge -p='{"spec":{"paused":false}}'
```

### Pause the Rollout (if needed)

If you need to pause the rollout manually:

```bash
# Pause at current step
kubectl argo rollouts pause nginx-demo

# Or via patch
kubectl patch rollout nginx-demo --type=merge -p='{"spec":{"paused":true}}'
```

### Retry Failed Step

```bash
# Retry the current step
kubectl argo rollouts retry nginx-demo
```

## Rollback

If issues are detected during the canary:

```bash
# Abort the rollout (reverts to stable version)
kubectl argo rollouts abort nginx-demo

# Or set image back to previous version
kubectl set image rollout/nginx-demo nginx-demo=nginx:stable
```

## Key Features

- **Gradual Traffic Shift**: Reduces risk by exposing new version to small percentage first
- **Automatic Progression**: Can automatically move through steps if healthy
- **Pause Points**: Built-in pauses for verification at each step
- **Real Production Traffic**: Tests with actual user traffic, not synthetic
- **Easy Rollback**: Can abort at any step to revert to stable version

## Example Workflow

1. **Deploy new version**:

   ```bash
   kubectl set image rollout/nginx-demo nginx-demo=nginx:1.26-alpine
   ```

2. **Watch rollout progress**:

   ```bash
   kubectl get rollout nginx-demo -w
   ```

3. **Monitor at 25% traffic**:

   ```bash
   # Check metrics, logs, errors
   kubectl logs -l app=nginx-demo --tail=50
   ```

4. **Verify health** (when paused at 25%):

   ```bash
   # Test canary version via port-forward
   kubectl port-forward svc/nginx-demo-canary 8080:80
   curl http://localhost:8080

   # Or test via ALB (25% of requests will hit canary)
   ALB_URL=$(kubectl get ingress nginx-demo -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
   curl http://$ALB_URL/

   # Check metrics, logs, errors
   kubectl logs -l app=nginx-demo --tail=50
   ```

5. **Resume to continue** (after verification):

   ```bash
   # Resume the rollout to proceed to 50% traffic
   kubectl argo rollouts resume nginx-demo

   # Watch it progress
   kubectl get rollout nginx-demo -w
   ```

6. **Monitor progression**: Watch as traffic increases 25% → 50% → 75% → 100%

7. **Complete**: New version becomes stable automatically

## Troubleshooting

### Rollout Stuck at a Step

```bash
# Check rollout status
kubectl describe rollout nginx-demo

# Check pod health
kubectl get pods -l app=nginx-demo

# Check service endpoints
kubectl get endpoints nginx-demo-stable nginx-demo-canary
```

### Traffic Not Splitting Correctly

```bash
# Verify ALB target groups
aws elbv2 describe-target-groups --region <region> \
  --query 'TargetGroups[?contains(TargetGroupName, `nginx-demo`)]'

# Check Ingress annotations
kubectl get ingress nginx-demo -o yaml | grep alb.ingress
```

### Canary Pods Not Ready

```bash
# Check pod status
kubectl get pods -l app=nginx-demo

# Check pod logs
kubectl logs <canary-pod-name>

# Check events
kubectl describe pod <canary-pod-name>
```
