#!/bin/bash

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
     kind create cluster --name "$CLUSTER_NAME"
 fi

# --- Apply demo app ---
docker pull docker.io/linsun/demo:v2
docker pull docker.io/curlimages/curl
docker pull docker.io/linsun/rag:v1
docker pull docker.io/linsun/rag:v2

kind load docker-image docker.io/linsun/demo:v2
kind load docker-image docker.io/curlimages/curl

echo "Applying the Kubernets manifests..."
kubectl apply -f kubernetes/client.yaml

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
if [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: GITHUB_TOKEN environment variable is not set."
    echo "Please set it before running this script: export GITHUB_TOKEN='your-github-pat'"
    exit 1
else
    echo "GITHUB_TOKEN is set."
    if ! kubectl get secret github-pat-secret -n kagent &> /dev/null; then
        echo "Creating github-pat-secret with GITHUB_TOKEN..."
        kubectl create secret generic github-pat-secret \
          --from-literal=GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_TOKEN" \
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

# --- Pull the llama resources if using in cluster setup ---
# kubectl exec -it deploy/client -- curl http://ollama.ollama:11434/api/pull -d '{"name": "llama3.2"}'
# kubectl exec -it deploy/client -- curl http://ollama.ollama:11434/api/pull -d '{"name": "llava"}'

# --- Apply kgateway resources ---
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.3.0/experimental-install.yaml

helm upgrade -i --create-namespace --namespace kgateway-system --version v2.1.0-main \
kgateway-crds oci://cr.kgateway.dev/kgateway-dev/charts/kgateway-crds

helm upgrade -i --namespace kgateway-system --version v2.1.0-main kgateway oci://cr.kgateway.dev/kgateway-dev/charts/kgateway --set agentgateway.enabled=true --set inferenceExtension.enabled=true


