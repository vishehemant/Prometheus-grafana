#!/bin/bash
# Traffic generator - continuously sends requests to the app to produce metrics

APP_URL="${APP_URL:-http://app:5000}"

ENDPOINTS=(
    "/"
    "/success"
    "/redirect"
    "/bad-request"
    "/unauthorized"
    "/forbidden"
    "/not-found"
    "/rate-limited"
    "/server-error"
    "/service-unavailable"
    "/gateway-timeout"
    "/random"
    "/random"
    "/random"
    "/slow"
)

echo "Starting traffic generator targeting ${APP_URL}"
echo "Endpoints: ${#ENDPOINTS[@]}"

while true; do
    endpoint=${ENDPOINTS[$RANDOM % ${#ENDPOINTS[@]}]}
    curl -s -o /dev/null -w "Status: %{http_code} | Endpoint: ${endpoint} | Time: %{time_total}s\n" \
        "${APP_URL}${endpoint}" &
    sleep "$(awk "BEGIN{print 0.1 + rand() * 0.9}")"
done
