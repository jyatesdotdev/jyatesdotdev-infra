#!/usr/bin/env bash
set -Eeuo pipefail

base_url="${SITE_URL:-https://jyates.dev}"
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

check() {
  local name="$1"
  local url="$2"
  local output="$3"

  echo "Checking ${name}: ${url}"
  curl \
    --fail-with-body \
    --silent \
    --show-error \
    --location \
    --connect-timeout 10 \
    --max-time 30 \
    --retry 6 \
    --retry-all-errors \
    --retry-delay 10 \
    --output "$output" \
    "$url"
}

check "site" "${base_url}/" "${tmp_dir}/site.html"
grep -qi '<html' "${tmp_dir}/site.html"

check "likes API" "${base_url}/api/v1/likes?slug=an-introduction" "${tmp_dir}/likes.json"
jq -e '.slug == "an-introduction" and (.likeCount | type == "number")' "${tmp_dir}/likes.json" >/dev/null

check "comments API" "${base_url}/api/v1/comments?slug=an-introduction" "${tmp_dir}/comments.json"
jq -e 'type == "array"' "${tmp_dir}/comments.json" >/dev/null

echo "Production smoke tests passed"
