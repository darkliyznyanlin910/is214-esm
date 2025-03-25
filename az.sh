export REGION="southeastasia"
export RESOURCE_GROUP_NAME="esm-aks-rg"
export AKS_CLUSTER_NAME="esm-aks-cluster"
export ACR_NAME="esmproject"

ACTION=$1
case "$ACTION" in
  init)
    az group create --name $RESOURCE_GROUP_NAME --location $REGION
    az aks create --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME --node-count 1 --generate-ssh-keys
    az acr login --name $ACR_NAME
    az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME
    kubectl create secret docker-registry acr-secret \
      --docker-server=$ACR_NAME.azurecr.io \
      --docker-username=$(az acr credential show --name $ACR_NAME --query username -o tsv) \
      --docker-password=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv) \
      --namespace=default \
      --dry-run=client -o yaml | kubectl apply -f -
    ;;
  login)
    az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME
    az acr login --name $ACR_NAME
    ;;
  build)
    docker buildx create --use
    docker buildx build --platform linux/amd64,linux/arm64 -t $ACR_NAME.azurecr.io/odoo-kubernetes:latest --push ./docker
    ;;
  install)
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.4/components.yaml
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    kubectl apply -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.21/releases/cnpg-1.21.3.yaml
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.yaml
    ;;
  uninstall)
    kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.4/components.yaml
    kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    kubectl delete -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.21/releases/cnpg-1.21.3.yaml
    kubectl delete -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.yaml
    ;;
  deploy)
    case "$2" in
      odoo)
        kubectl apply -k k8s/default
        ;;
      postgres)
        kubectl apply -k k8s/postgres
        ;;
      ingress)
        kubectl apply -k k8s/ingress
        ;;
      vector)
        kubectl apply -k k8s/vector
        ;;
      *)
        kubectl apply -k k8s
        ;;
    esac
    ;;
  get-ip)
    echo "Getting Ingress IP..."
    IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo "Your Odoo instance is accessible at: http://$IP"
    ;;
  revert)
    kubectl delete -k k8s
    ;;
  delete)
    az group delete --name $RESOURCE_GROUP_NAME --yes
    ;;
  *)
    echo "Usage: $0 {init|login|build|install|uninstall|deploy [odoo|postgres|ingress|vector]|get-ip|revert|delete}"
    exit 1
esac
