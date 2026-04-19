#!/usr/bin/env bash
# scripts/deploy.sh — Rolling Kubernetes deployment
# Usage: ./deploy.sh <environment> <version>
set -euo pipefail

ENV=${1:?Usage: deploy.sh <env> <version>}
VERSION=${2:?Usage: deploy.sh <env> <version>}
NAMESPACE="app-${ENV}"
DEPLOYMENT="app"
IMAGE="ghcr.io/your-org/your-repo:${VERSION}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Deploying to: ${ENV}"
echo "   Version     : ${VERSION}"
echo "   Namespace   : ${NAMESPACE}"
echo "   Image       : ${IMAGE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Write kubeconfig from env
mkdir -p ~/.kube
echo "${KUBE_CONFIG}" | base64 -d > ~/.kube/config
chmod 600 ~/.kube/config

# Ensure namespace exists
kubectl get namespace "${NAMESPACE}" 2>/dev/null || \
  kubectl create namespace "${NAMESPACE}"

# Apply env-specific manifests
kubectl apply -f k8s/base/ -n "${NAMESPACE}"
kubectl apply -f "k8s/overlays/${ENV}/" -n "${NAMESPACE}"

# Update image and trigger rolling deployment
kubectl set image deployment/"${DEPLOYMENT}" \
  app="${IMAGE}" \
  -n "${NAMESPACE}"

# Annotate for audit trail
kubectl annotate deployment/"${DEPLOYMENT}" \
  "deployment.kubernetes.io/revision"="$(date +%s)" \
  "deployment.kubernetes.io/version"="${VERSION}" \
  "deployment.kubernetes.io/actor"="${GITHUB_ACTOR:-ci}" \
  -n "${NAMESPACE}" --overwrite

# Wait for rollout
echo "⏳ Waiting for rollout to complete..."
kubectl rollout status deployment/"${DEPLOYMENT}" \
  -n "${NAMESPACE}" \
  --timeout=5m

echo "✅ Deployment successful!"
kubectl get pods -n "${NAMESPACE}" -l app="${DEPLOYMENT}"
