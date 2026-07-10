# api_gateway/ — REST API

Single-file module (~50 resources): REST API `jyatesdotdev-api`, stage `v1`.
Routes are hand-declared resource/method/integration triples (no OpenAPI body).

## Route table (all `AWS_PROXY` → Go Lambdas)

| Path (under `/api/v1`) | Methods | Lambda | Auth |
|---|---|---|---|
| `/comments` | GET, POST | interactions | none |
| `/comments/{commentId}/like` | POST | interactions | none |
| `/likes` | GET, POST | interactions | none |
| `/geo` | GET | interactions | none |
| `/visits` | GET, POST | interactions | none |
| `/contact` | POST | contact | none |
| `/admin/comments` | GET | admin | CUSTOM (TOKEN authorizer) |
| `/admin/comments/{commentId}` | PUT, DELETE | admin | CUSTOM (TOKEN authorizer) |

- **Every method has `api_key_required = true`** — CloudFront injects `x-api-key`
  at the origin; direct calls without the key get 403.
- The TOKEN authorizer has `authorizer_result_ttl_in_seconds = 0` — every admin
  request invokes the authorizer Lambda (deliberate: Basic-Auth checked each time,
  no cached allow).
- Paths are declared as `/api/v1/...` *inside* the API even though the stage is
  already `v1` — combined with CloudFront's `origin_path = "/v1"`, requests arrive
  as `/v1/api/v1/...`. Intentional double prefix (see root AGENTS.md); do not "fix".

## ⚠️ The deployment-snapshot trap

A REST API deployment is a snapshot. `aws_api_gateway_deployment.api` hashes all
Terraform files in this module, so any declared route/method/integration change
forces a new snapshot. New integrations must still be added to the deployment's
explicit `depends_on` list so Terraform cannot snapshot the API before creating
them.

## Cost limits (deliberate — don't "fix"; see RISKS.md)

- Stage-wide `method_settings` throttle: 20 rps / 40 burst.
- Usage plan `cloudfront-origin-plan` (key `cloudfront-origin-key`): same 20/40
throttle plus a **100000 req/DAY quota**. One shared key carries all
CloudFront-routed traffic, so both are aggregate controls. API Gateway quotas are
best effort, not hard cost ceilings; deterministic backend protection comes from
reserved Lambda concurrency and application-level write limits (see RISKS.md).

## Misc

- `aws_api_gateway_account` sets the **account-level** CloudWatch logging role for
  API Gateway — a region-wide setting, not per-API.
- Access logs: `/aws/api-gateway/jyatesdotdev-api`, 7-day retention, KMS-encrypted
  (`var.kms_key_arn`).
- Lambda invoke permissions use wildcard `execution_arn/*/*` source ARNs.
