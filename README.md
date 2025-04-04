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

# Login to AKS cluster and ACR
./az.sh login

# Build and push multi-arch Docker image to ACR
./az.sh build

# Deploy specific components or all to AKS
./az.sh deploy [COMPONENT]

# Install supporting services (metrics-server, ingress-nginx, cloudnative-pg, cert-manager)
./az.sh install

# Get Ingress IP
./az.sh get-ip

# Uninstall supporting services
./az.sh uninstall

# Revert deployment (remove k8s resources)
./az.sh revert [COMPONENT]

# Delete all Azure resources
./az.sh delete
```

## K8s Structure

```
k8s/
├── kustomization.yaml # Root Kustomize config
├── default/ # Default namespace resources
│ ├── kustomization.yaml # Default namespace Kustomize config
│ ├── odoo-deployment.yaml # Odoo deployment spec
│ ├── postgresql.yaml # PostgreSQL deployment
│ ├── odoo-configmap.yaml # Odoo config
│ ├── odoo-secret.yaml # Odoo secrets
│ ├── odoo-ingress.yaml # Ingress rules
│ └── odoo-service.yaml # Service definition
├── vector/ # Vector logging resources
│ ├── kustomization.yaml # Vector Kustomize config
│ ├── vector-agent.yaml # Vector agent DaemonSet
│ ├── vector-namespace.yaml # Vector namespace definition
│ └── rbac.yaml # Vector RBAC permissions
├── postgres/ # PostgreSQL resources
│ ├── kustomization.yaml # PostgreSQL Kustomize config
│ └── postgresql.yaml # PostgreSQL deployment spec
└── ingress/ # Ingress resources
├── kustomization.yaml # Ingress Kustomize config
└── ingress.yaml # Ingress rules
```

## Deployment Flow

1. `init`: Creates Azure resources, AKS cluster, and sets up ACR credentials
2. `login`: Logs into AKS cluster and ACR
3. `build`: Builds and pushes multi-arch Docker image for amd64 and arm64 to ACR
4. `deploy`: Applies k8s manifests using kustomize for specified components or all
5. `install`: Sets up metrics-server, NGINX Ingress Controller, CloudNative PostgreSQL, and cert-manager
6. `get-ip`: Retrieves public IP for access
7. `uninstall`: Removes supporting components
8. `revert`: Removes k8s resources deployed via kustomize for specified components or all
9. `delete`: Tears down all Azure resources
