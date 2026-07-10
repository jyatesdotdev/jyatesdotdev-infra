# Risk Register — jyates.dev

Security and cost trade-offs that were made deliberately. Read this before
"hardening" or "cleaning up" the related resources — the gaps below are known
and accepted, not oversights.

## 2026-07-04 — Removed the CloudFront WAF web ACL

### Decision

Deleted `aws_wafv2_web_acl.main` (and its attachment to the CloudFront
distribution) to eliminate a fixed **~$6.02/month** charge — verified against
Cost Explorer as $5.00 web-ACL fee + $1.00 rule fee + ~$0.02 request processing,
flat month-over-month and ~80% of the total ~$7.55 bill. The ACL held a single
per-IP rate-based rule (500 requests / 5 min per IP, block). WAF pricing is
all-or-nothing: an ACL with zero rules still bills $5, so there is no cheaper
partial configuration, and there is no cheaper AWS-native edge rate limiter
(CloudFront Functions are stateless and cannot rate-limit).

### What the WAF actually provided

Exactly one thing: a **per-IP** edge rate brake across the whole site. It did
**not** provide bot/geo/managed-rule protection, and — because it aggregated per
IP — it never mitigated a **distributed** flood (many IPs each under the limit).
Its only real value was throttling a single hot IP.

### Compensating controls (added, $0)

- **API Gateway usage-plan throttle + daily quota** (`api_gateway/main.tf`):
  `throttle_settings` 20 rps / 40 burst and `quota_settings` 100,000 req/DAY.
  All CloudFront-routed API traffic shares one key, so these are aggregate caps.
  AWS documents usage-plan throttles and quotas as best-effort targets, not hard
  request or cost ceilings. They materially reduce sustained load but can be
  exceeded briefly.
- **Account-level Lambda concurrency**: this account's regional quota currently
  preserves only the required pool of 10 unreserved executions, so project-level
  reservations cannot be configured. The shared account quota still bounds total
  concurrent Lambda work, but does not isolate these functions from each other.
- Pre-existing and unchanged: stage throttle (20/40 aggregate), app-level per-IP
  DynamoDB limits (100 like additions, 20 visits, 10 comments, and 5 contact
  submissions per day), AWS Shield Standard (free, L3/L4 only), CloudFront edge
  caching of static assets, `x-api-key` required on the origin, and the $10/month
  AWS Budgets alarm.

### Accepted residual risks

1. **No per-IP edge rate limit anymore.** A single abusive IP can hit the edge
   and API harder than before (previously capped to ~1.67 rps). The shared account
   concurrency quota bounds simultaneous Lambda work, while throttles, quotas,
   and application write limits reduce sustained load. Static content is
   edge-cached and cheap. Impact: low for a personal site.

2. **Distributed L7 flood is not fully prevented — and never was.** The removed
   per-IP WAF rule did nothing against a distributed bot. Account-wide Lambda
   concurrency is bounded, but CloudFront and API Gateway **request charges**
   scale with the attacker's send rate (throttled 429s are still billable). The
   only backstop is the $10 budget alarm, which is **notification-only and lags
   by hours** — it cannot stop spend. This tail risk is unchanged by removing the
   WAF. Genuine distributed-bot defense (WAF Bot Control, CAPTCHA/Challenge, or a
   Cloudflare front) costs *more*, not less, and was judged not worth it here.

3. **Raw `execute-api` endpoint stays reachable** (`disableExecuteApiEndpoint`
   left `false`). It cannot be disabled: the CloudFront API origin
   (`api_gateway_domain_name`) is derived from the stage `invoke_url`, i.e. the
   `execute-api` domain itself, so disabling it would break the site. Properly
   closing it needs an API Gateway custom domain (out of scope). It is gated by
   the required `x-api-key`, which CloudFront injects server-side and is not
   exposed to browsers — so this is defense-in-depth, not an open door. If the
   key ever leaks, rotate `random_password.api_key`.

4. **Quota self-DoS trade-off.** Once API Gateway observes the 100,000/day quota
   as exhausted, it returns 429 to everyone until the window resets, though some
   requests can exceed the configured quota because enforcement is best effort.
   A genuine viral spike could still 429 legitimate users. The limit is set
   generously (~100–500x a normal day) to make this unlikely; tune it in
   `api_gateway/main.tf` if traffic grows.

### If attacked (runbook)

1. Budget alarm fires (or bill looks off) → open the CloudWatch dashboard, check
   the **"API Gateway Requests & Errors"** widget (429s surface as 4XX) and the
   CloudFront traffic widget.
2. Immediate levers: lower the usage-plan `quota_settings.limit` /
   `throttle_settings`; block offending IPs/geos.
3. Nuclear option: **re-add the WAF** — revert this change (a single in-place
   `terraform apply`) to restore the per-IP edge rate limit. Everything here is
   fully reversible.

   ⚠️ Teardown ordering (learned during the 2026-07-04 removal): if the WAF is
   ever removed again, deleting a web ACL that is still associated with the
   CloudFront distribution fails with `WAFAssociatedItemException`. Disassociate
   first — apply the distribution change (drop `web_acl_id`) and let it deploy,
   then delete the ACL in a second apply.

### Cost impact

Total bill ~$7.55/mo → ~$1.53/mo (saves ~$6.02/mo, ~$72/yr).

## 2026-07-09 - Calibrated Checkov policy exceptions

Checkov is a hard CI gate. Accepted exceptions are annotated on individual
Terraform resources so new resources do not inherit blanket exclusions. The
current exceptions reflect these architecture and cost decisions:

- API Gateway uses Lambda proxy integrations. Go handlers own schema, path, and
  query validation; API responses are dynamic or visitor-specific and stay
  uncached. API Gateway client certificates do not apply to Lambda integrations.
- API Lambdas are invoked synchronously, have no private VPC dependencies, and
  cannot reserve concurrency under the account's current regional quota. AWS
  Signer is not used; OIDC CI publishes versioned artifacts to a private bucket.
- CloudWatch log retention is deliberately 7-14 days to limit both cost and
  retained visitor data. Public site assets use SSE-S3. The shared logging bucket
  also uses SSE-S3 because it receives S3 server logs and legacy CloudFront logs.
- S3 replication and event notifications have no consumer or recovery requirement
  here. Bucket versioning and reproducible deployments cover static-site recovery.
- The site is global, has a single origin per behavior, and uses unauthenticated
  Cognito identities solely so browsers can submit events to the scoped RUM role.
- DNSSEC is deferred because enabling it requires coordinated DS delegation at
  Name.com; an incomplete rollout would take the site and email DNS offline. DNS
  query logging is not retained because its cost and visitor metadata are not
  justified for the current incident-response needs.
