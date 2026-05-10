#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
ENV_FILE="$REPO_ROOT/.env"
DATASET="${ASDF_ANALYTICS_DATASET:-asdf_events}"

usage() {
  cat <<'EOF'
Usage:
  analytics/query.sh dashboard
  analytics/query.sh installs
  analytics/query.sh updates
  analytics/query.sh versions [24h|7d|30d|90d|all]
  analytics/query.sh version <version>
  analytics/query.sh platforms [24h|7d|30d|90d|all]
  analytics/query.sh failures [24h|7d|30d|90d|all]

Reads Cloudflare credentials from the repo-root .env file:
  CLOUDFLARE_ACCOUNT_ID=...
  CLOUDFLARE_API_TOKEN=...

Optional .env override:
  ASDF_ANALYTICS_DATASET=asdf_events

Examples:
  analytics/query.sh dashboard
  analytics/query.sh installs
  analytics/query.sh updates
  analytics/query.sh versions 30d
  analytics/query.sh version 1.0.0
  analytics/query.sh version 2026051001
  analytics/query.sh platforms 7d
  analytics/query.sh failures all

Note:
  Version commands report observed install/update events by version. They do
  not report unique active users, because asdf analytics intentionally does not
  store persistent user or device identifiers.
EOF
}

die() {
  printf 'analytics query: %s\n' "$*" >&2
  exit 1
}

trim() {
  local value="$1"

  value="${value#"${value%%[!$' \t\r\n']*}"}"
  value="${value%"${value##*[!$' \t\r\n']}"}"
  printf '%s' "$value"
}

strip_quotes() {
  local value="$1"

  case "$value" in
    \"*\")
      value="${value#\"}"
      value="${value%\"}"
      ;;
    \'*\')
      value="${value#\'}"
      value="${value%\'}"
      ;;
  esac

  printf '%s' "$value"
}

load_env() {
  local line key value

  [ -f "$ENV_FILE" ] ||
    die "missing $ENV_FILE; copy .env.example to .env and fill in Cloudflare credentials"

  while IFS= read -r line || [ -n "$line" ]; do
    line="$(trim "$line")"

    case "$line" in
      "" | \#*) continue ;;
      export\ *) line="$(trim "${line#export }")" ;;
    esac

    case "$line" in
      *=*) ;;
      *) continue ;;
    esac

    key="$(trim "${line%%=*}")"
    value="$(trim "${line#*=}")"

    case "$key" in
      CLOUDFLARE_ACCOUNT_ID | CLOUDFLARE_API_TOKEN | CF_ACCOUNT_ID | CF_API_TOKEN | ASDF_ANALYTICS_DATASET)
        value="$(strip_quotes "$value")"
        export "$key=$value"
        ;;
    esac
  done <"$ENV_FILE"

  CLOUDFLARE_ACCOUNT_ID="${CLOUDFLARE_ACCOUNT_ID:-${CF_ACCOUNT_ID:-}}"
  CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-${CF_API_TOKEN:-}}"
  DATASET="${ASDF_ANALYTICS_DATASET:-$DATASET}"

  [ -n "$CLOUDFLARE_ACCOUNT_ID" ] ||
    die "CLOUDFLARE_ACCOUNT_ID is missing in $ENV_FILE"
  [ -n "$CLOUDFLARE_API_TOKEN" ] ||
    die "CLOUDFLARE_API_TOKEN is missing in $ENV_FILE"

  case "$DATASET" in
    "" | *[!A-Za-z0-9_]*)
      die "ASDF_ANALYTICS_DATASET must contain only letters, numbers, and underscores"
      ;;
  esac
}

run_sql() {
  local sql="$1"
  local api_url="https://api.cloudflare.com/client/v4/accounts/$CLOUDFLARE_ACCOUNT_ID/analytics_engine/sql"
  local response

  response="$(
    curl -sS \
      "$api_url" \
      -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
      --data-binary "$sql"
  )"

  if command -v jq >/dev/null 2>&1 && printf '%s' "$response" | jq empty >/dev/null 2>&1; then
    printf '%s' "$response" | jq .
  else
    printf '%s\n' "$response"
  fi
}

run_sql_json() {
  local sql="$1"

  run_sql "$sql
FORMAT JSONEachRow
"
}

print_section() {
  printf '\n== %s ==\n' "$1"
}

window_condition() {
  case "${1:-30d}" in
    24h) printf "timestamp > NOW() - INTERVAL '1' DAY" ;;
    7d) printf "timestamp > NOW() - INTERVAL '7' DAY" ;;
    30d) printf "timestamp > NOW() - INTERVAL '30' DAY" ;;
    90d) printf "timestamp > NOW() - INTERVAL '90' DAY" ;;
    all) printf "1 = 1" ;;
    *) die "window must be one of: 24h, 7d, 30d, 90d, all" ;;
  esac
}

version_filter() {
  local version="$1"

  [ -n "$version" ] || die "version is required"
  [ "${#version}" -le 40 ] || die "version is too long"

  case "$version" in
    *[!0-9.]*)
      die "version may contain only digits and dots"
      ;;
  esac

  printf "(blob2 = '%s' OR blob3 = '%s')" "$version" "$version"
}

