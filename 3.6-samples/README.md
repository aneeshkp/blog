# LLMBatchGateway samples (Red Hat OpenShift AI 3.6)

Sample `LLMBatchGateway` custom resources taken from `opendatahub-io/llm-d-batch-gateway-operator`, `config/samples/` at commit [`9092d9b`](https://github.com/opendatahub-io/llm-d-batch-gateway-operator/tree/9092d9bea43e63af16961e4d16545839588f80a0/config/samples).

| File | Queue transport | Dispatch gate | Changed from upstream? |
|---|---|---|---|
| [`llmbatchgateway-async-sql.yaml`](llmbatchgateway-async-sql.yaml) | PostgreSQL (`asyncConfig.sql`) | `prometheus-budget` on the queue | No, copied as-is |
| [`llmbatchgateway-async-redis.yaml`](llmbatchgateway-async-redis.yaml) | Redis/Valkey (`asyncConfig.redis`) | `prometheus-saturation` on each queue | Yes, gate parameters corrected (see below) |

Replace the example hosts, buckets, pool names and namespaces with your own, and create the `batch-gateway-secrets` Secret before applying.

## Corrections to the Redis sample

Upstream `batch_v1alpha1_llmbatchgateway_async.yaml` uses gate parameter names that llm-d-async does not recognize (checked against `pkg/async/inference/flowcontrol/gate_factory.go`):

| Upstream sample | llm-d-async expects | Effect of the upstream sample |
|---|---|---|
| `prometheus_url` | Nothing; the URL comes from `asyncConfig.prometheusURL` | Ignored |
| `saturation_threshold` | `threshold` | Ignored; the default 0.8 is used |
| No `pool` | `pool` (required for `prometheus-saturation`) | Dispatcher fails to start |
| `redis-quota` with `quota_key` | `address` and `limit` (required), plus optional `attribute`, `mode`, `window` | Dispatcher fails to start |

This copy sets `pool`, `namespace` and `threshold` on each `prometheus-saturation` queue. The `redis-quota` worker-pool gate is commented out with working parameters.

## Settings used by the dispatcher sizing rule

The sizing rule `B ≥ W × T ÷ (t × b)` maps onto these fields:

| Symbol | Field | Sample value |
|---|---|---|
| T, time between polls | `asyncConfig.sql.pollIntervalMs` / `asyncConfig.redis.pollIntervalMs` | 1000 ms |
| B, most requests per poll | `asyncConfig.sql.batchSize` / `asyncConfig.redis.batchSize` | 10 |
| W, requests a worker pool keeps in flight | `asyncConfig.workerPools[].workers`; without a pool, the dispatcher's built-in pool has 8 | 4 (Redis sample) |
| b, gate budget (0 to 1) | Not a field. The gate computes it from Prometheus metrics on every poll. | Shaped by `threshold`, `max_concurrency`, `baseline` |
| t, time per request | Not a field. Measure it from `llm_d_async_async_inference_latency_time_millis`. | — |

## Notes

- `prometheus-saturation` reads `llm_d_epp_flow_control_pool_saturation`, which exists only when flow control is enabled in the EPP. Without it the gate fails open and does not throttle.
- In 3.6 the dispatcher cannot send a bearer token or trust a custom CA to Prometheus, so point `prometheusURL` at a Prometheus that needs neither, not OpenShift's built-in monitoring.
- The operator validates `prometheusURL` only for `prometheus-budget` and `prometheus-saturation` gates on SQL queues and worker pools; other cases fail at dispatcher startup (tracked in RHAI-58489).
