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
if ! cilium status | grep -q "Hubble:.*Enabled"; then
    echo "Enabling Cilium Hubble..."
    cilium hubble enable --ui
    echo "Waiting for Hubble to be ready..."
    sleep 20
else
    echo "Cilium Hubble is already enabled, skipping."
fi

# --- Port-forward for Hubble ---
if ! pgrep -f "cilium hubble port-forward" > /dev/null; then
    echo "Port-forwarding for Hubble..."
    cilium hubble port-forward &
    echo "Waiting for port-forwarding to be set up..."
    sleep 5
else
    echo "Hubble port-forwarding is already running, skipping."
fi

echo "Checking Hubble status..."
hubble status

# --- Check for OpenAI API Key ---
if [ -z "$OPENAI_API_KEY" ]; then
    echo "Error: OPENAI_API_KEY environment variable is not set."
    echo "Please set it before running this script: export OPENAI_API_KEY='your-api-key'"
    exit 1
else
    echo "OPENAI_API_KEY is set."
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

echo "Getting kagent agents..."
kubectl get agents.kagent.dev -n kagent
echo "Setup complete!"