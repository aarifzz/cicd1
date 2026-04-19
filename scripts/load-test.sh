#!/usr/bin/env bash
# scripts/load-test.sh — k6 load test wrapper
# Usage: ./load-test.sh <base_url>
set -euo pipefail

BASE_URL=${1:?Usage: load-test.sh <base_url>}

echo "⚡ Running load tests against ${BASE_URL}"

# Install k6 if not present
if ! command -v k6 &>/dev/null; then
  echo "📦 Installing k6..."
  curl -sSL https://github.com/grafana/k6/releases/download/v0.49.0/k6-v0.49.0-linux-amd64.tar.gz \
    | tar -xz -C /usr/local/bin --strip-components=1 k6-v0.49.0-linux-amd64/k6
fi

k6 run - <<EOF
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '30s', target: 20 },   // ramp up
    { duration: '60s', target: 20 },   // hold
    { duration: '10s', target: 0 },    // ramp down
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'],  // 95% of requests under 500ms
    http_req_failed: ['rate<0.01'],    // <1% failure rate
  },
};

export default function () {
  const res = http.get('${BASE_URL}/health');
  check(res, {
    'status is 200': (r) => r.status === 200,
    'response time OK': (r) => r.timings.duration < 500,
  });
  sleep(1);
}
EOF

echo "✅ Load tests complete"
