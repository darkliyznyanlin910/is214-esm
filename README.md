# Azure AKS Setup & Deployment Guide

## Prerequisites

- `az` (Azure CLI) installed
- `docker` installed
- `kubectl` installed
- Azure subscription
- Azure Container Registry (ACR) created with name "esmproject"

## Azure Resources

- Region: southeastasia
- Resource Group: esm-aks-rg
- AKS Cluster: esm-aks-cluster
- ACR: esmproject

## Commands

```bash
# Initialize Azure resources, create AKS cluster, and setup ACR credentials
./az.sh init

# Build multi-arch Docker image
./az.sh build

# Push image to ACR
./az.sh push

# Install supporting services (metrics-server, ingress-nginx, cloudnative-pg)
./az.sh install

# Deploy to AKS
./az.sh deploy

# Install cert-manager for SSL certificates
./az.sh install-cert-manager

# Setup SSL with Let's Encrypt (requires domain name)
./az.sh setup-ssl yourdomain.com

# Get Ingress IP
./az.sh get-ip

# Uninstall supporting services
./az.sh uninstall

# Revert deployment (remove k8s resources)
./az.sh revert

# Delete all Azure resources
./az.sh delete
```

## K8s Structure

```
k8s/
├── kustomization.yaml    # Root Kustomize config
├── default/              # Default namespace resources
│   ├── kustomization.yaml    # Default namespace Kustomize config
│   ├── odoo-deployment.yaml  # Odoo deployment spec
│   ├── postgresql.yaml       # PostgreSQL deployment
│   ├── odoo-configmap.yaml   # Odoo config
│   ├── odoo-secret.yaml      # Odoo secrets
│   ├── odoo-ingress.yaml     # Ingress rules
│   └── odoo-service.yaml     # Service definition
└── vector/               # Vector logging resources
    ├── kustomization.yaml    # Vector Kustomize config
    ├── vector-agent.yaml     # Vector agent DaemonSet
    ├── vector-namespace.yaml # Vector namespace definition
    └── rbac.yaml             # Vector RBAC permissions
```

## Deployment Flow

1. `init`: Creates Azure resources, AKS cluster, and sets up ACR credentials
2. `build`: Builds multi-arch Docker image for amd64 and arm64
3. `push`: Pushes image to Azure Container Registry
4. `deploy`: Applies all k8s manifests using kustomize
5. `install`: Sets up metrics-server, NGINX Ingress Controller, and CloudNative PostgreSQL
6. `install-cert-manager`: Installs cert-manager for SSL certificates
7. `setup-ssl`: Configures Let's Encrypt SSL certificate for a specified domain
8. `get-ip`: Retrieves public IP for access

## Cleanup

- `uninstall`: Removes supporting components (metrics-server, ingress-nginx, cloudnative-pg)
- `revert`: Removes k8s resources deployed via kustomize
- `delete`: Tears down all Azure resources
