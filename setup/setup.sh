#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e
set -o pipefail
 
 # Cluster name can be overridden via environment; default to "kind"
 CLUSTER_NAME=${CLUSTER_NAME:-kind}

# --- Check for Kind Cluster ---
 # Capture active clusters
 activeClusters=$(kind get clusters 2>/dev/null || true)
 
 # If the desired kind cluster exists already, skip creation
 if [[ "$activeClusters" =~ (^|[[:space:]])"$CLUSTER_NAME"($|[[:space:]]) ]]; then
     echo "Kind cluster '$CLUSTER_NAME' already exists, skipping creation."
 else
     echo "Creating kind cluster '$CLUSTER_NAME'..."
     kind create cluster --name "$CLUSTER_NAME" --config kind-config.yaml
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
    helm upgrade --install argocd argo/argo-cd --version 8.0.0 -n argocd --values argo-values.yaml --wait
    kubectl rollout status -n argocd deploy/argocd-server

    # TODO: debug password reset
    echo "Setting default ArgoCD admin password to 'admin123'..." 
    kubectl patch secret -n argocd argocd-secret \
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

# --- Install kagent (CRDs and controller) ---
if ! kubectl get crd agents.kagent.dev &> /dev/null; then
    echo "kagent CRDs not found. Installing kagent CRDs via Helm (OCI)..."
    helm upgrade --install kagent-crds oci://ghcr.io/kagent-dev/kagent/helm/kagent-crds \
        --namespace kagent \
        --create-namespace \
        --wait
else
    echo "kagent CRDs already present. Ensuring they are up to date..."
    helm upgrade --install kagent-crds oci://ghcr.io/kagent-dev/kagent/helm/kagent-crds \
        --namespace kagent \
        --create-namespace \
        --wait
fi

echo "Installing/Upgrading kagent via Helm (OCI)..."
helm upgrade --install kagent oci://ghcr.io/kagent-dev/kagent/helm/kagent \
    --namespace kagent \
    --set providers.default=openAI \
    --set providers.openAI.apiKey="$OPENAI_API_KEY" \
    --wait

# --- Check for GitHub token and create Secret ---
if [ -z "$GITHUB_PERSONAL_ACCESS_TOKEN" ]; then
    echo "Error: GITHUB_PERSONAL_ACCESS_TOKEN environment variable is not set."
    echo "Please set it before running this script: export GITHUB_PERSONAL_ACCESS_TOKEN='your-github-pat'"
    exit 1
else
    echo "GITHUB_PERSONAL_ACCESS_TOKEN is set."
    if ! kubectl get secret github-pat-secret -n kagent &> /dev/null; then
        echo "Creating github-pat-secret with GITHUB_PERSONAL_ACCESS_TOKEN..."
        kubectl create secret generic github-pat-secret \
          --from-literal=GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_PERSONAL_ACCESS_TOKEN" \
          -n kagent
    else
        echo "Secret 'github-pat-secret' already exists, ensuring required key is present..."
        if ! kubectl get secret github-pat-secret -n kagent -o jsonpath='{.data.GITHUB_PERSONAL_ACCESS_TOKEN}' | grep -q .; then
            echo "Patching secret to add GITHUB_PERSONAL_ACCESS_TOKEN..."
            kubectl patch secret github-pat-secret -n kagent \
              --type=merge \
              -p '{"stringData": {"GITHUB_PERSONAL_ACCESS_TOKEN": "'$GITHUB_PERSONAL_ACCESS_TOKEN'"}}'
        else
            echo "Key GITHUB_PERSONAL_ACCESS_TOKEN already present."
        fi
    fi
fi

echo "Setup complete!"
