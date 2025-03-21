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
    az acr login --name $ACR_NAME
    az aks get-credentials --resource-group $RESOURCE_GROUP_NAME --name $AKS_CLUSTER_NAME
    kubectl create secret docker-registry acr-secret \
      --docker-server=$ACR_NAME.azurecr.io \
      --docker-username=$(az acr credential show --name $ACR_NAME --query username -o tsv) \
      --docker-password=$(az acr credential show --name $ACR_NAME --query "passwords[0].value" -o tsv) \
      --namespace=default \
      --dry-run=client -o yaml | kubectl apply -f -
    ;;
  build)
    docker buildx create --use
    docker buildx build --platform linux/amd64,linux/arm64 -t odoo-kubernetes ./docker
    ;;
  push)
    docker buildx build --platform linux/amd64,linux/arm64 -t $ACR_NAME.azurecr.io/odoo-kubernetes:latest --push ./docker
    ;;
  deploy)
    kubectl apply -k k8s
    ;;
  install)
    kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.4/components.yaml
    kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    kubectl apply --server-side=true --force-conflicts -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.21/releases/cnpg-1.21.3.yaml
    ;;
  install-cert-manager)
    # Install cert-manager
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.1/cert-manager.yaml
    echo "Cert-manager installed. Waiting for pods to be ready..."
    kubectl wait --for=condition=Ready pod -l app=cert-manager -n cert-manager --timeout=60s
    ;;
  setup-ssl)
    # Takes domain as parameter: ./az.sh setup-ssl example.com
    DOMAIN=$2
    if [ -z "$DOMAIN" ]; then
      echo "Domain parameter required. Usage: $0 setup-ssl yourdomain.com"
      exit 1
    fi
    
    # Get the ingress IP address
    IP=$(kubectl get service ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
    echo "Ingress IP: $IP"
    echo "Setting up SSL for domain: $DOMAIN"
    echo "Please ensure your DNS A record for $DOMAIN points to $IP"
    
    # Create ClusterIssuer for Let's Encrypt
    cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@${DOMAIN}
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
    
    # Update the ingress to use TLS
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: odoo
  annotations:
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "600"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "600"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - ${DOMAIN}
    secretName: odoo-tls-cert
  rules:
  - host: ${DOMAIN}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: odoo
            port:
              number: 80
EOF

    echo "SSL setup initiated. Certificate will be issued once DNS propagation is complete."
    echo "Check status with: kubectl get certificate"
    ;;
  uninstall)
    kubectl delete -f https://github.com/kubernetes-sigs/metrics-server/releases/download/v0.6.4/components.yaml
    kubectl delete -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.8.2/deploy/static/provider/cloud/deploy.yaml
    kubectl delete -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.21/releases/cnpg-1.21.3.yaml
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
    echo "Usage: $0 {init|login|build|push|deploy|install|install-cert-manager|setup-ssl|uninstall|get-ip|revert|delete}"
    exit 1
esac
