export REGION="southeastasia"
export RESOURCE_GROUP_NAME="esm-aks-rg"
export AKS_CLUSTER_NAME="esm-aks-cluster"
export DNS_LABEL="esm-aks-dns-label"
export ACR_NAME="esmproject"

ACTION=$1
case "$ACTION" in
  init)
    az group create --name $RESOURCE_GROUP_NAME --location $REGION
    az aks create --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME --node-count 1 --generate-ssh-keys
    # Create ACR secret if it doesn't exist
    kubectl create secret docker-registry acr-secret \
      --docker-server=$ACR_NAME.azurecr.io \
      --docker-username=$ACR_NAME \
      --docker-password=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv) \
      --dry-run=client -o yaml | kubectl apply -f -
    ;;
  login)
    az acr login --name $ACR_NAME
    az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME
    ;;
  build)
    docker buildx create --use
    docker buildx build --platform linux/amd64,linux/arm64 -t odoo-kubernetes ./docker
    ;;
  push)
    docker buildx build --platform linux/amd64,linux/arm64 -t $ACR_NAME.azurecr.io/odoo-kubernetes:latest --push ./docker
    ;;
  deploy)
    kubectl apply -k k8s/manifests
    ;;
  ingress)
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    ;;
  get-ip)
    echo "Getting Ingress IP..."
    IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo "Your Odoo instance is accessible at: http://$IP"
    ;;
  revert)
    kubectl delete -k k8s/manifests
    ;;
  delete)
    az group delete --name $RESOURCE_GROUP_NAME --yes
    ;;
  *)
    echo "Usage: $0 {init|login|build|push|deploy|ingress|get-ip|revert|delete}"
    exit 1
esac
