#!/usr/bin/env bash
# scripts/rollback.sh — Instant Kubernetes rollback
# Usage: ./rollback.sh <environment> [version]
set -euo pipefail

ENV=${1:?Usage: rollback.sh <env> [version]}
VERSION=${2:-}          # Optional: specific version to roll back to
NAMESPACE="app-${ENV}"
DEPLOYMENT="app"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 ROLLBACK initiated"
echo "   Environment : ${ENV}"
echo "   Target ver  : ${VERSION:-previous}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p ~/.kube
echo "${KUBE_CONFIG}" | base64 -d > ~/.kube/config
chmod 600 ~/.kube/config

if [[ -n "${VERSION}" ]]; then
  # Roll back to specific image version
  IMAGE="ghcr.io/your-org/your-repo:${VERSION}"
  echo "⏪ Rolling back to specific version: ${IMAGE}"
  kubectl set image deployment/"${DEPLOYMENT}" \
    app="${IMAGE}" \
    -n "${NAMESPACE}"
else
  # Roll back to previous revision
  echo "⏪ Rolling back to previous revision..."
  kubectl rollout undo deployment/"${DEPLOYMENT}" \
    -n "${NAMESPACE}"
fi

echo "⏳ Waiting for rollback to stabilize..."
kubectl rollout status deployment/"${DEPLOYMENT}" \
  -n "${NAMESPACE}" --timeout=3m

CURRENT_IMAGE=$(kubectl get deployment "${DEPLOYMENT}" \
  -n "${NAMESPACE}" \
  -o jsonpath='{.spec.template.spec.containers[0].image}')

echo "✅ Rollback complete. Running image: ${CURRENT_IMAGE}"
kubectl get pods -n "${NAMESPACE}" -l app="${DEPLOYMENT}"
