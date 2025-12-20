# AWS EKS with ArgoCD and Argo Rollouts Demo

A complete Terraform demonstration of deploying ArgoCD and Argo Rollouts on AWS EKS with Application Load Balancer (ALB) ingress.

## Overview

This project demonstrates:

- **EKS Cluster** - Managed Kubernetes cluster on AWS
- **ArgoCD** - GitOps continuous delivery tool
- **Argo Rollouts** - Progressive delivery controller for Kubernetes
- **AWS Load Balancer Controller** - Manages ALB ingress for Kubernetes services
- **Demo Applications** - Two sample apps showcasing canary and blue-green deployment strategies

## Architecture

```text
┌─────────────────────────────────────────────────────────────┐
│                    AWS Application Load Balancer              │
│              (Internet-facing ALB on port 80)                │
└───────────────────────┬───────────────────────────────────────┘
                        │
                        ▼
┌─────────────────────────────────────────────────────────────┐
│                    EKS Cluster                                   │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  ArgoCD Server (Ingress → Service → Pods)              │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Argo Rollouts Controller                              │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  AWS Load Balancer Controller                          │  │
│  └────────────────────────────────────────────────────────┘  │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  Demo Applications:                                    │  │
│  │    - nginx-demo (Canary strategy)                      │  │
│  │    - go-demo (Blue-Green strategy)                     │  │
│  └────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## Features

- **GitOps Workflow** - ArgoCD automatically syncs applications from Git repository
- **Progressive Delivery** - Canary and blue-green deployment strategies
- **ALB Integration** - ArgoCD accessible via AWS Application Load Balancer
- **Insecure Mode** - HTTP access enabled for demo purposes (no TLS required)
- **Modular Design** - Clean module structure for maintainability

## Prerequisites

- AWS CLI configured with appropriate credentials
- Terraform >= 1.0
- kubectl installed
- AWS account with permissions to create:
  - EKS clusters
  - VPCs and networking resources
  - IAM roles and policies
  - Application Load Balancers

## Quick Start

1. **Clone the repository**

   ```bash
   git clone https://github.com/jdevto/tf-aws-eks-argocd-rollouts-demo.git
   cd tf-aws-eks-argocd-rollouts-demo
   ```

2. **Configure variables** (optional)

   ```bash
   # Edit variables.tf or use terraform.tfvars
   # Default values:
   #   - cluster_name: "test"
   #   - aws_region: "ap-southeast-2"
   #   - cluster_version: "1.34"
   ```

3. **Initialize Terraform**

   ```bash
   terraform init
   ```

4. **Plan and apply**

   ```bash
   terraform plan
   terraform apply
   ```

5. **Get ArgoCD credentials**

   ```bash
   # Get the ALB URL
   terraform output argocd_server_url

   # Get the admin password
   terraform output argocd_password
   ```

6. **Access ArgoCD**
   - Open the ALB URL in your browser
   - Username: `admin`
   - Password: Use the output from step 5

## Module Structure

```text
.
├── main.tf                    # Root module configuration
├── variables.tf               # Root variables
├── outputs.tf                # Root outputs
├── providers.tf              # Provider configuration
├── locals.tf                 # Local values
└── modules/
    ├── vpc/                  # VPC and networking
    ├── eks/                  # EKS cluster and node groups
    ├── aws-lb-controller/    # AWS Load Balancer Controller
    └── argocd/               # ArgoCD and Argo Rollouts
```

## Demo Applications

### nginx-demo (Canary Strategy)

- **Strategy**: Canary deployment
- **Steps**: 25% → 50% → 75% → 100% with pauses
- **Location**: `k8s-app/nginx-demo/`

### go-demo (Blue-Green Strategy)

- **Strategy**: Blue-Green deployment
- **Features**: Preview service for testing before promotion
- **Location**: `k8s-app/go-demo/`

### atlantis-demo (Blue-Green Strategy)

- **Strategy**: Blue-Green deployment
- **Features**: Atlantis Terraform automation tool with preview service
- **Location**: `k8s-app/atlantis-demo/`
- **Note**: Requires GitHub token/webhook secret configuration for full functionality
- **Location**: `k8s-app/go-demo/`

## Configuration

### Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `cluster_name` | EKS cluster name | `"test"` |
| `aws_region` | AWS region | `"ap-southeast-2"` |
| `cluster_version` | Kubernetes version | `"1.34"` |
| `repo_url` | Git repository URL for ArgoCD | GitHub repo URL |
| `target_revision` | Git branch/tag to track | `"main"` |

### Outputs

- `argocd_server_url` - ArgoCD ALB URL
- `argocd_username` - Admin username (always `admin`)
- `argocd_password` - Admin password
- `cluster_name` - EKS cluster name
- `cluster_endpoint` - EKS API endpoint

## Argo Rollouts Strategies

### Canary (nginx-demo)

```yaml
strategy:
  canary:
    steps:
      - setWeight: 25
      - pause: {}
      - setWeight: 50
      - pause: { duration: 30s }
      - setWeight: 75
      - pause: { duration: 30s }
      - setWeight: 100
```

### Blue-Green (go-demo)

```yaml
strategy:
  blueGreen:
    activeService: go-demo
    previewService: go-demo-preview
    autoPromotionEnabled: false
    scaleDownDelaySeconds: 30
```

## Troubleshooting

### ArgoCD not accessible

- Check ALB target group health: `aws elbv2 describe-target-health`
- Verify Ingress status: `kubectl get ingress -n argocd`
- Check ArgoCD pods: `kubectl get pods -n argocd`

### Health checks failing

- Ensure health check path is `/healthz` (not `/api/version`)
- Verify ArgoCD is in insecure mode: `kubectl get configmap -n argocd argocd-cmd-params-cm -o yaml`

### Applications not syncing

- Check ArgoCD application status: `kubectl get applications -n argocd`
- Verify Git repository is accessible
- Check ArgoCD logs: `kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server`

## Security Notes

⚠️ **This is a demo configuration:**

- HTTP (not HTTPS) is enabled for simplicity
- Insecure mode is enabled
- Default admin password should be changed in production
- Consider using ACM certificates and HTTPS for production use

## Cleanup

To destroy all resources:

```bash
terraform destroy
```

## License

See [LICENSE](LICENSE) file for details.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
