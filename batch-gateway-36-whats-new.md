# What's new in Batch Gateway in Red Hat OpenShift AI 3.6

*Batch inference that waits for spare capacity: one dispatch path, a PostgreSQL queue option, and dispatch gates that keep interactive traffic first.*

## Batch inference in one minute

Some AI work doesn't need an answer right away. Scoring a document collection overnight, evaluating a new model against thousands of prompts, or labeling a dataset can all run in the background, as long as the job finishes within a reasonable window.

Batch Gateway in Red Hat OpenShift AI, built on the open source llm-d project, is designed for that work. You upload a file of requests, submit it as a batch job, and come back later for the results. The API follows the familiar OpenAI Files and Batches pattern, so existing clients and tools work with little or no change. Behind the API, Batch Gateway sends each request to the same llm-d model servers that handle your interactive traffic, but it does so carefully: batch work fills spare capacity instead of competing with users who are waiting for a response.

With Red Hat OpenShift AI 3.6, Batch Gateway is generally available. This post explains what changed in Red Hat OpenShift AI 3.6 Batch Gateway and the ideas behind it, without the YAML.

![Diagram of the 3.6 Batch Gateway flow: Batch API, batch processor, request queue in Redis or PostgreSQL, dispatcher with worker pools and dispatch gates, inference gateway with priority bands, and model servers. PostgreSQL stores jobs and metadata; object storage stores files.](assets/batch-gateway-36-concept.svg)

*Figure 1. In 3.6, every batch request takes the same path: it waits in a queue, and a dispatcher sends it only when the model has room.*

## The big picture

A batch job moves through a few simple stages:

1. **Batch API.** Clients upload a JSONL file, create a batch, check its progress, and download the output. Job records and progress live in PostgreSQL; the files themselves live in S3-compatible object storage.
2. **Batch processor.** The processor picks up the job, splits it into individual requests, and places them on a request queue. It later collects the results and writes the output file.
3. **Request queue.** Requests wait here until it is their turn. In 3.6 the queue can be Redis (or Valkey) or PostgreSQL.
4. **Dispatcher.** A pool of workers takes requests off the queue. Before each send, a *dispatch gate* checks whether the model has room.
5. **Inference gateway and model servers.** The llm-d inference gateway routes each request to a model server, giving interactive traffic priority over batch traffic.

The Batch Gateway Operator deploys and manages all of these components from a single `LLMBatchGateway` resource. You enable the operator once through Red Hat OpenShift AI, then create one `LLMBatchGateway` for each batch service you want to run.

## What's new in 3.6

| What changed | Why it matters |
|---|---|
| **One dispatch path for every request** | Every batch request now goes through the queue and dispatcher. Capacity checks, worker pools, and priority rules apply to all batch traffic, not just some of it. |
| **PostgreSQL as the request queue** | The dispatcher can queue requests in the same PostgreSQL database Batch Gateway already uses for job records. You can run Batch Gateway without Redis. |
| **Per-user quotas in PostgreSQL** | The new `sql-quota` gate enforces rate limits or concurrency caps per user or tenant, counted in PostgreSQL. |
| **Resumable batches** | The processor can resume an interrupted batch instead of starting it over. |
| **Self-cleaning job store** | The garbage collector now also finds and cleans up orphaned jobs that normal expiry missed. |
| **Per-model routing and priority** | Each model gets its own route, queue, and priority class (inference objective), so one model's backlog doesn't hold up another. |
| **More endpoints** | You can allow inference paths beyond the standard OpenAI batch endpoint list. |

The rest of this post looks at the three ideas that matter most: the queue, dispatch gates, and flow control.

## PostgreSQL as the request queue

Before 3.6, the dispatcher's request queue lived in Redis, as a *sorted set*: a list kept in deadline order so the most urgent request is always at the front. That works well, but it means running and operating Redis alongside PostgreSQL.

In 3.6 you can choose PostgreSQL instead. The PostgreSQL queue was designed to behave the same way as the Redis sorted set:

| Behavior | Redis sorted set | PostgreSQL queue |
|---|---|---|
| Order of dispatch | Earliest deadline first | Earliest deadline first, then submission order |
| Claiming a request | The dispatcher claims it with a time-limited lease | The same: claims are leased and protected so only one dispatcher can complete a request |
| If a dispatcher crashes | Its claimed requests are delivered again after the lease expires | The same |
| Dispatch gates per queue | Yes | Yes |
| Backlog metrics | Yes | Yes |

How does a database act like a queue at scale? The PostgreSQL queue splits each queue into partitions and shares the partitions among the running dispatchers, so dispatchers don't fight over the same rows. Each dispatcher picks up the oldest-deadline requests in its own partitions and skips anything another dispatcher has already locked. During a rolling restart, a dispatcher finishes its in-flight work before handing its partitions to a peer. If a dispatcher stops unexpectedly, its partitions move to the others once its lease runs out.

**When to choose which:**

- **Choose PostgreSQL** when you want fewer moving parts. Batch Gateway already needs PostgreSQL for job records, so the queue reuses the same database and credentials, and your queue data gets PostgreSQL's durability and backups.
- **Choose Redis or Valkey** when you already operate it, or when you want to use gates that read their data from Redis.

Either way, plan PostgreSQL connections for the whole service: the batch processor, the dispatcher, and any other applications share the database's connection limit.