query_installs() {
  run_sql_json "
SELECT
  SUM(if(timestamp > NOW() - INTERVAL '1' DAY, _sample_interval, 0)) AS installs_24h,
  SUM(if(timestamp > NOW() - INTERVAL '7' DAY, _sample_interval, 0)) AS installs_7d,
  SUM(if(timestamp > NOW() - INTERVAL '30' DAY, _sample_interval, 0)) AS installs_30d,
  SUM(if(timestamp > NOW() - INTERVAL '90' DAY, _sample_interval, 0)) AS installs_90d,
  SUM(_sample_interval) AS installs_all_time
FROM $DATASET
WHERE blob1 = 'install'
"
}

query_updates() {
  run_sql_json "
SELECT
  SUM(if(blob1 = 'update_success' AND timestamp > NOW() - INTERVAL '1' DAY, _sample_interval, 0)) AS update_successes_24h,
  SUM(if(blob1 = 'update_failed' AND timestamp > NOW() - INTERVAL '1' DAY, _sample_interval, 0)) AS update_failures_24h,
  SUM(if(blob1 IN ('update_success', 'update_failed') AND timestamp > NOW() - INTERVAL '1' DAY, _sample_interval, 0)) AS update_events_24h,
  SUM(if(blob1 = 'update_success' AND timestamp > NOW() - INTERVAL '7' DAY, _sample_interval, 0)) AS update_successes_7d,
  SUM(if(blob1 = 'update_failed' AND timestamp > NOW() - INTERVAL '7' DAY, _sample_interval, 0)) AS update_failures_7d,
  SUM(if(blob1 IN ('update_success', 'update_failed') AND timestamp > NOW() - INTERVAL '7' DAY, _sample_interval, 0)) AS update_events_7d,
  SUM(if(blob1 = 'update_success' AND timestamp > NOW() - INTERVAL '30' DAY, _sample_interval, 0)) AS update_successes_30d,
  SUM(if(blob1 = 'update_failed' AND timestamp > NOW() - INTERVAL '30' DAY, _sample_interval, 0)) AS update_failures_30d,
  SUM(if(blob1 IN ('update_success', 'update_failed') AND timestamp > NOW() - INTERVAL '30' DAY, _sample_interval, 0)) AS update_events_30d,
  SUM(if(blob1 = 'update_success' AND timestamp > NOW() - INTERVAL '90' DAY, _sample_interval, 0)) AS update_successes_90d,
  SUM(if(blob1 = 'update_failed' AND timestamp > NOW() - INTERVAL '90' DAY, _sample_interval, 0)) AS update_failures_90d,
  SUM(if(blob1 IN ('update_success', 'update_failed') AND timestamp > NOW() - INTERVAL '90' DAY, _sample_interval, 0)) AS update_events_90d,
  SUM(if(blob1 = 'update_success', _sample_interval, 0)) AS update_successes_all_time,
  SUM(if(blob1 = 'update_failed', _sample_interval, 0)) AS update_failures_all_time,
  SUM(if(blob1 IN ('update_success', 'update_failed'), _sample_interval, 0)) AS update_events_all_time
FROM $DATASET
WHERE blob1 IN ('update_success', 'update_failed')
"
}

query_versions() {
  local window="${1:-30d}"
  local condition

  condition="$(window_condition "$window")"

  run_sql_json "
SELECT
  blob2 AS human_version,
  blob3 AS update_version,
  SUM(if(blob1 = 'install', _sample_interval, 0)) AS installs,
  SUM(if(blob1 = 'update_success', _sample_interval, 0)) AS update_successes,
  SUM(if(blob1 = 'update_failed', _sample_interval, 0)) AS update_failures,
  SUM(_sample_interval) AS observed_events
FROM $DATASET
WHERE $condition
  AND blob1 IN ('install', 'update_success', 'update_failed')
GROUP BY
  human_version,
  update_version
ORDER BY observed_events DESC
LIMIT 50
"
}

