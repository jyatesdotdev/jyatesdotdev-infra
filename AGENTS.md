# jyatesdotdev-infra — Terraform for jyates.dev

Flat root module + 8 local child modules (each is a single self-contained
`<name>/main.tf` with its own vars/outputs). State: S3 backend
`jyatesdotdev-terraform-state` in us-east-1 with **native S3 locking**
(`use_lockfile = true`; a stale lock is `state/terraform.tfstate.tflock`).

Two AWS providers: default = `var.aws_region` (us-west-2) and alias **`aws.us_east_1`**.
The OIDC provider, deploy role, artifacts bucket, and state bucket live in a separate
private bootstrap repo — not here.

## ⚠️ Before you apply ANYTHING

1. **Never blind-apply `route53.tf`** — `namedotcom_domain_nameservers` rewrites live
   domain delegation at the registrar; a bad plan breaks DNS (site AND email) for
   jyates.dev.
2. **ACM cert, WAF, and CloudFront resources must stay on `aws.us_east_1`** — CloudFront
   only accepts us-east-1 certs/ACLs. Do not "clean up" the provider alias.
3. **`random_password.api_key` and `random_password.admin_password` live in state.**
   Destroying/recreating them rotates real secrets (CloudFront→APIGW key, admin login).
4. **`rum_budget_guard` is a real kill-switch**: at $10/mo RUM spend a budget action
   attaches an IAM Deny to the RUM role; a monthly EventBridge-triggered Lambda
   (`jyatesdotdev-rum-budget-reset`) is the ONLY thing that removes it. Don't delete
   either half.
5. Deliberately tiny limits for cost control — don't "fix" them: API Gateway throttle
   20 rps / 40 burst; WAF rate limit **500 req/5min per IP** (AWS minimum is 100);
   account-wide $10/mo budget in `budgets.tf` (separate from the RUM budget).
6. SES is in **sandbox** — only verified identities receive mail.

## Module map

`s3` (site + logs buckets, OAC-only policy) · `cloudfront` (distribution, CloudFront
Functions for /admin basic-auth + blog-subdomain/index rewrites, response-headers policy
with CSP, WAF) · `api_gateway` (REST API, stage `v1`, TOKEN authorizer, API key) ·
`lambda` (4 Go functions from S3 artifacts: interactions/contact/admin/authorizer, SSM
admin params) · `dynamodb` (`jyatesdotdev-state`, PK/SK + GSI1, PAY_PER_REQUEST) ·
`ses` (domain identity + DKIM) · `cloudwatch_rum` (app monitor, 100% sampling, Cognito
unauth role) · `rum_budget_guard` (budget kill-switch + reset Lambda).

Root files: `acm.tf` (cert, us-east-1), `route53.tf` (zone, delegation, DKIM/SPF/DMARC/
iCloud mail records), `budgets.tf`, `dashboard.tf` (dashboard references resource names
as string literals — keep in sync if renaming).

## Quirks

- **CSP is inline in `cloudfront/main.tf`** — any new external script/connect origin the
  frontend needs must be added there or it breaks silently (browser console only).
  Currently only 'self' + *.amazonaws.com (RUM) are allowed.
- **`origin_path = "/v1"` double-prefix**: `/api/v1/likes` arrives at API Gateway as
  `/v1/api/v1/likes`. Intentional — do not "fix" resource paths.
- The CloudFront basic-auth function bakes the base64 password into function code, and
  the API key rides a plaintext `x-api-key` origin header — both are in state by design.
- The `subdomain_rewrite` function hardcodes `blog.jyates.dev`.
- SPA fallback maps 404→200 `/index.html` (404 only, not 403 — intentional).
- **`aws_cloudfront_cache_policy.api_with_geo_headers` has `max_ttl = 1`, not 0** —
  it whitelists the CloudFront-Viewer-* geo headers so they reach the API origin
  (powers the visitor map / whereami), and CloudFront rejects header whitelisting on a
  cache policy with caching fully disabled (all TTLs 0). `default_ttl` is 0 and the API
  sends no Cache-Control, so nothing is actually cached. Don't "simplify" it back to 0.

## Scripts

`scripts/backfill_rum_geo.py` — one-time import of CloudWatch RUM history into the
visitor-map counters (distinct sessions per country → STATS#GEO items). Idempotent
via a `BACKFILL#<tag>` marker item guarded by `attribute_not_exists`; re-runs skip.
Uses the AWS CLI (no boto3). Already applied once with tag `rum-30d`.

## Commands / CI

- Local: plain `terraform init/plan/apply` — no wrapper scripts, no tfvars file; apply
  needs many `-var` values (artifact bucket + 4 lambda keys, secrets). In practice,
  **deploys happen via CI, not locally** — prefer `terraform plan` locally and let CI apply.
- CI `deploy.yml` runs ONLY on `repository_dispatch` (`deploy_api`/`deploy_frontend`,
  sent by the API repo) or manual dispatch — never on push. It runs
  `apply -auto-approve`, serialized by a `terraform-apply` concurrency group.
- `checkov.yml` runs `terraform fmt -check` + `validate` (hard gates) and a Checkov scan
  (soft-fail) on push/PR + weekly. Run `terraform fmt -recursive` before committing.
- `.terraform.lock.hcl` is committed — after changing provider versions, run
  `terraform init -upgrade` and commit the updated lock file.
