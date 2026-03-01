#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${BASE_URL:-http://localhost}"

CONFIG_PORT="${CONFIG_PORT:-8888}"
EUREKA_PORT="${EUREKA_PORT:-8761}"
GATEWAY_PORT="${GATEWAY_PORT:-8080}"

CUSTOMERS_PORT="${CUSTOMERS_PORT:-8081}"
VETS_PORT="${VETS_PORT:-8082}"
VISITS_PORT="${VISITS_PORT:-8083}"

EXPECTED_MESSAGE="${EXPECTED_MESSAGE:-hello-from-config-server}"

WAIT_SECONDS="${WAIT_SECONDS:-60}"
SLEEP_SECONDS="${SLEEP_SECONDS:-1}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: '$1' is required but not found in PATH." >&2
    exit 1
  }
}

curl_get() {
  curl --silent --show-error --fail --max-time 2 "$1"
}

contains_all() {
  local body="$1"
  shift
  local expected
  for expected in "$@"; do
    [[ "$body" == *"$expected"* ]] || return 1
  done
  return 0
}

wait_for() {
  local name="$1"
  local url="$2"
  shift 2

  local end=$((SECONDS + WAIT_SECONDS))
  local body=""

  echo "==> Waiting for $name"
  echo "    $url"

  while (( SECONDS < end )); do
    if body="$(curl_get "$url" 2>/dev/null)"; then
      if contains_all "$body" "$@"; then
        echo "OK: $name"
        return 0
      fi
    fi
    sleep "$SLEEP_SECONDS"
  done

  echo "ERROR: Timeout after ${WAIT_SECONDS}s: $name" >&2
  echo "URL: $url" >&2
  echo "Expected substrings:" >&2
  for x in "$@"; do
    echo "  - $x" >&2
  done
  echo "--- last response (if any) ---" >&2
  curl --silent --show-error --max-time 2 "$url" 2>&1 | sed 's/^/  /' >&2 || true
  return 1
}

require_cmd curl

CONFIG_URL="${BASE_URL}:${CONFIG_PORT}"
EUREKA_URL="${BASE_URL}:${EUREKA_PORT}"
GATEWAY_URL="${BASE_URL}:${GATEWAY_PORT}"
CUSTOMERS_URL="${BASE_URL}:${CUSTOMERS_PORT}"
VETS_URL="${BASE_URL}:${VETS_PORT}"
VISITS_URL="${BASE_URL}:${VISITS_PORT}"

# 1) config-server
wait_for "config-server health" "${CONFIG_URL}/actuator/health" "\"status\":\"UP\""
wait_for "config-server application/default" "${CONFIG_URL}/application/default" "${EXPECTED_MESSAGE}"

# 2) discovery-server
wait_for "discovery-server health" "${EUREKA_URL}/actuator/health" "\"status\":\"UP\""

# 3) direct service health
wait_for "customers-service health (direct)" "${CUSTOMERS_URL}/actuator/health" "\"status\":\"UP\""
wait_for "vets-service health (direct)" "${VETS_URL}/actuator/health" "\"status\":\"UP\""
wait_for "visits-service health (direct)" "${VISITS_URL}/actuator/health" "\"status\":\"UP\""

# 4) gateway
wait_for "api-gateway health" "${GATEWAY_URL}/actuator/health" "\"status\":\"UP\""

# 5) gateway -> services (health)
wait_for "gateway -> customers health" "${GATEWAY_URL}/customers/actuator/health" "\"status\":\"UP\""
wait_for "gateway -> vets health" "${GATEWAY_URL}/vets/actuator/health" "\"status\":\"UP\""
wait_for "gateway -> visits health" "${GATEWAY_URL}/visits/actuator/health" "\"status\":\"UP\""

# 6) gateway -> services (hello)
wait_for "gateway -> customers hello" "${GATEWAY_URL}/customers/api/hello" "\"service\":\"customers-service\"" "\"message\":\"${EXPECTED_MESSAGE}\""
wait_for "gateway -> vets hello" "${GATEWAY_URL}/vets/api/hello" "\"service\":\"vets-service\"" "\"message\":\"${EXPECTED_MESSAGE}\""
wait_for "gateway -> visits hello" "${GATEWAY_URL}/visits/api/hello" "\"service\":\"visits-service\"" "\"message\":\"${EXPECTED_MESSAGE}\""

echo ""
echo "All checks passed."