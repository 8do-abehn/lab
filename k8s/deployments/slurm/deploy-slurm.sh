#!/bin/bash
set -e

echo "=== Deploying Slurm on Kubernetes via Slinky Project ==="
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Step 1: Adding Helm repositories...${NC}"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add jetstack https://charts.jetstack.io
helm repo update

echo -e "${GREEN}✓ Helm repositories added${NC}"
echo ""

echo -e "${YELLOW}Step 2: Installing cert-manager...${NC}"
if helm list -n cert-manager | grep -q cert-manager; then
    echo "cert-manager already installed, skipping..."
else
    helm install cert-manager jetstack/cert-manager \
        --namespace cert-manager --create-namespace \
        --set crds.enabled=true
    echo "Waiting for cert-manager to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/instance=cert-manager -n cert-manager --timeout=300s
fi
echo -e "${GREEN}✓ cert-manager ready${NC}"
echo ""

echo -e "${YELLOW}Step 3: Installing Prometheus...${NC}"
if helm list -n prometheus | grep -q prometheus; then
    echo "Prometheus already installed, skipping..."
else
    helm install prometheus prometheus-community/kube-prometheus-stack \
        --namespace prometheus --create-namespace \
        --set installCRDs=true
    echo "Waiting for Prometheus operator to be ready..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus-operator -n prometheus --timeout=300s
fi
echo -e "${GREEN}✓ Prometheus ready${NC}"
echo ""

echo -e "${YELLOW}Step 4: Installing Slurm Operator CRDs...${NC}"
helm install slurm-operator-crds oci://ghcr.io/slinkyproject/charts/slurm-operator-crds \
    --version=0.4.1
echo -e "${GREEN}✓ Slurm Operator CRDs installed${NC}"
echo ""

echo -e "${YELLOW}Step 5: Installing Slurm Operator...${NC}"
if [ -f "values-operator.yaml" ]; then
    echo "Using custom values from values-operator.yaml"
    helm install slurm-operator oci://ghcr.io/slinkyproject/charts/slurm-operator \
        --values=values-operator.yaml \
        --version=0.4.1 \
        --namespace=slinky --create-namespace
else
    echo "Using default values"
    helm install slurm-operator oci://ghcr.io/slinkyproject/charts/slurm-operator \
        --version=0.4.1 \
        --namespace=slinky --create-namespace
fi
echo "Waiting for operator to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=slurm-operator -n slinky --timeout=300s
echo -e "${GREEN}✓ Slurm Operator ready${NC}"
echo ""

echo -e "${YELLOW}Step 6: Installing Slurm Cluster...${NC}"
if [ -f "values-slurm.yaml" ]; then
    echo "Using custom values from values-slurm.yaml"
    helm install slurm oci://ghcr.io/slinkyproject/charts/slurm \
        --values=values-slurm.yaml \
        --version=0.4.1 \
        --namespace=slurm --create-namespace
else
    echo "Using default values"
    helm install slurm oci://ghcr.io/slinkyproject/charts/slurm \
        --version=0.4.1 \
        --namespace=slurm --create-namespace
fi
echo -e "${GREEN}✓ Slurm cluster deployment started${NC}"
echo ""

echo -e "${YELLOW}Waiting for Slurm components to be ready...${NC}"
echo "This may take several minutes..."
echo ""

# Wait for key components
echo "Waiting for MariaDB..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=mariadb -n slurm --timeout=600s

echo "Waiting for Slurm controller..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller -n slurm --timeout=600s

echo "Waiting for Slurm compute nodes..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=compute -n slurm --timeout=600s

echo ""
echo -e "${GREEN}=== Slurm Deployment Complete! ===${NC}"
echo ""
echo "Check cluster status:"
echo "  kubectl -n slurm get pods"
echo ""
echo "Access Slurm login node:"
echo "  kubectl -n slurm exec -it \$(kubectl -n slurm get pod -l app.kubernetes.io/component=login -o name) -- bash"
echo ""
echo "Run a test job:"
echo "  kubectl -n slurm exec -it \$(kubectl -n slurm get pod -l app.kubernetes.io/component=login -o name) -- srun hostname"
