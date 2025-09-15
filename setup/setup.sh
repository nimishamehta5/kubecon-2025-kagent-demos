#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e
set -o pipefail

# --- Check for Kind Cluster ---
if ! kind get clusters | grep -q "kind"; then
    echo "Creating kind cluster..."
    kind create cluster --config kind-config.yaml
else
    echo "Kind cluster 'kind' already exists, skipping creation."
fi

# --- Install Cilium ---
if ! kubectl get pods -n kube-system -l k8s-app=cilium --no-headers | grep -q "cilium"; then
    echo "Installing Cilium..."
    cilium install
    echo "Waiting for Cilium to be ready..."
    cilium status --wait
else
    echo "Cilium appears to be installed already, skipping installation."
fi

# --- Enable Hubble ---
if ! cilium status | grep -q "Hubble Relay:.*OK"; then
    echo "Enabling Cilium Hubble..."
    cilium hubble enable --ui
    echo "Waiting for Hubble to be ready..."
    sleep 20
else
    echo "Cilium Hubble is already enabled, skipping."
fi

# --- Port-forward for Hubble ---
echo "Ensuring Hubble port-forward is running..."
# Kill any existing port-forward processes 
if pgrep -f "cilium hubble port-forward" > /dev/null; then
    echo "Killing existing Hubble port-forward process..."
    pkill -f "cilium hubble port-forward" || true
    sleep 2 
fi

echo "Starting new Hubble port-forward..."
cilium hubble port-forward &>/dev/null &

echo "Waiting for Hubble port-forward to be ready..."
for i in {1..15}; do
    if nc -z localhost 4245; then
        echo "Hubble port-forward is ready."
        break
    fi
    if [ $i -eq 15 ]; then
        echo "Error: Hubble port-forward failed to start after 15 seconds."
        exit 1
    fi
    sleep 1
done

echo "Checking Hubble status..."
hubble status

echo "Setting up ArgoCD..."

if ! kubectl get namespace argocd &> /dev/null; then
    echo "Creating argocd namespace..."
    kubectl create namespace argocd
else
    echo "Namespace 'argocd' already exists, skipping creation."
fi

helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

if ! helm status argocd -n argocd &> /dev/null; then
    echo "Installing ArgoCD via Helm..."
    helm upgrade --install argocd argo/argo-cd --version 8.0.0 -n argocd --values argo-values.yaml
    kubectl rollout status -n argocd deploy/argocd-server

    # TODO: debug password reset
    echo "Setting default ArgoCD admin password to 'admin123'..." 
    kubectl --context $CONTEXT patch secret -n argocd argocd-secret \
  -p '{"stringData": { "admin.password": "'$(htpasswd -bnBC 10 "" admin123 | tr -d ':\n')'"}}'

    echo "ArgoCD installed on kind cluster with username/password admin/admin123"
else
    echo "ArgoCD already installed, skipping installation."
fi

if ! kubectl get application sample-apps -n argocd &> /dev/null; then
    echo "Installing ArgoCD application..."
    kubectl apply -f argo-application.yaml
else
    echo "ArgoCD application 'sample-apps' already exists, skipping creation."
fi

# --- Check for OpenAI API Key ---
if [ -z "$OPENAI_API_KEY" ]; then
    echo "Error: OPENAI_API_KEY environment variable is not set."
    echo "Please set it before running this script: export OPENAI_API_KEY='your-api-key'"
    exit 1
else
    echo "OPENAI_API_KEY is set."
fi

# --- Check for GitHub PAT and Create Secret ---
if [ -z "$GH_PAT" ]; then
    echo "Error: GH_PAT environment variable is not set."
    echo "Please set it before running this script: export GH_PAT='your-github-pat'"
    exit 1
else
    echo "GH_PAT is set."
    if ! kubectl get secret github-pat-secret -n kagent &> /dev/null; then
        echo "Creating github-pat-secret..."
        kubectl create secret generic github-pat-secret --from-literal=GH_PAT="$GH_PAT" -n kagent
    else
        echo "Secret 'github-pat-secret' already exists, skipping creation."
    fi
fi

# --- Check for kagent installation ---
if ! kubectl get crd agents.kagent.dev &> /dev/null; then
    echo "kagent CRD 'agents.kagent.dev' not found."
    echo "Please run the interactive 'kagent' CLI and type 'install' to set it up."
    echo "Then, re-run this script."
    exit 1
else
    echo "kagent CRD found, skipping installation."
fi

# --- Apply GitHub Toolserver ---
echo "Applying GitHub toolserver..."
kubectl apply -f gh-server.yaml

echo "Setup complete!"