## Dispatch gates: "is there room?"

A dispatch gate is a checkpoint between the queue and the model. Before the dispatcher sends a request, it asks the gate whether now is a good time. The gate answers in one of three ways:

- **Send now.** There is capacity, so the request goes to the model.
- **Wait.** The worker holds the request briefly and asks again.
- **Retry later.** The request goes back on the queue for another turn.

Gates fall into a few families:

| Family | Example gates | What they decide |
|---|---|---|
| **Capacity** | `prometheus-budget`, `prometheus-saturation`, `endpoint-scrape`, `prometheus-query` | How busy the model servers are, from live metrics. `prometheus-budget` keeps a small reserve so interactive users always have headroom. |
| **Externally controlled** | `redis`, `redis-leased-rate` | A budget or a maximum rate that another system sets, such as a capacity planner or a controller. |
| **Limits and quotas** | `local-max-concurrency`, `sql-quota`, `redis-quota` | How many requests may be in flight, or how many a user or tenant may send in a time window. |
| **Combinations** | `composite`, `wait-on-refuse` | Several gates at once (the most restrictive answer wins), or waiting in memory instead of re-queuing. |

You attach gates to a queue or to a worker pool. A typical setup puts a capacity gate on each model's queue, so batch requests flow freely when the cluster is quiet and slow down automatically when interactive load rises.

Gates that read metrics are careful when they can't get data. Most capacity gates *fail closed* by default: if the metrics are unavailable, they stop sending batch traffic rather than risk overloading the model.

## Flow control: interactive first, batch fills the gaps

Flow control in 3.6 works in layers, each with a clear job.

**Layer 1: the dispatcher decides how much to send.** Each worker pool has a fixed number of workers, and each worker sends one request at a time, so the pool size caps how much batch work is in flight. Pools are isolated: if one model's pool is saturated, other pools keep moving. Gates then decide, request by request, whether there is room right now.

**Layer 2: the inference gateway decides what goes first.** Every request carries a priority class, called an *inference objective*. Interactive traffic uses a high priority. Batch traffic uses a low, *sheddable* priority, which means that when the model servers are saturated, batch requests are the first to give way. Within the batch class, requests are ordered by their job deadline, so urgent jobs go ahead of jobs with time to spare.

**Layer 3: the processor tells the gateway what it knows.** When the processor plans a request, it attaches the time remaining until the job's deadline, the request's priority class, and, when enabled, a tenant identifier so the gateway can share capacity fairly between tenants.

The result: when interactive users are busy, batch work slows down on its own. When the cluster goes quiet, batch work speeds up and uses capacity that would otherwise sit idle.

## Removed and deprecated in 3.6

Moving to a single dispatch path removed the older synchronous mode and the settings that only it used.

| Removed or deprecated | What to use instead |
|---|---|
| Synchronous dispatch (`dispatchMode: sync`) | Asynchronous dispatch is the only mode. The `dispatchMode` field is deprecated and accepts only `async`; you can leave it out. |
| `globalInferenceGateway` | Configure each model under `modelGateways`, with its inference pool. |
| Top-level `spec.redis` | Configure the queue under `asyncConfig.redis`, or use `asyncConfig.sql` for PostgreSQL. |
| Per-gateway retry, timeout, and TLS settings | Use the async settings: `resultPollTimeout`, `drainTimeout`, and `asyncConfig.tls`. |
| Redis or Valkey as the job database (`dbBackend`) | PostgreSQL is the job database. Redis and Valkey remain available as the request queue. |
| `progressTTLSeconds` (deprecated) | `progressUpdateInterval` |
| `asyncConfig.replicas` | Kept for compatibility but ignored; it no longer scales or suspends the dispatcher. |

## Upgrading from 3.5

Batch Gateway in 3.5 used synchronous dispatch by default, and 3.6 does not convert existing resources automatically. A 3.5 gateway that still uses synchronous dispatch reports a `ValidationFailed` condition after the upgrade until you re-create it with an asynchronous configuration.

To upgrade smoothly:

1. Let running batches finish, or stop submitting new ones and wait for the queue to drain.
2. On 3.5, switch the gateway to asynchronous dispatch: add an `asyncConfig` with a Redis queue and replace `globalInferenceGateway` with a `modelGateways` entry for your model. 3.5 already supports this mode.
3. Upgrade Red Hat OpenShift AI to 3.6.
4. Optionally, move the queue from Redis to PostgreSQL once the Redis queue is empty.

Job records in PostgreSQL and files in object storage are kept across the change.

## Summary

Batch Gateway in Red Hat OpenShift AI 3.6 is about sending batch work at the right time. Every request now takes one well-defined path: it waits in a queue, a dispatcher checks a gate before sending it, and the inference gateway keeps interactive users first. PostgreSQL can now hold that queue, so you can run batch inference with one database instead of a database and a cache. And because the model only sees batch traffic when it has room, you can put idle GPU capacity to work without slowing down the people who are waiting for answers.

## Learn more

- [llm-d project](https://llm-d.ai)
- [llm-d Batch Gateway (upstream project) on GitHub](https://github.com/llm-d/llm-d-batch-gateway)
- [llm-d async dispatcher on GitHub](https://github.com/llm-d/llm-d-async)
- [OpenAI Batch API guide](https://platform.openai.com/docs/guides/batch)
