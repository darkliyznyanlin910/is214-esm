# Azure AKS Setup & Deployment Guide

## Prerequisites

- Azure CLI installed
- Docker installed
- kubectl installed
- Azure subscription
- Azure Container Registry (ACR) created with name "esmproject"

## Azure Resources

- Region: southeastasia
- Resource Group: esm-aks-rg
- AKS Cluster: esm-aks-cluster
- ACR: esmproject

## Commands

```bash
# Initialize Azure resources and AKS cluster
./az.sh init

# Login to ACR and AKS
./az.sh login

# Build multi-arch Docker image
./az.sh build

# Push image to ACR
./az.sh push

# Deploy to AKS
./az.sh deploy

# Setup Ingress Controller
./az.sh ingress

# Get Ingress IP
./az.sh get-ip

# Revert deployment
./az.sh revert

# Delete all resources
./az.sh delete
```

## K8s Structure

```
k8s/
└── manifests/
    ├── kustomization.yaml    # Kustomize config
    ├── odoo-deployment.yaml  # Odoo deployment spec
    ├── postgresql.yaml       # PostgreSQL deployment
    ├── odoo-configmap.yaml   # Odoo config
    ├── odoo-secret.yaml      # Odoo secrets
    ├── odoo-ingress.yaml     # Ingress rules
    └── odoo-service.yaml     # Service definition
```

## Deployment Flow

1. `init`: Creates Azure resources and AKS cluster
2. `login`: Authenticates with ACR and AKS
3. `build`: Builds multi-arch Docker image
4. `push`: Pushes image to Azure Container Registry
5. `deploy`: Applies all k8s manifests
6. `ingress`: Sets up NGINX Ingress Controller
7. `get-ip`: Retrieves public IP for access

## Cleanup

- `revert`: Removes k8s resources
- `delete`: Tears down all Azure resources
