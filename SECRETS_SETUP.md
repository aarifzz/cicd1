# GitHub Repository Secrets & Environments Setup Guide

## Required GitHub Secrets

Go to: Settings → Secrets and Variables → Actions

### Global Secrets (all environments)
| Secret | Description |
|--------|-------------|
| `SLACK_WEBHOOK` | Slack Incoming Webhook URL for deployment notifications |

### Per-Environment Secrets
Configure these under Settings → Environments for each env (`development`, `staging`, `production`):

#### Development
| Secret | Description |
|--------|-------------|
| `DEV_KUBE_CONFIG` | Base64-encoded kubeconfig for dev cluster |
| `DEV_DB_URL` | PostgreSQL connection string for dev |
| `DEV_APP_SECRET` | App secret key for dev |

#### Staging
| Secret | Description |
|--------|-------------|
| `STAGING_KUBE_CONFIG` | Base64-encoded kubeconfig for staging cluster |
| `STAGING_DB_URL` | PostgreSQL connection string for staging |
| `STAGING_APP_SECRET` | App secret key for staging |

#### Production
| Secret | Description |
|--------|-------------|
| `PROD_KUBE_CONFIG` | Base64-encoded kubeconfig for prod cluster |
| `PROD_DB_URL` | PostgreSQL connection string for production |
| `PROD_APP_SECRET` | App secret key for production |
| `AWS_ACCESS_KEY_ID` | AWS key for S3 DB snapshots |
| `AWS_SECRET_ACCESS_KEY` | AWS secret for S3 DB snapshots |
| `ALLOW_PROD_MIGRATION` | Set to `true` to allow DB migrations in prod |

## Encoding kubeconfig

```bash
cat ~/.kube/config | base64 | pbcopy   # macOS
cat ~/.kube/config | base64 | xclip    # Linux
```

## Branch → Environment Mapping

| Branch / Ref | Environment | URL |
|---|---|---|
| `develop` or PR | `development` | https://dev.yourapp.com |
| `staging` | `staging` | https://staging.yourapp.com |
| `v*.*.*` tag | `production` | https://yourapp.com |

## How to Release to Production

```bash
git checkout main
git pull origin main
git tag v1.2.3
git push origin v1.2.3
```

This triggers the full pipeline: quality → security → build → prod deploy.

## Manual Rollback

Go to Actions → Manual Rollback → Run workflow
- Select environment
- Enter target version (e.g. `v1.2.2` or `sha-abc123`)
- Enter reason for audit log
