#!/usr/bin/env bash
# scripts/smoke-test.sh — Post-deploy smoke tests
# Usage: ./smoke-test.sh <base_url>
set -euo pipefail

BASE_URL=${1:?Usage: smoke-test.sh <base_url>}
PASS=0
FAIL=0

check() {
  local desc=$1
  local url=$2
  local expected_status=${3:-200}
  local expected_body=${4:-}

  local status
  local body
  body=$(curl -sf --retry 3 --retry-delay 2 \
    -o /tmp/smoke_body \
    -w "%{http_code}" \
    "${url}" 2>/dev/null) || status=$?

  status=$(cat /dev/stdin <<< "${body}" 2>/dev/null || echo "${body}")

  if [[ "${status}" == "${expected_status}" ]]; then
    if [[ -z "${expected_body}" ]] || grep -q "${expected_body}" /tmp/smoke_body; then
      echo "  ✅ ${desc}"
      ((PASS++)) || true
    else
      echo "  ❌ ${desc} — body missing '${expected_body}'"
      ((FAIL++)) || true
    fi
  else
    echo "  ❌ ${desc} — got HTTP ${status}, expected ${expected_status}"
    ((FAIL++)) || true
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 Smoke Tests → ${BASE_URL}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

check "Health endpoint"       "${BASE_URL}/health"       200 '"status":"ok"'
check "Liveness probe"        "${BASE_URL}/health/live"  200 '"alive":true'
check "Readiness probe"       "${BASE_URL}/health/ready" 200 '"ready":true'
check "API hello"             "${BASE_URL}/api/hello"    200 '"message"'

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Passed: ${PASS}  Failed: ${FAIL}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ "${FAIL}" -gt 0 ]]; then
  echo "💥 Smoke tests failed!"
  exit 1
fi
echo "🎉 All smoke tests passed!"
