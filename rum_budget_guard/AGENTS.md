# rum_budget_guard/ — RUM cost kill-switch

Hard stop for CloudWatch RUM spend. Two halves that only work together —
**never delete either one** (root AGENTS.md warning #4):

1. **Trip.** Budget `jyatesdotdev-rum-guard` (COST, monthly, `var.monthly_limit`
   USD, cost-filtered to service "Amazon CloudWatch RUM"). At 100% ACTUAL spend,
   `aws_budgets_budget_action.rum_kill` (`APPLY_IAM_POLICY`, approval
   `AUTOMATIC` — no human in the loop) attaches policy `jyatesdotdev-rum-deny`
   (Deny `rum:PutRumEvents` on `*`) to the RUM Cognito unauth role. Beacons then
   fail for the rest of the month — accepted telemetry loss, bounded cost.
2. **Reset.** EventBridge rule `jyatesdotdev-rum-monthly-reset`
   (`cron(0 0 1 * ? *)` — midnight UTC on the 1st) invokes Python 3.12 Lambda
   `jyatesdotdev-rum-budget-reset`, which detaches the deny policy (tolerates
   NoSuchEntity when it isn't attached). This is the **only automatic detach
   path**. Manual mid-month recovery: `aws iam detach-role-policy` with the same
   role/policy — but only after confirming the spend spike is understood.

## Gotchas

- The reset Lambda's source is **inline in main.tf** (heredoc → `archive_file` →
  `reset.zip` in this directory at plan time). The RUM role name and deny-policy
  ARN are interpolated into the Python code, so renaming either re-zips and
  redeploys automatically. `reset.zip` is a build artifact — untracked in git;
  leave it out of commits.
- IAM is tightly scoped in both directions: the Budgets action role and the reset
  Lambda role can only attach/detach *this specific policy* on *this specific
  role* (`Condition: ArnEquals iam:PolicyArn`).
- Budget notification and the action's subscriber both email `var.admin_email`;
  `time_period_start` is pinned at `2026-04-01_00:00`.
