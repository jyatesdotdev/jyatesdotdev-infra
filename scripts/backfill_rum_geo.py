#!/usr/bin/env python3
"""One-time backfill: seed the visitor-map counters from CloudWatch RUM history.

The visitor map (tools > visitor map on the site) counts hits per country in
DynamoDB (PK=STATS#GEO, SK=COUNTRY#<alpha2>), incremented by a per-session
beacon that reads the CloudFront-Viewer-Country edge header. Before that beacon
existed, the only record of where visitors came from was CloudWatch RUM, which
tags every event with metadata.countryCode.

This script reads the RUM events from their CloudWatch Logs group (the app
monitor has cw_log_enabled = true), counts DISTINCT sessions per country over
the log group's retention window (30 days), and ADDs those counts into the
STATS#GEO items in one transaction.

Idempotency: the transaction also Puts a marker item (SK=BACKFILL#<tag>) guarded
by attribute_not_exists(PK). A second run fails the whole transaction, so counts
can never be double-added. Change --tag to intentionally run a fresh import.

Uses the AWS CLI (no boto3 dependency); the CLI must be configured for the
account (e.g. AWS_PROFILE=portfolio).

Usage:
    AWS_PROFILE=portfolio python3 scripts/backfill_rum_geo.py            # dry run
    AWS_PROFILE=portfolio python3 scripts/backfill_rum_geo.py --apply
"""
import argparse
import datetime as dt
import json
import subprocess
import sys
import time

LOG_GROUP = "/aws/vendedlogs/RUMService_jyatesdotdevc846af48"
TABLE = "jyatesdotdev-state"
REGION = "us-west-2"
STATS_PK = "STATS#GEO"
QUERY = (
    "fields metadata.countryCode as country, user_details.sessionId as sid "
    "| filter ispresent(metadata.countryCode) "
    "| stats count_distinct(sid) as sessions by country "
    "| sort sessions desc"
)


def aws(*args: str, payload: str | None = None) -> str:
    """Run an aws CLI command and return stdout, exiting on error."""
    proc = subprocess.run(
        ["aws", *args, "--region", REGION, "--output", "json"],
        input=payload,
        capture_output=True,
        text=True,
    )
    if proc.returncode != 0:
        sys.exit(f"aws {' '.join(args)} failed:\n{proc.stderr}")
    return proc.stdout


def sessions_by_country(days: int) -> dict[str, int]:
    end = int(time.time())
    start = end - days * 24 * 3600
    qid = json.loads(
        aws(
            "logs", "start-query",
            "--log-group-name", LOG_GROUP,
            "--start-time", str(start),
            "--end-time", str(end),
            "--query-string", QUERY,
        )
    )["queryId"]

    while True:
        res = json.loads(aws("logs", "get-query-results", "--query-id", qid))
        if res["status"] == "Complete":
            break
        if res["status"] in ("Failed", "Cancelled", "Timeout"):
            sys.exit(f"Logs Insights query {res['status']}")
        time.sleep(1)

    counts: dict[str, int] = {}
    for row in res["results"]:
        fields = {c["field"]: c["value"] for c in row}
        if fields.get("country"):
            counts[fields["country"]] = int(fields["sessions"])
    return counts


def transact_items(counts: dict[str, int], tag: str) -> list[dict]:
    now = dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    items = [
        {
            "Update": {
                "TableName": TABLE,
                "Key": {"PK": {"S": STATS_PK}, "SK": {"S": f"COUNTRY#{code}"}},
                "UpdateExpression": "ADD #c :n SET updatedAt = :now",
                "ExpressionAttributeNames": {"#c": "count"},
                "ExpressionAttributeValues": {":n": {"N": str(n)}, ":now": {"S": now}},
            }
        }
        for code, n in sorted(counts.items())
    ]
    items.append(
        {
            "Put": {
                "TableName": TABLE,
                "Item": {
                    "PK": {"S": STATS_PK},
                    "SK": {"S": f"BACKFILL#{tag}"},
                    "createdAt": {"S": now},
                    "total": {"N": str(sum(counts.values()))},
                    "note": {"S": f"CloudWatch RUM distinct sessions per country ({tag})"},
                },
                "ConditionExpression": "attribute_not_exists(PK)",
            }
        }
    )
    return items


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--days", type=int, default=30, help="lookback window (RUM log retention)")
    ap.add_argument("--tag", default="rum-30d", help="marker suffix; change to re-import")
    ap.add_argument("--apply", action="store_true", help="write to DynamoDB (default: dry run)")
    args = ap.parse_args()

    counts = sessions_by_country(args.days)
    total = sum(counts.values())
    print(f"{total} distinct sessions across {len(counts)} countries (last {args.days}d):")
    for code, n in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        print(f"  {code}  {n}")

    if not args.apply:
        print("\ndry run — re-run with --apply to write to DynamoDB")
        return

    items = transact_items(counts, args.tag)
    proc = subprocess.run(
        ["aws", "dynamodb", "transact-write-items", "--region", REGION,
         "--transact-items", json.dumps(items)],
        capture_output=True, text=True,
    )
    if proc.returncode == 0:
        print(f"\napplied: marker BACKFILL#{args.tag} written, {total} sessions added")
    elif "TransactionCanceledException" in proc.stderr:
        print(f"\nskipped: BACKFILL#{args.tag} already exists (counts unchanged)")
    else:
        sys.exit(proc.stderr)


if __name__ == "__main__":
    main()
