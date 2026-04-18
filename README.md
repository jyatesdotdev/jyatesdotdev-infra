# jyatesdotdev-infra

Terraform IaC for [jyates.dev](https://jyates.dev) — a fully serverless portfolio site on AWS.

## Architecture

- **DNS**: Name.com delegates to Route53. Includes iCloud Mail MX/DKIM records and SES subdomain.
- **CDN**: CloudFront serves the S3 static site (default origin) and routes `/api/*` to API Gateway. A CloudFront Function rewrites directory paths to `index.html` for SPA support and handles `blog.jyates.dev` subdomain rewriting. Only 404 errors trigger the SPA fallback (not 403) — this is intentional so API error responses pass through correctly.
- **Compute**: API Gateway (REST, stage `v1`) → Lambda (Go, ARM64). Four functions: interactions, contact, admin, authorizer. CloudFront's `origin_path = "/v1"` prepends the stage name, so a request to `/api/v1/likes` arrives at API Gateway as `/v1/api/v1/likes` (stage `v1`, resource `/api/v1/likes`).
- **Storage**: DynamoDB (on-demand) for likes/comments. S3 for static site and access logs.
- **Email**: SES sends from `blog@jyates.dev` to `me@jyates.dev` for contact form and comment notifications. Production access requested 2026-04-18; sandbox until approved (only affects sending to unverified addresses).
- **Security**: WAFv2 rate limiting, API key on API Gateway (injected by CloudFront custom header), KMS encryption on DynamoDB, CSP headers via CloudFront response headers policy.
- **Auth**: Admin endpoints use Basic Auth via a custom Lambda authorizer. Credentials stored in SSM Parameter Store (auto-generated password).
- **Observability**: CloudWatch RUM (real `aws-rum-web` SDK via Cognito Identity Pool for unauthenticated browser access), CloudWatch Dashboard, CloudFront access logs.
- **CI/CD Security**: Checkov IaC scanning with SARIF upload to GitHub Security tab.

## How It Works

This repo does **not** deploy on push. It is triggered by:

1. **`repository_dispatch`** from `jyatesdotdev-api` — after the API builds and uploads Lambda zips to S3, it dispatches here with the artifact locations. Terraform updates the Lambda function code.
2. **`workflow_dispatch`** — manual trigger. When deploying infra-only changes (no Lambda code update), you must provide the current Lambda artifact parameters (see below).

A `concurrency` group ensures only one Terraform apply runs at a time. Queued runs wait rather than racing for the state lock.

## Manual Deployment

When triggering manually via `workflow_dispatch`, you need to provide the Lambda artifact parameters to avoid empty s3_bucket/s3_key errors. Find the latest artifacts:

```bash
aws s3 ls s3://<artifacts-bucket>/lambdas/ \
  --profile portfolio --region us-west-2
```

Then trigger with the latest SHA prefix:

```bash
BUCKET="<artifacts-bucket>"
SHA="<latest-sha-from-above>"

gh workflow run deploy.yml --repo jyatesdotdev/jyatesdotdev-infra --ref main \
  -f artifact_bucket="$BUCKET" \
  -f interactions_lambda_key="lambdas/${SHA}/interactions.zip" \
  -f contact_lambda_key="lambdas/${SHA}/contact.zip" \
  -f admin_lambda_key="lambdas/${SHA}/admin.zip" \
  -f authorizer_lambda_key="lambdas/${SHA}/authorizer.zip"
```

If you only need to deploy infra changes without touching Lambda code, you can also trigger the API workflow first (which will dispatch to infra with the correct artifact vars automatically):

```bash
gh workflow run deploy.yml --repo jyatesdotdev/jyatesdotdev-api --ref main
```

## State Lock Issues

Terraform uses S3-based locking. If a run fails mid-apply and leaves a stale lock:

```bash
aws s3 rm s3://<state-bucket>/state/terraform.tfstate.tflock \
  --profile portfolio --region us-east-1
```

## Required Secrets & Variables

### Secrets
| Secret | Description |
|---|---|
| `AWS_ROLE_ARN` | GitHub OIDC deploy role ARN |
| `RECAPTCHA_SECRET` | Google reCAPTCHA v3 server key |
| `ADMIN_USERNAME` | Admin area username |
| `NAMEDOTCOM_USERNAME` | Name.com API username |
| `NAMEDOTCOM_TOKEN` | Name.com API token |

### Key Resources

Resource identifiers (account ID, bucket names, distribution IDs) are intentionally omitted from this public README. Refer to terraform state or AWS console for operational reference.
