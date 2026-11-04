# Batch Gateway Operator Article Implementation Plan

> **For agentic workers:** execute natively in this session; validate each deliverable against pinned source before pushing the branch.

**Goal:** Publish a source-grounded, hands-on Red Hat Developer draft about the llm-d Batch Gateway Operator and Red Hat AI Inference 3.6 in the requested blog repository.

**Architecture:** Use the RHOAI/DataScienceCluster installation path as the walkthrough, then trace a namespaced `LLMBatchGateway` through the product-pinned operator and chart sources. Use Redis/Valkey as the primary runnable async transport because it is documented by Red Hat; explain SQL as an experimental alternative only where the pinned source supports it. Use placeholders for cluster observations and release artifacts that cannot be verified.

**Tech Stack:** Markdown, Kubernetes/OpenShift YAML, shell, Go/controller source references, GitHub.

**Spec:** User-provided Batch Gateway article task in the conversation (2026-11-04).

## Global Constraints

- Article body targets 2,200–3,000 words excluding code blocks.
- Do not invent cluster details, outputs, API fields, defaults, validation messages, image tags, or published chart artifacts.
- Cite claims with commit-pinned source paths where possible.
- Distinguish Red Hat-supported/documented behavior from upstream/product-fork source behavior and experimental SQL transport.
- Push requested files to `https://github.com/aneeshkp/blog` on a reviewable branch; do not force-push or overwrite a default branch.

## Review Focus

- The AI Gateway → Batch Gateway Operator ownership chain must be distinct from the separate creation of an `LLMBatchGateway` workload CR.
- SQL queueing must not be described as the default or as equivalent to Redis recovery.
- Invalid configuration must distinguish Kubernetes admission rejection from controller semantic validation/status.
- Commands must be source-verified; outputs must be marked illustrative or omitted because no test-cluster data was supplied.
- Release support and chart/image publication claims must remain explicitly unverified where authoritative 3.6 product evidence is unavailable.

---

### Task 1: Pin and map primary sources

**Files:**
- Create: `batch-gateway-source-notes.md`
- Reference: 3.6 installation handoff, operator product branch, operator-pinned ODH Batch Gateway and llm-d-async commits, upstream `llm-d/llm-d-batch-gateway` tag, two style articles, prior Batch Gateway article.

- [x] Record repository refs/SHAs and inspect installation guidance, operator schema/reconcile code, pinned charts, and request/queue implementations.
- [x] Write a claim-to-source map with exact file/line links and open release questions.
- [x] Verify the product fork relationship and whether SQL is experimental in the pinned 3.6 source.

**Verification:** Every article-critical claim has a commit permalink or is explicitly listed as unverified.

### Task 2: Build validated examples

**Files:**
- Create: `batch-gateway-examples/llmbatchgateway.yaml`
- Create: `batch-gateway-examples/internal-model-route.yaml`
- Create: `batch-gateway-examples/input.jsonl`
- Create: `batch-gateway-examples/create-secret.sh`
- Create: `batch-gateway-examples/submit-batch.sh`
- Create: `batch-gateway-examples/invalid-both-transports.yaml`
- Create: `batch-gateway-examples/invalid-no-model-gateway.yaml`
- Create: `batch-gateway-examples/validate.sh`
- Create: `batch-gateway-examples/README.md`

- [x] Derive the CR from the 3.6 operator CRD/sample; use Redis/Valkey as the primary transport and placeholder credentials.
- [x] Keep the inference pool, model identifier, batch endpoint, and queue configuration consistent across YAML and JSONL.
- [x] Include one admission-rejected example and one controller-semantic-validation example.
- [x] Check YAML/JSON syntax and shell syntax; render the chart when local tooling permits.

**Verification:** `python3 -c` YAML/JSON parsing, `bash -n`, and chart render/schema checks where available. No live-cluster output is fabricated.

### Task 3: Draft the article

**Files:**
- Create: `batch-gateway-operator-blog.md`

- [x] Cover the requested architecture, reconciliation chain, cluster placeholders, DataScienceCluster opt-in, CR, created resources, async lifecycle, API walkthrough, validation, troubleshooting, and production considerations.
- [x] Explain SQL vs Redis accurately and keep the 3.6 artifact/support caveats visible.
- [x] Use a compact text diagram and inline source links without duplicating the prior architecture article.

**Verification:** Count prose words excluding fenced code; target 2,200–3,000. Confirm all requested sections and no unverified output blocks.

### Task 4: Audit and editorial review

**Files:**
- Create: `batch-gateway-review-checklist.md`
- Review: all files above.

- [x] Cross-check each API field, default, rejection, resource, route, and status claim against pinned source.
- [x] Audit every command and placeholder; note commands requiring cluster execution.
- [x] Mark 3.6 product support/artifact claims needing official confirmation.
- [x] Edit for concise first-person technical prose and Red Hat Developer style.

**Verification:** Checklist has no unresolved source mismatch; remaining unknowns are explicit, not silently asserted.

### Task 5: Commit and push the deliverables

**Files:**
- Commit: four requested deliverables, example directory, and this plan.

- [ ] Review `git diff`, verify no credentials or real secrets, and check branch/status.
- [ ] Commit with a descriptive message.
- [ ] Push `batch-gateway-operator-article` to the empty `aneeshkp/blog` repository.

**Verification:** `git status` is clean after push and the remote branch is confirmed.
