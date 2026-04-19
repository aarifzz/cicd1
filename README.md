# 🚀 One-Click CI/CD Pipeline

A production-ready, fully automated deployment pipeline with zero-downtime releases, gated migrations, blue/green deployments, and one-click rollback.

---

## 📐 Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Actions                           │
│                                                                 │
│  Push/PR        ┌──────────┐   ┌──────────┐   ┌────────────┐  │
│  ───────────►   │ Quality  │──►│ Security │──►│   Build    │  │
│                 │  Gates   │   │   Scan   │   │ & Publish  │  │
│                 └──────────┘   └──────────┘   └─────┬──────┘  │
│                                                      │         │
│           ┌──────────────────────────────────────────┤         │
│           │              Branch routing              │         │
│           │                                          │         │
│   develop ▼           staging ▼           tag v* ▼  │         │
│  ┌────────────┐   ┌────────────┐   ┌──────────────┐ │         │
│  │  Deploy    │   │  Deploy    │   │    Deploy    │ │         │
│  │    DEV     │   │  STAGING   │   │  PRODUCTION  │ │         │
│  │            │   │            │   │ (Blue/Green) │ │         │
│  │ • Migrate  │   │ • Migrate  │   │ • DB Snapshot│ │         │
│  │ • Smoke ✓  │   │ • Integr ✓ │   │ • Migrate    │ │         │
│  │            │   │ • Load   ✓ │   │ • Smoke ✓    │ │         │
│  └────────────┘   └────────────┘   │ • Rollback ↩ │ │         │
│                                    └──────────────┘ │         │
└─────────────────────────────────────────────────────────────────┘
```

## ✨ Features

| Feature | Detail |
|---|---|
| **Dependency caching** | npm cache keyed on `package-lock.json` hash — fast installs |
| **Quality gates** | ESLint + TypeScript type-check + Jest unit tests with 80% coverage threshold |
| **Security scanning** | npm audit + TruffleHog secret detection on every PR |
| **Versioned Docker images** | Multi-stage build, SHA + semver tags, SBOM generation |
| **Environment promotion** | `develop` → DEV · `staging` → STAGING · `v*` tag → PROD |
| **Blue/Green production deploy** | Zero-downtime; old slot kept warm for instant rollback |
| **Gated DB migrations** | golang-migrate with prod gate flag; snapshot to S3 before running |
| **One-click rollback** | Manual workflow + automatic rollback on deploy failure |
| **Smoke & integration tests** | Automated post-deploy validation |
| **Alerting** | Prometheus alerts for error rate, latency, crash-loops |

---

## 🚦 Quick Start (Local)

### Prerequisites
- Docker & Docker Compose
- Node.js 20+

```bash
# 1. Clone and enter the project
git clone <your-repo>
cd cicd-pipeline

# 2. Set up local environment
cp .env.example .env

# 3. Start all services
docker compose up -d

# 4. Verify
curl http://localhost/health
# → {"status":"ok","version":"local",...}

# 5. Run tests locally
cd app
npm install
npm test
```

---

## 🌿 Branch → Environment Flow

```
feature/xyz  →  PR  →  [quality gates run]
                  ↓
              develop  →  DEV    (auto-deploy)
                  ↓
              staging  →  STAGING (auto-deploy + load tests)
                  ↓
          git tag v1.2.3  →  PRODUCTION (blue/green + gated)
```

---

## 🚀 Releasing to Production

```bash
# Ensure main is clean and tested
git checkout main && git pull

# Tag a semantic version — this triggers the full prod pipeline
git tag v1.2.3
git push origin v1.2.3
```

The pipeline will:
1. Run all quality gates and security scans
2. Build and push a versioned Docker image
3. Snapshot the production database
4. Run migrations (requires `ALLOW_PROD_MIGRATION=true` secret)
5. Blue/green deploy with health checks
6. Run smoke tests
7. Auto-rollback if smoke tests fail
8. Notify Slack on success or failure

---

## 🔄 Rolling Back

### Automatic
If post-deploy smoke tests fail, the pipeline rolls back automatically.

### Manual (via GitHub Actions UI)
1. Go to **Actions** → **Manual Rollback**
2. Click **Run workflow**
3. Choose: environment, target version, reason
4. The team gets a Slack notification with full audit trail

### CLI
```bash
# Rollback to previous revision
bash scripts/rollback.sh prod

# Rollback to specific version
bash scripts/rollback.sh prod v1.2.2
```

---

## 🗄️ Database Migrations

Migrations live in `migrations/` as numbered up/down pairs:

```
migrations/
  000001_create_users.up.sql
  000001_create_users.down.sql
  000002_add_sessions.up.sql
  000002_add_sessions.down.sql
```

**Adding a migration:**
```bash
# Create next numbered pair
touch migrations/000003_add_feature.up.sql
touch migrations/000003_add_feature.down.sql
```

**Manual run:**
```bash
DB_URL=postgres://... bash scripts/migrate.sh dev
```

**Production safety:**
- A DB snapshot is taken to S3 before any prod migration
- `ALLOW_PROD_MIGRATION=true` must be set as a GitHub environment secret
- Down migrations are always provided for rollback

---

## 📁 Project Structure

```
cicd-pipeline/
├── .github/
│   └── workflows/
│       ├── ci-cd.yml          # Main pipeline
│       └── rollback.yml       # Manual rollback workflow
├── app/
│   ├── src/
│   │   ├── index.ts           # Express app entry
│   │   └── routes/
│   │       ├── health.ts      # /health endpoints
│   │       └── api.ts         # /api endpoints
│   ├── tests/
│   │   └── app.test.ts        # Unit/integration tests
│   ├── Dockerfile             # Multi-stage production build
│   ├── package.json
│   └── tsconfig.json
├── k8s/
│   ├── base/                  # Base Kubernetes manifests
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   └── hpa.yaml
│   └── overlays/              # Per-environment overrides
│       ├── dev/
│       ├── staging/
│       └── prod/
├── migrations/                # SQL up/down migration files
├── monitoring/
│   ├── prometheus.yml         # Scrape config
│   └── alerts.yml             # Alert rules
├── nginx/
│   └── local.conf             # Local reverse-proxy config
├── scripts/
│   ├── deploy.sh              # Rolling Kubernetes deploy
│   ├── deploy-bluegreen.sh    # Blue/green production deploy
│   ├── rollback.sh            # Instant rollback
│   ├── migrate.sh             # Gated DB migrations
│   ├── db-snapshot.sh         # Pre-migration S3 snapshot
│   ├── smoke-test.sh          # Post-deploy smoke tests
│   ├── integration-test.sh    # Full integration suite
│   └── load-test.sh           # k6 load tests
├── docker-compose.yml         # Local dev environment
├── .env.example               # Environment template
├── SECRETS_SETUP.md           # GitHub Secrets config guide
└── README.md
```

---

## 🔐 Secrets Setup

See [SECRETS_SETUP.md](./SECRETS_SETUP.md) for the full list of required GitHub Secrets and how to configure them.

---

## 📊 Monitoring

The pipeline ships Prometheus alert rules for:
- **High 5xx error rate** (> 5% over 5 min → critical)
- **High P95 latency** (> 500ms over 5 min → warning)
- **Pod crash-looping** (any restarts → critical)
- **Replica mismatch** (unavailable pods → warning)

Connect your Grafana instance to Prometheus and import a Node.js dashboard (ID `11159`) for instant observability.

---

## 🤝 Contributing

1. Branch from `develop`
2. Open a PR → quality gates run automatically
3. Merge to `develop` → auto-deploys to DEV
4. Promote to `staging` branch for staging validation
5. Tag a version for production release