query_version() {
  local version="$1"
  local filter

  filter="$(version_filter "$version")"

  run_sql_json "
SELECT
  blob2 AS human_version,
  blob3 AS update_version,
  SUM(if(blob1 = 'install' AND timestamp > NOW() - INTERVAL '1' DAY, _sample_interval, 0)) AS installs_24h,
  SUM(if(blob1 = 'update_success' AND timestamp > NOW() - INTERVAL '1' DAY, _sample_interval, 0)) AS update_successes_24h,
  SUM(if(blob1 = 'update_failed' AND timestamp > NOW() - INTERVAL '1' DAY, _sample_interval, 0)) AS update_failures_24h,
  SUM(if(timestamp > NOW() - INTERVAL '1' DAY, _sample_interval, 0)) AS observed_events_24h,
  SUM(if(blob1 = 'install' AND timestamp > NOW() - INTERVAL '7' DAY, _sample_interval, 0)) AS installs_7d,
  SUM(if(blob1 = 'update_success' AND timestamp > NOW() - INTERVAL '7' DAY, _sample_interval, 0)) AS update_successes_7d,
  SUM(if(blob1 = 'update_failed' AND timestamp > NOW() - INTERVAL '7' DAY, _sample_interval, 0)) AS update_failures_7d,
  SUM(if(timestamp > NOW() - INTERVAL '7' DAY, _sample_interval, 0)) AS observed_events_7d,
  SUM(if(blob1 = 'install' AND timestamp > NOW() - INTERVAL '30' DAY, _sample_interval, 0)) AS installs_30d,
  SUM(if(blob1 = 'update_success' AND timestamp > NOW() - INTERVAL '30' DAY, _sample_interval, 0)) AS update_successes_30d,
  SUM(if(blob1 = 'update_failed' AND timestamp > NOW() - INTERVAL '30' DAY, _sample_interval, 0)) AS update_failures_30d,
  SUM(if(timestamp > NOW() - INTERVAL '30' DAY, _sample_interval, 0)) AS observed_events_30d,
  SUM(if(blob1 = 'install' AND timestamp > NOW() - INTERVAL '90' DAY, _sample_interval, 0)) AS installs_90d,
  SUM(if(blob1 = 'update_success' AND timestamp > NOW() - INTERVAL '90' DAY, _sample_interval, 0)) AS update_successes_90d,
  SUM(if(blob1 = 'update_failed' AND timestamp > NOW() - INTERVAL '90' DAY, _sample_interval, 0)) AS update_failures_90d,
  SUM(if(timestamp > NOW() - INTERVAL '90' DAY, _sample_interval, 0)) AS observed_events_90d,
  SUM(if(blob1 = 'install', _sample_interval, 0)) AS installs_all_time,
  SUM(if(blob1 = 'update_success', _sample_interval, 0)) AS update_successes_all_time,
  SUM(if(blob1 = 'update_failed', _sample_interval, 0)) AS update_failures_all_time,
  SUM(_sample_interval) AS observed_events_all_time
FROM $DATASET
WHERE $filter
GROUP BY
  human_version,
  update_version
ORDER BY observed_events_all_time DESC
"
}

query_platforms() {
  local window="${1:-30d}"
  local condition

  condition="$(window_condition "$window")"

  run_sql_json "
SELECT
  blob5 AS os,
  blob6 AS shell,
  blob4 AS install_name,
  SUM(if(blob1 = 'install', _sample_interval, 0)) AS installs,
  SUM(if(blob1 = 'update_success', _sample_interval, 0)) AS update_successes,
  SUM(if(blob1 = 'update_failed', _sample_interval, 0)) AS update_failures,
  SUM(_sample_interval) AS observed_events
FROM $DATASET
WHERE $condition
  AND blob1 IN ('install', 'update_success', 'update_failed')
GROUP BY
  os,
  shell,
  install_name
ORDER BY observed_events DESC
LIMIT 50
"
}

query_failures() {
  local window="${1:-30d}"
  local condition

  condition="$(window_condition "$window")"

  run_sql_json "
SELECT
  blob2 AS human_version,
  blob3 AS update_version,
  blob5 AS os,
  blob6 AS shell,
  blob4 AS install_name,
  SUM(_sample_interval) AS update_failures
FROM $DATASET
WHERE $condition
  AND blob1 = 'update_failed'
GROUP BY
  human_version,
  update_version,
  os,
  shell,
  install_name
ORDER BY update_failures DESC
LIMIT 50
"
}

query_dashboard() {
  print_section "Installs"
  query_installs

  print_section "Updates"
  query_updates

  print_section "Versions - 30d observed events"
  query_versions 30d

  print_section "Platforms - 30d observed events"
  query_platforms 30d
}

require_no_args() {
  local command="$1"
  shift

  [ "$#" -eq 0 ] || die "$command does not accept arguments"
}

require_max_one_arg() {
  local command="$1"
  shift

  [ "$#" -le 1 ] || die "$command accepts at most one argument"
}

require_one_arg() {
  local command="$1"
  shift

  [ "$#" -eq 1 ] || die "$command requires exactly one argument"
}

main() {
  local command="${1:-}"

  case "$command" in
    -h | --help | help | "")
      usage
      exit 0
      ;;
  esac

  command -v curl >/dev/null 2>&1 ||
    die "curl is required"

  load_env

  case "$command" in
    dashboard)
      shift
      require_no_args dashboard "$@"
      query_dashboard
      ;;
    installs)
      shift
      require_no_args installs "$@"
      query_installs
      ;;
    updates)
      shift
      require_no_args updates "$@"
      query_updates
      ;;
    versions)
      shift
      require_max_one_arg versions "$@"
      query_versions "${1:-30d}"
      ;;
    version)
      shift
      require_one_arg version "$@"
      query_version "$1"
      ;;
    platforms)
      shift
      require_max_one_arg platforms "$@"
      query_platforms "${1:-30d}"
      ;;
    failures)
      shift
      require_max_one_arg failures "$@"
      query_failures "${1:-30d}"
      ;;
    *)
      die "unknown command '$command'; run analytics/query.sh --help"
      ;;
  esac
}

main "$@"
