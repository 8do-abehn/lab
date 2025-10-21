#!/bin/bash
set -e

echo "=== Netdata Helm Chart Quickstart ==="
echo

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo "Error: Helm is not installed. Please install Helm first."
    exit 1
fi

# Add Netdata repo
echo "1. Adding Netdata Helm repository..."
helm repo add netdata https://netdata.github.io/helmchart/
helm repo update

echo
echo "2. Choose deployment method:"
echo "   a) Direct values (simple, less secure)"
echo "   b) Kubernetes secrets (recommended)"
echo
read -p "Enter choice (a/b): " choice

case $choice in
    a)
        echo
        echo "Installing with direct values..."
        helm install netdata netdata/netdata -f values.yaml
        ;;
    b)
        echo
        if [ ! -f secret.yaml ]; then
            echo "Creating secret.yaml from example..."
            cp secret.yaml.example secret.yaml
            echo "⚠️  Please edit secret.yaml with your actual tokens before proceeding!"
            echo "   Press Enter when ready..."
            read
        fi

        echo "Applying secret..."
        kubectl apply -f secret.yaml

        echo "Installing Netdata with secrets..."
        helm install netdata netdata/netdata -f values-with-secrets.yaml
        ;;
    *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
esac

echo
echo "=== Installation Complete ==="
echo
echo "Check status with:"
echo "  kubectl get pods -l app=netdata"
echo
echo "View logs with:"
echo "  kubectl logs -l app=netdata --tail=50"
echo
echo "Check claiming status:"
echo "  kubectl logs -l app=netdata | grep -i claim"
