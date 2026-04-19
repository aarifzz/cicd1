#!/usr/bin/env bash
# scripts/integration-test.sh — Full integration test suite
# Usage: ./integration-test.sh <base_url>
set -euo pipefail

BASE_URL=${1:?Usage: integration-test.sh <base_url>}
PASS=0
FAIL=0
ERRORS=()

log_pass() { echo "  ✅ $1"; ((PASS++)) || true; }
log_fail() { echo "  ❌ $1"; ERRORS+=("$1"); ((FAIL++)) || true; }

assert_json_field() {
  local desc=$1 url=$2 field=$3 expected=$4
  local actual
  actual=$(curl -sf "${url}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('${field}','__missing__'))" 2>/dev/null)
  if [[ "${actual}" == "${expected}" ]]; then
    log_pass "${desc}"
  else
    log_fail "${desc} — expected '${expected}', got '${actual}'"
  fi
}

assert_http() {
  local desc=$1 url=$2 expected_code=${3:-200}
  local actual_code
  actual_code=$(curl -so /dev/null -w "%{http_code}" "${url}")
  if [[ "${actual_code}" == "${expected_code}" ]]; then
    log_pass "${desc}"
  else
    log_fail "${desc} — expected HTTP ${expected_code}, got ${actual_code}"
  fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔬 Integration Tests → ${BASE_URL}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "── Health & Observability ──────────────"
assert_json_field "Health status is 'ok'"   "${BASE_URL}/health"       status ok
assert_json_field "Liveness returns true"   "${BASE_URL}/health/live"  alive  True
assert_json_field "Readiness returns true"  "${BASE_URL}/health/ready" ready  True
assert_http       "404 on unknown route"    "${BASE_URL}/does-not-exist" 404

echo ""
echo "── API Endpoints ───────────────────────"
assert_http "GET /api/hello returns 200"  "${BASE_URL}/api/hello" 200

echo ""
echo "── Security Headers ────────────────────"
HEADERS=$(curl -sI "${BASE_URL}/health")
if echo "${HEADERS}" | grep -qi "x-content-type-options"; then
  log_pass "X-Content-Type-Options header present"
else
  log_fail "X-Content-Type-Options header missing"
fi
if echo "${HEADERS}" | grep -qi "x-frame-options"; then
  log_pass "X-Frame-Options header present"
else
  log_fail "X-Frame-Options header missing"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Passed: ${PASS}  Failed: ${FAIL}"
if [[ "${FAIL}" -gt 0 ]]; then
  echo ""
  echo "  Failed tests:"
  for e in "${ERRORS[@]}"; do echo "    • ${e}"; done
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 1
fi
echo "🎉 All integration tests passed!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
