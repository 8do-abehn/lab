#!/bin/bash
set -e

echo "=== Deploying Netdata with Kubernetes Secrets ==="
echo

# Step 1: Add Helm repo
echo "Step 1: Adding Netdata Helm repository..."
helm repo add netdata https://netdata.github.io/helmchart/
helm repo update
echo "✓ Helm repository added"
echo

# Step 2: Create the Kubernetes secret
echo "Step 2: Creating Kubernetes secret..."
kubectl apply -f secret.yaml
echo "✓ Secret created"
echo

# Step 3: Install Netdata
echo "Step 3: Installing Netdata with Helm..."
helm install netdata netdata/netdata -f values-with-secrets.yaml
echo "✓ Netdata installed"
echo

# Step 4: Verify deployment
echo "=== Deployment Complete ==="
echo
echo "Waiting for pods to start..."
sleep 5
echo
echo "Pod status:"
kubectl get pods -l app=netdata
echo
echo "To view logs:"
echo "  kubectl logs -l app=netdata --tail=50"
echo
echo "To verify claiming:"
echo "  kubectl logs -l app=netdata | grep -i claim"
echo
echo "To port-forward Netdata UI:"
echo "  kubectl port-forward svc/netdata 19999:19999"
echo "  Then visit: http://localhost:19999"
