#!/usr/bin/env bash
# scripts/deploy-bluegreen.sh — Blue/Green production deployment
# Usage: ./deploy-bluegreen.sh prod <version>
set -euo pipefail

ENV=${1:?Usage: deploy-bluegreen.sh <env> <version>}
VERSION=${2:?Usage: deploy-bluegreen.sh <env> <version>}
NAMESPACE="app-${ENV}"
IMAGE="ghcr.io/your-org/your-repo:${VERSION}"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🟢 Blue/Green Deploy → ${ENV}"
echo "   Version : ${VERSION}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

mkdir -p ~/.kube
echo "${KUBE_CONFIG}" | base64 -d > ~/.kube/config
chmod 600 ~/.kube/config

# Detect current active slot (blue or green)
CURRENT=$(kubectl get service app-service \
  -n "${NAMESPACE}" \
  -o jsonpath='{.spec.selector.slot}' 2>/dev/null || echo "blue")

if [[ "${CURRENT}" == "blue" ]]; then
  NEW_SLOT="green"
else
  NEW_SLOT="blue"
fi

echo "   Current slot : ${CURRENT}"
echo "   New slot     : ${NEW_SLOT}"

# Deploy to the inactive slot
kubectl set image deployment/"app-${NEW_SLOT}" \
  app="${IMAGE}" \
  -n "${NAMESPACE}"

echo "⏳ Waiting for ${NEW_SLOT} slot to be ready..."
kubectl rollout status deployment/"app-${NEW_SLOT}" \
  -n "${NAMESPACE}" --timeout=5m

# Quick health check on new slot (internal)
NEW_POD=$(kubectl get pods -n "${NAMESPACE}" \
  -l "slot=${NEW_SLOT}" \
  -o jsonpath='{.items[0].metadata.name}')

echo "🔍 Verifying new slot pod: ${NEW_POD}"
kubectl exec "${NEW_POD}" -n "${NAMESPACE}" -- \
  wget -qO- http://localhost:3000/health/ready

# Switch traffic to new slot
echo "🔀 Switching traffic to ${NEW_SLOT}..."
kubectl patch service app-service \
  -n "${NAMESPACE}" \
  --type='json' \
  -p="[{\"op\":\"replace\",\"path\":\"/spec/selector/slot\",\"value\":\"${NEW_SLOT}\"}]"

echo "✅ Traffic now routed to ${NEW_SLOT} (${VERSION})"
echo "   Old slot '${CURRENT}' kept warm for quick rollback."
