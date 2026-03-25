# Monitoring Lab Environment

A complete, production-style monitoring lab featuring **Prometheus**, **Grafana**, **Alertmanager**, **OpenTelemetry**, and **Jaeger**. The lab includes a sample Flask application that generates all types of HTTP status codes (2xx, 3xx, 4xx, 5xx) with an automated traffic generator to simulate real-world traffic patterns.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Components & Fundamentals](#components--fundamentals)
   - [Prometheus](#1-prometheus)
   - [Grafana](#2-grafana)
   - [Alertmanager](#3-alertmanager)
   - [OpenTelemetry](#4-opentelemetry-otel)
   - [Jaeger](#5-jaeger)
3. [HTTP Status Codes Reference](#http-status-codes-reference)
4. [Prerequisites](#prerequisites)
5. [Quick Start](#quick-start)
6. [Accessing the Services](#accessing-the-services)
7. [Detailed Setup Guide](#detailed-setup-guide)
8. [PromQL Query Examples](#promql-query-examples)
9. [Alerting Rules Explained](#alerting-rules-explained)
10. [OpenTelemetry Pipeline Explained](#opentelemetry-pipeline-explained)
11. [Troubleshooting](#troubleshooting)
12. [Project Structure](#project-structure)
13. [Interview Scenarios for 5 Years Experience](#interview-scenarios-for-5-years-experience)

---

## Architecture Overview

```
                          ┌──────────────────────┐
                          │   Traffic Generator   │
                          │  (curl-based script)  │
                          └──────────┬───────────┘
                                     │ HTTP Requests
                                     ▼
┌───────────────────────────────────────────────────────────┐
│                  Flask Application (:5000)                 │
│  Endpoints: /, /success, /bad-request, /unauthorized,     │
│  /forbidden, /not-found, /server-error, /service-         │
│  unavailable, /redirect, /rate-limited, /gateway-timeout, │
│  /random, /slow, /health, /metrics                        │
└──────┬──────────────────────────────────┬─────────────────┘
       │ /metrics (Prometheus format)     │ OTLP (traces)
       ▼                                  ▼
┌──────────────┐              ┌─────────────────────┐
│  Prometheus  │              │  OTel Collector     │
│   (:9090)    │◄─────────────│  (:4317/:4318)      │
│              │  scrape      │  (:8889 metrics)    │
└──────┬───┬──┘              └──────────┬──────────┘
       │   │                            │ OTLP export
       │   │                            ▼
       │   │                    ┌──────────────┐
       │   │                    │    Jaeger     │
       │   │                    │  (:16686 UI)  │
       │   │                    └──────────────┘
       │   │
       │   └──────────────┐
       ▼                  ▼
┌──────────────┐   ┌──────────────┐
│   Grafana    │   │ Alertmanager │
│  (:3000)     │   │  (:9093)     │
│  Dashboards  │   │  Routing &   │
│  & Alerts    │   │  Silencing   │
└──────────────┘   └──────────────┘
```

---

## Components & Fundamentals

### 1. Prometheus

**What is Prometheus?**
Prometheus is an open-source systems monitoring and alerting toolkit originally built at SoundCloud. It is now a graduated project of the Cloud Native Computing Foundation (CNCF).

**Core Concepts:**

| Concept | Description |
|---------|-------------|
| **Time Series** | Data identified by metric name and key-value label pairs. Each data point has a timestamp and a float64 value. |
| **Metric Types** | **Counter** (monotonically increasing), **Gauge** (can go up/down), **Histogram** (samples in configurable buckets), **Summary** (configurable quantiles over a sliding window) |
| **Scraping** | Prometheus **pulls** metrics from targets at configured intervals (pull-based model). |
| **PromQL** | Prometheus Query Language for querying time-series data. Supports instant vectors, range vectors, scalar, and string types. |
| **Service Discovery** | Automatically finds scrape targets. Supports static config, Kubernetes, Consul, EC2, DNS, file-based, etc. |
| **Recording Rules** | Pre-compute frequently used or expensive PromQL expressions and save as new time series. |
| **Alert Rules** | Define conditions under which alerts are fired and sent to Alertmanager. |

**Data Model:**
```
<metric_name>{<label1>=<value1>, <label2>=<value2>, ...}  <value>  [<timestamp>]

Example:
http_requests_total{method="GET", endpoint="/api", status_code="200"}  1027  1625000000
```

**How Prometheus Works in This Lab:**
- Prometheus scrapes the Flask app's `/metrics` endpoint every 5 seconds.
- It also scrapes the OTel Collector's Prometheus exporter on port 8889.
- Alert rules evaluate every 15 seconds and fire alerts to Alertmanager.
- Recording rules pre-compute request rates and latency percentiles.

---

### 2. Grafana

**What is Grafana?**
Grafana is an open-source analytics and interactive visualization web application. It provides charts, graphs, and alerts for the web when connected to supported data sources.

**Core Concepts:**

| Concept | Description |
|---------|-------------|
| **Data Sources** | Backend connections to databases like Prometheus, Elasticsearch, InfluxDB, Jaeger, Loki, etc. |
| **Dashboards** | Collections of panels organized in rows. Each dashboard has a time range selector and variables. |
| **Panels** | Individual visualization units: time series, stat, gauge, bar chart, table, heatmap, etc. |
| **Provisioning** | YAML-based configuration to auto-configure data sources and dashboards on startup. |
| **Alerting** | Grafana Alerting allows defining alert rules directly in the Grafana UI with multi-data-source support. |
| **Variables** | Template variables for dynamic dashboards (e.g., dropdown for selecting an environment). |
| **Annotations** | Mark points on graphs for events (deployments, incidents, etc.). |

**How Grafana Works in This Lab:**
- Auto-provisioned with Prometheus and Jaeger data sources.
- Pre-loaded dashboard showing: request rates, error rates, latency percentiles, status code distribution, CPU/memory gauges, active users.
- Login: `admin` / `admin`.

---

### 3. Alertmanager

**What is Alertmanager?**
Alertmanager handles alerts sent by Prometheus. It takes care of deduplicating, grouping, routing, silencing, and inhibiting alerts, and dispatching notifications via email, Slack, PagerDuty, webhooks, etc.

**Core Concepts:**

| Concept | Description |
|---------|-------------|
| **Routing** | A tree of routes that match alerts by labels and send them to the correct receiver. |
| **Grouping** | Combines similar alerts into a single notification (e.g., group by `alertname` and `severity`). |
| **Inhibition** | Suppresses notifications for less-severe alerts when a more-severe alert is already firing. |
| **Silencing** | Temporarily mutes specific alerts (e.g., during maintenance windows). |
| **Receivers** | Notification destinations: email, Slack, PagerDuty, OpsGenie, webhooks, etc. |
| **`group_wait`** | How long to wait before sending the initial notification for a new group. |
| **`group_interval`** | How long to wait before sending updates for an existing group. |
| **`repeat_interval`** | How long to wait before re-sending an alert notification. |

**How Alertmanager Works in This Lab:**
- Receives alerts from Prometheus when rules fire.
- Routes critical alerts, warning alerts, and security alerts to separate receivers.
- Inhibition rule: when a critical alert fires, matching warning alerts are suppressed.
- Uses webhook receivers (can be extended to Slack/email/PagerDuty).

---

### 4. OpenTelemetry (OTel)

**What is OpenTelemetry?**
OpenTelemetry is a CNCF observability framework for instrumenting, generating, collecting, and exporting telemetry data (traces, metrics, logs). It provides a single set of APIs, SDKs, and tools.

**Three Pillars of Observability:**

| Pillar | Description | Tool in This Lab |
|--------|-------------|------------------|
| **Metrics** | Numerical measurements over time (counters, gauges, histograms) | Prometheus + OTel Collector |
| **Traces** | End-to-end request paths through distributed systems | Jaeger + OTel Collector |
| **Logs** | Discrete event records with timestamps | Application logs (stdout) |

**OTel Collector Architecture:**

```
Receivers  →  Processors  →  Exporters
   │              │              │
   │              │              ├── Jaeger (traces)
   │              │              ├── Prometheus (metrics)
   │              │              └── Debug (console)
   │              │
   │              ├── Batch (groups telemetry for efficiency)
   │              ├── Memory Limiter (prevents OOM)
   │              ├── Attributes (adds/modifies attributes)
   │              └── Filter (drops unwanted data)
   │
   ├── OTLP/gRPC (port 4317)
   └── OTLP/HTTP (port 4318)
```

**Key OTel Concepts:**

| Concept | Description |
|---------|-------------|
| **Spans** | A unit of work in a trace. Has a name, start/end timestamps, attributes, events, and links. |
| **Traces** | A collection of spans forming a DAG (Directed Acyclic Graph) representing a request flow. |
| **Context Propagation** | Passing trace context (trace ID, span ID) across service boundaries via HTTP headers (W3C TraceContext). |
| **Resource** | Entity producing telemetry (e.g., `service.name`, `service.version`). |
| **Instrumentation** | Auto-instrumentation (agent/SDK wraps libraries) or manual (explicit span creation). |
| **OTLP** | OpenTelemetry Protocol - the native wire protocol for sending telemetry data. |

**How OTel Works in This Lab:**
- The Flask app is auto-instrumented with `opentelemetry-instrumentation-flask`.
- Traces are sent via OTLP/gRPC to the OTel Collector.
- The Collector processes, batches, and exports traces to Jaeger and metrics to Prometheus.

---

### 5. Jaeger

**What is Jaeger?**
Jaeger is an open-source distributed tracing system inspired by Google Dagger and OpenZipkin. It is used for monitoring and troubleshooting microservices-based architectures.

**Core Concepts:**

| Concept | Description |
|---------|-------------|
| **Trace** | End-to-end journey of a request through services. |
| **Span** | A named, timed operation representing a unit of work. |
| **Service** | A logical deployment unit identified by `service.name`. |
| **Operation** | A specific span name within a service (e.g., `GET /api/users`). |
| **Tags** | Key-value pairs providing metadata about a span. |
| **Logs** | Structured log entries within a span for debugging. |

---

## HTTP Status Codes Reference

This lab generates the following HTTP status codes to simulate real-world traffic:

### 2xx - Success
| Code | Name | Endpoint | Description |
|------|------|----------|-------------|
| 200 | OK | `/`, `/success`, `/slow` | Request succeeded. The server returned the requested resource. |

### 3xx - Redirection
| Code | Name | Endpoint | Description |
|------|------|----------|-------------|
| 301 | Moved Permanently | `/redirect` | Resource has been permanently moved to a new URL. |
| 302 | Found | `/redirect` | Temporary redirect. Client should use the original URL for future requests. |
| 307 | Temporary Redirect | `/redirect` | Same as 302 but method and body must not change. |
| 308 | Permanent Redirect | `/redirect` | Same as 301 but method and body must not change. |

### 4xx - Client Errors
| Code | Name | Endpoint | Description |
|------|------|----------|-------------|
| 400 | Bad Request | `/bad-request` | Server cannot process the request due to malformed syntax. |
| 401 | Unauthorized | `/unauthorized` | Authentication is required and has failed or not been provided. |
| 403 | Forbidden | `/forbidden` | Server understood the request but refuses to authorize it. |
| 404 | Not Found | `/not-found` | Requested resource could not be found on the server. |
| 429 | Too Many Requests | `/rate-limited` | Client has sent too many requests in a given time (rate limiting). |

### 5xx - Server Errors
| Code | Name | Endpoint | Description |
|------|------|----------|-------------|
| 500 | Internal Server Error | `/server-error` | Unexpected condition encountered on the server. |
| 503 | Service Unavailable | `/service-unavailable` | Server is temporarily unable to handle the request (overloaded/maintenance). |
| 504 | Gateway Timeout | `/gateway-timeout` | Upstream server failed to respond within the time limit. |

---

## Prerequisites

- **Docker** (version 20.10+)
- **Docker Compose** (version 2.0+ or `docker compose` plugin)
- At least **4 GB of free RAM** (all services combined)
- Ports available: `3000`, `5000`, `9090`, `9093`, `4317`, `4318`, `8889`, `16686`

---

## Quick Start

```bash
# 1. Clone the repository
git clone <repository-url>
cd <repository-directory>

# 2. Start all services
docker compose up -d --build

# 3. Wait for services to be healthy (about 30 seconds)
docker compose ps

# 4. Open the services in your browser
#    - App:          http://localhost:5000
#    - Prometheus:   http://localhost:9090
#    - Grafana:      http://localhost:3000  (admin/admin)
#    - Alertmanager: http://localhost:9093
#    - Jaeger:       http://localhost:16686

# 5. Stop all services
docker compose down

# 6. Stop and remove all data
docker compose down -v
```

---

## Accessing the Services

| Service | URL | Credentials |
|---------|-----|-------------|
| **Flask App** | http://localhost:5000 | - |
| **Prometheus** | http://localhost:9090 | - |
| **Grafana** | http://localhost:3000 | admin / admin |
| **Alertmanager** | http://localhost:9093 | - |
| **Jaeger UI** | http://localhost:16686 | - |
| **OTel Collector Health** | http://localhost:13133 | - |
| **OTel zPages** | http://localhost:55679/debug/tracez | - |

---

## Detailed Setup Guide

### Step 1: Understand the Directory Structure

```
monitoring-lab/
├── app/                           # Flask application
│   ├── app.py                     # Main application with all endpoints
│   ├── requirements.txt           # Python dependencies
│   └── Dockerfile                 # Container image for the app
├── prometheus/
│   ├── prometheus.yml             # Prometheus scrape configuration
│   └── alert_rules.yml            # Alert rules and recording rules
├── alertmanager/
│   └── alertmanager.yml           # Alert routing and receivers
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/
│   │   │   └── datasources.yml    # Auto-configure Prometheus + Jaeger
│   │   └── dashboards/
│   │       └── dashboards.yml     # Dashboard provisioning config
│   └── dashboards/
│       └── monitoring-lab-dashboard.json  # Pre-built dashboard
├── otel-collector/
│   └── otel-collector-config.yml  # OTel Collector pipeline config
├── scripts/
│   ├── traffic-generator.sh       # Automated traffic generator
│   └── Dockerfile                 # Container for traffic generator
├── docker-compose.yml             # Orchestrates all services
└── README.md                      # This file
```

### Step 2: Start the Environment

```bash
docker compose up -d --build
```

This command:
- Builds the Flask app and traffic generator Docker images.
- Pulls official images for Prometheus, Grafana, Alertmanager, OTel Collector, and Jaeger.
- Creates a shared Docker network (`monitoring-lab-network`).
- Creates named volumes for persistent data.

### Step 3: Verify All Services are Running

```bash
docker compose ps
```

All services should show `Up` status. The app should show `Up (healthy)` after passing its health check.

### Step 4: Explore Prometheus

1. Open http://localhost:9090.
2. Go to **Status > Targets** to verify all scrape targets are up.
3. Try these queries in the **Graph** tab:
   - `http_requests_total` - View raw request counters.
   - `rate(http_requests_total[5m])` - View request rate per second.
   - `http_requests_total{status_code="503"}` - Filter by status code.
4. Go to **Status > Rules** to see alert and recording rules.
5. Go to **Alerts** to see current alert states (firing/pending/inactive).

### Step 5: Explore Grafana

1. Open http://localhost:3000 and log in with `admin` / `admin`.
2. Navigate to **Dashboards > Monitoring Lab** folder.
3. Open the **Monitoring Lab - HTTP Status Codes & Performance** dashboard.
4. You will see:
   - **Overview row**: Total request rate, 5xx error rate, P95 latency, app health.
   - **Status code row**: Request rate by status code (line chart) and by endpoint (bar chart).
   - **Latency row**: Latency percentiles (P50/P90/P95/P99) and per-endpoint P95.
   - **Error row**: Error rate by type (client/server) and by endpoint.
   - **Application row**: CPU gauge, memory gauge, active users stat.

### Step 6: Explore Alertmanager

1. Open http://localhost:9093.
2. View active alerts under **Alerts**.
3. Explore **Silences** to see how to mute alerts during maintenance.
4. The lab will likely trigger `HighErrorRate` and `ServiceUnavailableSpike` alerts because the traffic generator hits error endpoints.

### Step 7: Explore Jaeger

1. Open http://localhost:16686.
2. Select **monitoring-lab-app** from the Service dropdown.
3. Click **Find Traces** to see distributed traces.
4. Click on any trace to see span details, timing, and attributes.

### Step 8: Explore OpenTelemetry Collector

1. Health check: http://localhost:13133
2. zPages (internal debugging): http://localhost:55679/debug/tracez
3. Prometheus metrics exported by the collector: http://localhost:8889/metrics

### Step 9: Test Individual Endpoints

```bash
# 200 OK
curl http://localhost:5000/success

# 301/302/307/308 Redirect
curl -v http://localhost:5000/redirect

# 400 Bad Request
curl http://localhost:5000/bad-request

# 401 Unauthorized
curl http://localhost:5000/unauthorized

# 403 Forbidden
curl http://localhost:5000/forbidden

# 404 Not Found
curl http://localhost:5000/not-found

# 429 Rate Limited
curl http://localhost:5000/rate-limited

# 500 Internal Server Error
curl http://localhost:5000/server-error

# 503 Service Unavailable
curl http://localhost:5000/service-unavailable

# 504 Gateway Timeout
curl http://localhost:5000/gateway-timeout

# Random status code
curl http://localhost:5000/random

# Slow response (1-5 seconds)
curl http://localhost:5000/slow

# Prometheus metrics
curl http://localhost:5000/metrics
```

---

## PromQL Query Examples

### Basic Queries

```promql
# Total number of requests (instant vector)
http_requests_total

# Total requests for a specific status code
http_requests_total{status_code="200"}

# Total requests for all 5xx errors
http_requests_total{status_code=~"5.."}

# Total requests for all 4xx errors
http_requests_total{status_code=~"4.."}
```

### Rate Queries

```promql
# Request rate per second (over last 5 minutes)
rate(http_requests_total[5m])

# Total request rate across all endpoints
sum(rate(http_requests_total[5m]))

# Request rate by status code
sum(rate(http_requests_total[5m])) by (status_code)

# Error rate percentage (5xx)
sum(rate(http_requests_total{status_code=~"5.."}[5m]))
/
sum(rate(http_requests_total[5m]))

# Top 5 endpoints by request rate
topk(5, sum(rate(http_requests_total[5m])) by (endpoint))
```

### Latency Queries

```promql
# P50 latency
histogram_quantile(0.50, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# P95 latency
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# P99 latency
histogram_quantile(0.99, sum(rate(http_request_duration_seconds_bucket[5m])) by (le))

# Average request duration
sum(rate(http_request_duration_seconds_sum[5m]))
/
sum(rate(http_request_duration_seconds_count[5m]))

# P95 latency per endpoint
histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, endpoint))
```

### Advanced Queries

```promql
# Apdex score (threshold = 0.5s, tolerable = 2s)
(
  sum(rate(http_request_duration_seconds_bucket{le="0.5"}[5m]))
  +
  sum(rate(http_request_duration_seconds_bucket{le="2"}[5m]))
)
/
(2 * sum(rate(http_request_duration_seconds_count[5m])))

# Request rate increase compared to 1 hour ago
sum(rate(http_requests_total[5m]))
/
sum(rate(http_requests_total[5m] offset 1h))

# Error budget: percentage of remaining error budget (SLO = 99.9%)
1 - (
  sum(increase(http_requests_total{status_code=~"5.."}[24h]))
  /
  sum(increase(http_requests_total[24h]))
) / 0.001
```

---

## Alerting Rules Explained

| Alert | Severity | Condition | Description |
|-------|----------|-----------|-------------|
| **HighErrorRate** | Critical | >5% of requests are 5xx for 2 min | Backend is failing at a dangerous rate. Immediate investigation needed. |
| **HighClientErrorRate** | Warning | >10% of requests are 4xx for 5 min | Clients are sending many bad requests. May indicate API changes or bugs. |
| **HighLatency** | Warning | P95 latency > 2s for 5 min | Responses are getting slow. Check database, dependencies, resource usage. |
| **VeryHighLatency** | Critical | P99 latency > 5s for 2 min | Extreme latency. Users are experiencing timeouts. |
| **ServiceUnavailableSpike** | Critical | 503 rate > 0.1/s for 1 min | Service is overloaded or under maintenance. |
| **UnauthorizedAccessSpike** | Warning | 401 rate > 0.5/s for 5 min | Possible brute-force attack or misconfigured auth. |
| **HighCPUUsage** | Warning | CPU > 80% for 5 min | Application is CPU-bound. Consider scaling or optimizing. |
| **HighMemoryUsage** | Warning | Memory > 1.5GB for 5 min | Memory leak risk. Investigate and consider increasing limits. |
| **TargetDown** | Critical | `up == 0` for 1 min | Prometheus cannot reach a scrape target. Service may be down. |

---

## OpenTelemetry Pipeline Explained

### Receivers
- **OTLP gRPC** (`:4317`): Accepts traces and metrics from the Flask app's OTel SDK.
- **OTLP HTTP** (`:4318`): Alternative HTTP-based ingestion.

### Processors
1. **Memory Limiter**: Prevents the Collector from using more than 512 MiB, with a 128 MiB spike allowance.
2. **Batch**: Groups 1024 spans before exporting (5s timeout). Reduces network calls.
3. **Attributes**: Adds `environment=lab` and `service.namespace=monitoring-lab` to all telemetry.
4. **Filter**: Drops traces for `/health` and `/metrics` endpoints (noise reduction).

### Exporters
1. **OTLP → Jaeger**: Sends processed traces for visualization and querying.
2. **Prometheus**: Exposes received metrics on `:8889` for Prometheus to scrape.
3. **Debug**: Logs telemetry to stdout for troubleshooting.

---

## Troubleshooting

### Service Won't Start
```bash
# Check logs for a specific service
docker compose logs <service-name>

# Example: check app logs
docker compose logs app

# Check all logs
docker compose logs -f
```

### Prometheus Targets are Down
1. Open http://localhost:9090/targets.
2. Check the `State` column for `DOWN` targets.
3. Verify the target service is running: `docker compose ps`.
4. Check network connectivity: `docker compose exec prometheus wget -qO- http://app:5000/metrics`.

### Grafana Dashboard Shows "No Data"
1. Verify Prometheus data source: **Configuration > Data Sources > Prometheus > Test**.
2. Check that the app is generating metrics: `curl http://localhost:5000/metrics`.
3. Ensure the traffic generator is running: `docker compose logs traffic-generator`.

### Alerts Not Firing
1. Check Prometheus rules: http://localhost:9090/rules.
2. Verify alert evaluation: http://localhost:9090/alerts.
3. Check Alertmanager connectivity: `docker compose exec prometheus wget -qO- http://alertmanager:9093/-/healthy`.

### OTel Collector Issues
1. Check health: `curl http://localhost:13133`.
2. Check zPages: http://localhost:55679/debug/tracez.
3. Review logs: `docker compose logs otel-collector`.

---

## Project Structure

```
.
├── README.md
├── docker-compose.yml
├── app/
│   ├── Dockerfile
│   ├── app.py
│   └── requirements.txt
├── alertmanager/
│   └── alertmanager.yml
├── grafana/
│   ├── dashboards/
│   │   └── monitoring-lab-dashboard.json
│   └── provisioning/
│       ├── dashboards/
│       │   └── dashboards.yml
│       └── datasources/
│           └── datasources.yml
├── otel-collector/
│   └── otel-collector-config.yml
├── prometheus/
│   ├── alert_rules.yml
│   └── prometheus.yml
└── scripts/
    ├── Dockerfile
    └── traffic-generator.sh
```

---

## Interview Scenarios for 5 Years Experience

The following section contains scenario-based interview questions and detailed answers for someone with approximately 5 years of DevOps/SRE experience. These are framed around real-world monitoring challenges.

---

### Scenario 1: Production Incident - High 5xx Error Rate

**Q: You receive a PagerDuty alert at 2 AM saying "HighErrorRate: 15% of requests are returning 5xx errors." Walk me through your incident response process.**

**A:**

**1. Acknowledge and Assess (first 2 minutes):**
- Acknowledge the alert in PagerDuty to stop escalation.
- Open Grafana and check the error rate dashboard to confirm the alert is real (not a false positive due to a metric spike).
- Identify which specific 5xx codes are elevated (500 vs 502 vs 503 vs 504 — they imply different root causes).

**2. Determine Blast Radius (next 5 minutes):**
- Check if the issue affects all endpoints or specific ones. In PromQL:
  ```promql
  sum(rate(http_requests_total{status_code=~"5.."}[5m])) by (endpoint)
  ```
- Check if all instances/pods are affected or just some:
  ```promql
  sum(rate(http_requests_total{status_code=~"5.."}[5m])) by (instance)
  ```
- Correlate with recent deployments (check CI/CD pipeline, Git commits).

**3. Identify Root Cause:**
- **503 (Service Unavailable)**: Check if upstream dependencies are down (database, cache, third-party API). Check resource utilization (CPU, memory, disk).
- **500 (Internal Server Error)**: Check application logs for stack traces. Examine recent code changes.
- **502/504 (Bad Gateway/Timeout)**: Check load balancer health checks, upstream timeout configurations, network connectivity.

**4. Mitigate:**
- If caused by a bad deployment → **rollback** immediately.
- If caused by resource exhaustion → **scale horizontally** (add pods/instances).
- If caused by a downstream dependency → **enable circuit breaker** or **failover to backup**.
- If caused by traffic spike → **enable rate limiting** or scale the fleet.

**5. Communicate:**
- Post in the incident channel with status updates every 15 minutes.
- Update the status page for customer-facing impact.

**6. Post-Incident:**
- Write a blameless post-mortem with timeline, root cause, and action items.
- Create tickets for preventive measures (better alerts, runbooks, capacity planning).

---

### Scenario 2: Prometheus Performance and Scaling

**Q: Your Prometheus instance is running out of memory and queries are timing out. How do you diagnose and fix this?**

**A:**

**Diagnosis:**
1. Check `prometheus_tsdb_head_series` — if it's > 5 million, you have cardinality explosion.
2. Run `topk(10, count by (__name__)({__name__=~".+"}))` to find metrics with the most time series.
3. Check `prometheus_tsdb_compaction_duration_seconds` for long compaction times.
4. Examine `process_resident_memory_bytes{job="prometheus"}` for memory growth patterns.

**Common Causes and Solutions:**

| Cause | Solution |
|-------|----------|
| **High cardinality** (too many unique label combinations) | Use `metric_relabel_configs` to drop unnecessary labels. Avoid labels with unbounded values (user IDs, request IDs). |
| **Too many targets** | Use federated Prometheus or Thanos/Cortex for horizontal scaling. |
| **Long retention** | Reduce `--storage.tsdb.retention.time`. Use remote write to long-term storage (Thanos, Mimir). |
| **Expensive queries** | Use recording rules to pre-compute expensive queries. Set `--query.max-concurrency` and `--query.timeout`. |

**Scaling Strategies:**
- **Vertical**: Increase CPU/RAM (quick fix, limited ceiling).
- **Functional sharding**: Separate Prometheus instances per team/service.
- **Thanos**: Add Thanos Sidecar for long-term storage in object storage (S3/GCS) with global query view.
- **Prometheus Agent Mode**: Use `--enable-feature=agent` for write-only instances that remote-write to Mimir/Cortex.

---

### Scenario 3: Setting Up Monitoring for a New Microservice

**Q: A development team is launching a new microservice. How would you set up monitoring from scratch? What metrics would you recommend they expose?**

**A:**

**The Four Golden Signals (from Google SRE book):**
1. **Latency**: Time to service a request. Track P50, P90, P95, P99.
2. **Traffic**: Request rate (req/s). Understand normal vs peak patterns.
3. **Errors**: Rate of failed requests (5xx). Both explicit and implicit failures.
4. **Saturation**: Resource utilization (CPU, memory, disk, connections).

**RED Method (for request-driven services):**
- **R**ate: Requests per second.
- **E**rrors: Errors per second.
- **D**uration: Distribution of request latencies.

**USE Method (for resources like CPU, memory, disk):**
- **U**tilization: Percentage of resource being used.
- **S**aturation: Queue depth or backlog.
- **E**rrors: Resource-level errors.

**Recommended Metrics to Expose:**
```python
# Counters
http_requests_total{method, endpoint, status_code}
http_request_size_bytes_total{method, endpoint}

# Histograms
http_request_duration_seconds{method, endpoint}

# Gauges
app_connections_active
app_thread_pool_size
app_queue_depth

# Business metrics
orders_placed_total
payment_processed_total{status}
```

**Implementation Steps:**
1. Add a `/metrics` endpoint using a Prometheus client library.
2. Create a `ServiceMonitor` (if using Kubernetes + Prometheus Operator).
3. Create Grafana dashboards with the four golden signals.
4. Define SLOs (e.g., 99.9% availability, P99 latency < 500ms).
5. Set up alerts based on SLO burn rates.
6. Add distributed tracing with OpenTelemetry.
7. Implement structured logging (JSON format) for correlation.

---

### Scenario 4: Alertmanager Routing and Alert Fatigue

**Q: Your team is experiencing alert fatigue — they get 200+ alerts per day and have started ignoring them. How would you fix this?**

**A:**

**Immediate Assessment:**
1. Analyze alert frequency: which alerts fire most often?
   ```bash
   amtool alert query --alertmanager.url=http://localhost:9093
   ```
2. Categorize alerts into: **actionable** vs **informational** vs **noise**.

**Strategies to Reduce Alert Fatigue:**

| Strategy | Implementation |
|----------|---------------|
| **Increase thresholds** | If "HighCPU" fires at 60%, raise to 80%. Tune based on actual impact. |
| **Increase `for` duration** | Change `for: 1m` to `for: 5m` to avoid alerting on transient spikes. |
| **Use inhibition rules** | When a critical `NodeDown` alert fires, suppress all pod-level alerts on that node. |
| **Group related alerts** | Use `group_by: [cluster, namespace]` so 50 pod alerts become 1 grouped notification. |
| **Use SLO-based alerting** | Replace symptom-based alerts with multi-window burn-rate alerts. |
| **Create tiered routing** | Critical → PagerDuty (wake people up). Warning → Slack (address during business hours). Info → Dashboard only. |
| **Regular alert reviews** | Monthly review: delete/adjust alerts that haven't led to action in 30 days. |

**SLO-Based Alerting Example (Multi-Window Burn Rate):**
```yaml
# Fast burn: 14.4x error rate over 1 hour (will exhaust 30-day budget in 2 days)
- alert: ErrorBudgetBurnFast
  expr: |
    (
      sum(rate(http_requests_total{status_code=~"5.."}[1h]))
      / sum(rate(http_requests_total[1h]))
    ) > (14.4 * 0.001)
  for: 2m
  labels:
    severity: critical

# Slow burn: 3x error rate over 6 hours (will exhaust budget in 10 days)
- alert: ErrorBudgetBurnSlow
  expr: |
    (
      sum(rate(http_requests_total{status_code=~"5.."}[6h]))
      / sum(rate(http_requests_total[6h]))
    ) > (3 * 0.001)
  for: 30m
  labels:
    severity: warning
```

---

### Scenario 5: OpenTelemetry Adoption in a Legacy System

**Q: You need to add distributed tracing to a legacy monolith that is being broken into microservices. How would you approach this with OpenTelemetry?**

**A:**

**Phase 1 — Start with Auto-Instrumentation (Week 1-2):**
- Use OTel auto-instrumentation agents (Java agent, Python `opentelemetry-instrument`, .NET auto-instrumentation).
- This provides immediate visibility with zero code changes:
  - HTTP client/server spans
  - Database query spans
  - gRPC call spans
- Configure the OTel SDK to send traces to an OTel Collector.

**Phase 2 — Deploy OTel Collector (Week 2-3):**
- Deploy as a DaemonSet (Kubernetes) or sidecar.
- Start with a simple pipeline: OTLP receiver → batch processor → Jaeger exporter.
- Add a memory limiter processor to prevent OOM.
- Use the Collector as a centralized gateway so apps don't need to know about the backend.

**Phase 3 — Add Custom Instrumentation (Ongoing):**
```python
from opentelemetry import trace

tracer = trace.get_tracer("order-service")

def process_order(order_id):
    with tracer.start_as_current_span("process-order") as span:
        span.set_attribute("order.id", order_id)
        span.set_attribute("order.type", "premium")

        validate_order(order_id)
        charge_payment(order_id)
        send_confirmation(order_id)

        span.add_event("order_completed", {"order.id": order_id})
```

**Phase 4 — Context Propagation Across Services:**
- Ensure all services propagate W3C TraceContext headers (`traceparent`, `tracestate`).
- For message queues (Kafka, RabbitMQ), inject trace context into message headers.
- For async workflows, propagate context via task metadata.

**Phase 5 — Advanced Features:**
- **Tail-based sampling** in the OTel Collector: only keep traces with errors or high latency.
- **Span links** for fan-out patterns (one request triggers multiple async jobs).
- **Resource detection** for automatic cloud metadata (AWS EC2, GCP, Kubernetes).

**Key Decisions:**
| Decision | Recommendation |
|----------|---------------|
| Sampling strategy | Start with 100%, then move to tail-based (keep errors, slow, random 10%) |
| Backend | Jaeger for traces, Prometheus for metrics, Loki for logs |
| Collector deployment | DaemonSet for high-volume, sidecar for isolation |
| Protocol | OTLP/gRPC (more efficient than HTTP) |

---

### Scenario 6: Grafana Dashboard Design for Stakeholders

**Q: Your VP of Engineering asks you to create a dashboard that both developers and executives can use. How do you approach this?**

**A:**

**Dashboard Design Principles:**

1. **Layer the information** (progressive disclosure):
   - **Top row**: Executive summary — green/red status, SLA compliance percentage, total revenue impacted.
   - **Middle rows**: Engineering details — error rates, latency percentiles, throughput.
   - **Bottom rows**: Deep-dive — per-service breakdown, per-endpoint details.

2. **Use template variables** for interactivity:
   - Environment dropdown (prod, staging, dev).
   - Service dropdown.
   - Time range presets (last 1h, 6h, 24h, 7d).

3. **Golden Signals Layout:**
   ```
   Row 1: [SLA Status: 99.95%] [Error Rate: 0.3%] [P95 Latency: 120ms] [Traffic: 2.5k req/s]
   Row 2: [Error Rate Time Series] [Latency Percentiles Time Series]
   Row 3: [Request Rate by Service] [Error Rate by Service]
   Row 4: [Top 10 Slowest Endpoints - Table] [Recent Alerts - Table]
   ```

4. **Color coding:**
   - Green: SLO met (error rate < 0.1%).
   - Yellow: SLO at risk (error rate 0.1–0.5%).
   - Red: SLO breached (error rate > 0.5%).

5. **Annotations:**
   - Mark deployments on time series graphs.
   - Mark incident start/end times.

6. **Practical tips:**
   - Use `stat` panels for KPIs (executives care about numbers, not graphs).
   - Use `time series` panels for trends (engineers need to correlate events).
   - Add links to runbooks in panel descriptions.
   - Set auto-refresh to 30s for ops, 5m for executives.

---

### Scenario 7: Monitoring Kubernetes with Prometheus

**Q: How would you set up a complete monitoring stack for a Kubernetes cluster?**

**A:**

**Recommended Stack:**
- **kube-prometheus-stack** (Helm chart) which includes:
  - Prometheus Operator
  - Prometheus
  - Alertmanager
  - Grafana
  - node-exporter (host metrics)
  - kube-state-metrics (Kubernetes object metrics)
  - Prometheus Adapter (custom metrics for HPA)

**Installation:**
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring --create-namespace \
  --set grafana.adminPassword=admin \
  --set prometheus.prometheusSpec.retention=30d \
  --set prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=50Gi
```

**Key Metrics to Monitor:**

| Layer | Metrics | Source |
|-------|---------|--------|
| **Node** | CPU, memory, disk, network | node-exporter |
| **Kubernetes** | Pod status, deployment replicas, HPA status | kube-state-metrics |
| **Container** | CPU/memory requests vs limits, restarts | cAdvisor (built into kubelet) |
| **Application** | RED metrics, business metrics | Custom `/metrics` endpoint |
| **Network** | DNS latency, TCP connections, dropped packets | node-exporter + CoreDNS metrics |

**ServiceMonitor for Custom Apps:**
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: my-app
  labels:
    release: monitoring
spec:
  selector:
    matchLabels:
      app: my-app
  endpoints:
    - port: http-metrics
      interval: 15s
      path: /metrics
```

**Critical Alerts for Kubernetes:**
- `KubePodCrashLooping` — Pod restarting repeatedly.
- `KubePodNotReady` — Pod stuck in not-ready state.
- `KubeDeploymentReplicasMismatch` — Desired vs actual replicas differ.
- `NodeNotReady` — Kubernetes node is unhealthy.
- `CPUThrottlingHigh` — Container being CPU-throttled.
- `KubePersistentVolumeFillingUp` — PV running out of disk space.

---

### Scenario 8: Handling a Cardinality Explosion

**Q: A developer added a label `user_id` to their metrics, and Prometheus memory usage jumped from 4 GB to 40 GB overnight. How do you fix this?**

**A:**

**Why It Happened:**
- Each unique combination of labels creates a new time series.
- If you have 1 million users, that label creates 1 million time series per metric.
- With 10 metrics × 1M users = 10 million time series = memory explosion.

**Immediate Fix:**
1. Use `metric_relabel_configs` in Prometheus to drop the label:
   ```yaml
   scrape_configs:
     - job_name: "my-app"
       metric_relabel_configs:
         - source_labels: [user_id]
           action: labeldrop
           regex: user_id
   ```
2. Reload Prometheus: `curl -X POST http://localhost:9090/-/reload`
3. Wait for TSDB compaction to reclaim memory (or restart Prometheus).

**Long-Term Prevention:**
- Establish a **metrics governance policy**: no unbounded labels.
- Use a **metrics linting tool** (like `pint`) in CI/CD to catch high-cardinality labels before deployment.
- Set up a **cardinality alert**:
  ```yaml
  - alert: HighCardinality
    expr: prometheus_tsdb_head_series > 2000000
    for: 5m
    annotations:
      summary: "Prometheus cardinality is too high: {{ $value }} series"
  ```
- Educate developers: labels should have **low, bounded cardinality** (e.g., `status_code`, `method`, `region` — not `user_id`, `trace_id`, `request_id`).

**The Rule of Thumb:**
- Every label value combination multiplies the number of time series.
- A metric with 3 labels, each having 10 values = 10 × 10 × 10 = 1,000 time series.
- A metric with a `user_id` label (1M values) = 1M time series per metric.

---

### Scenario 9: Implementing SLOs and Error Budgets

**Q: Your company wants to implement SLOs. Walk me through the process for an API service.**

**A:**

**Step 1 — Define SLIs (Service Level Indicators):**
```
Availability SLI = (successful requests / total requests) × 100
Latency SLI     = (requests served within 500ms / total requests) × 100
```

**Step 2 — Set SLOs (Service Level Objectives):**
| SLI | SLO Target | Error Budget (30 days) |
|-----|------------|----------------------|
| Availability | 99.9% | 0.1% = ~43 minutes of downtime |
| Latency (P99 < 500ms) | 99.5% | 0.5% = ~216 minutes above threshold |

**Step 3 — Calculate Error Budget:**
```promql
# Availability error budget remaining (over 30 days)
1 - (
  sum(increase(http_requests_total{status_code=~"5.."}[30d]))
  /
  sum(increase(http_requests_total[30d]))
) / 0.001

# Latency error budget remaining
1 - (
  1 - (
    sum(increase(http_request_duration_seconds_bucket{le="0.5"}[30d]))
    /
    sum(increase(http_request_duration_seconds_count[30d]))
  )
) / 0.005
```

**Step 4 — Set Up Multi-Window Burn Rate Alerts:**
| Window | Burn Rate | Severity | Meaning |
|--------|-----------|----------|---------|
| 1h / 5m | 14.4x | Critical (page) | Budget exhausted in 2 days |
| 6h / 30m | 6x | Critical (page) | Budget exhausted in 5 days |
| 1d / 2h | 3x | Warning (ticket) | Budget exhausted in 10 days |
| 3d / 6h | 1x | Info (log) | Budget on track to exhaust |

**Step 5 — Error Budget Policy:**
- If error budget > 50%: Deploy freely, experiment.
- If error budget 20-50%: Extra review for risky changes.
- If error budget < 20%: Freeze feature deployments, focus on reliability.
- If error budget exhausted: No deployments until budget is restored.

---

### Scenario 10: Migrating from Monolithic Monitoring to Observability

**Q: Your organization currently uses Nagios for monitoring. Management wants to move to a modern observability stack. How would you plan and execute this migration?**

**A:**

**Phase 1 — Assessment (Discovery):**
- Inventory all Nagios checks (host checks, service checks, custom plugins).
- Map Nagios checks to equivalent Prometheus metrics or exporters.
- Identify critical alerts that must not have gaps during migration.
- Document current on-call procedures and escalation paths.

**Phase 2 — Parallel Run:**
- Deploy the new stack (Prometheus, Grafana, Alertmanager, OTel Collector) alongside Nagios.
- Start with node-exporter on all hosts to replace Nagios host checks.
- Use blackbox-exporter for HTTP/TCP endpoint checks (replaces Nagios service checks).
- Run both systems in parallel for 2-4 weeks to build confidence.

**Phase 3 — Migration Mapping:**
| Nagios Concept | Modern Equivalent |
|---------------|-------------------|
| Host check (ping) | `up` metric, blackbox-exporter |
| Service check (HTTP) | blackbox-exporter HTTP probe |
| NRPE plugins | Prometheus exporters or custom metrics |
| Nagios alerts | Prometheus alert rules + Alertmanager |
| Nagios dashboards | Grafana dashboards |
| Nagios event handler | Alertmanager webhook + automation |
| Performance data | Prometheus metrics (native) |

**Phase 4 — Cutover:**
- Disable Nagios alerts one group at a time (start with least critical).
- Verify equivalent Prometheus alerts fire correctly.
- Update on-call runbooks to reference Grafana dashboards instead of Nagios.
- Train the team on PromQL, Grafana, and the new alerting workflow.

**Phase 5 — Enhance:**
- Add distributed tracing (OTel + Jaeger) — something Nagios never had.
- Add log aggregation (Loki or Elasticsearch).
- Implement SLOs and error budgets.
- Set up Grafana On-Call or PagerDuty for modern incident management.

**Key Risks and Mitigations:**
| Risk | Mitigation |
|------|-----------|
| Alert gap during migration | Parallel run, cutover one service at a time |
| Team resistance | Training workshops, pair sessions |
| Missing checks | Systematic mapping document, weekly reviews |
| Increased complexity | Start simple, add complexity incrementally |

---

### Bonus: Common Interview Questions (Quick-Fire)

**Q: What is the difference between `rate()` and `irate()` in PromQL?**
- `rate()` calculates per-second average rate over the full range. Smooth, good for alerts.
- `irate()` calculates rate using only the last two data points. Spiky, good for real-time graphs.

**Q: What is the difference between a Counter and a Gauge?**
- Counter: Monotonically increasing (resets only on restart). Use `rate()` on it. Example: total requests.
- Gauge: Can go up and down. Use directly. Example: CPU usage, active connections.

**Q: How does Prometheus handle high availability?**
- Run two identical Prometheus instances scraping the same targets.
- Use Alertmanager's built-in deduplication (both send alerts; AM deduplicates).
- Use Thanos or Cortex for a unified query view across replicas.

**Q: What is a recording rule and why use it?**
- Pre-computes an expensive PromQL expression and stores the result as a new time series.
- Improves dashboard load time and allows alerting on pre-computed values.
- Example: Pre-compute `sum(rate(http_requests_total[5m])) by (service)` as `job:http_requests_total:rate5m`.

**Q: Explain the pull vs push model in monitoring.**
- **Pull (Prometheus)**: Monitoring system scrapes targets. Pros: central control, easy to detect target death. Cons: hard for short-lived jobs (use Pushgateway).
- **Push (Graphite, InfluxDB, OTel)**: Targets push data to a collector. Pros: works for short-lived jobs, firewalled environments. Cons: harder to detect if a target stopped sending.

**Q: What are the three pillars of observability?**
- **Metrics**: Aggregated numerical measurements (what is happening).
- **Traces**: Request-scoped, distributed call graphs (where is it happening).
- **Logs**: Discrete, timestamped event records (why is it happening).

**Q: How would you monitor a Kubernetes cluster?**
- Use kube-prometheus-stack (Helm chart).
- node-exporter (host metrics), kube-state-metrics (K8s objects), cAdvisor (container metrics).
- ServiceMonitor CRDs for app metrics auto-discovery.
- Alert on: CrashLoopBackOff, OOMKilled, PersistentVolume filling up, Node not ready.

**Q: What is the difference between blackbox and whitebox monitoring?**
- **Blackbox**: Monitor from the outside (e.g., HTTP probe, ping). Tests what the user sees.
- **Whitebox**: Monitor from the inside (e.g., `/metrics` endpoint). Provides internal system state.
- Best practice: Use both. Blackbox for SLO measurement, whitebox for debugging.

**Q: How do you handle alert storms?**
- **Grouping**: Alertmanager groups related alerts.
- **Inhibition**: Suppress lower-severity alerts when higher ones fire.
- **Silencing**: Temporarily mute during maintenance.
- **Aggregation**: Alert on aggregated symptoms (error rate) rather than individual events.
- **Routing**: Route different severities to different channels.

**Q: Explain context propagation in distributed tracing.**
- When Service A calls Service B, it injects trace context (trace ID + span ID) into HTTP headers.
- W3C TraceContext format: `traceparent: 00-<trace-id>-<span-id>-<flags>`.
- Service B extracts the context and creates a child span linked to the parent.
- This allows building a complete trace tree across all services.

---

## License

This project is for educational and lab purposes. All tools used are open source.
