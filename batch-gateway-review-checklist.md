# Batch Gateway Operator article review checklist

## Source and API accuracy

- [x] API group/version/kind is `batch.llm-d.ai/v1alpha1`, `LLMBatchGateway`.
- [x] Required CR fields, async transport exclusivity, and file-storage exclusivity are checked against the generated CRD for the operator source pinned by the RHOAI-side AI Gateway Operator.
- [x] Controller-only semantic validation is distinguished from CRD/admission rejection.
- [x] The article shows the distinction between Batch Gateway Operator enablement and user creation of an `LLMBatchGateway` workload CR.
- [x] The reconciliation chain is verified against the handoff and AI Gateway Operator source.
- [x] Workload ownership is described from operator tests/source: API server Deployment, processor StatefulSet, GC Deployment, async-processor Deployment, supporting resources, owner references, status, and stale-object cleanup.
- [x] PostgreSQL batch-job queue/metadata is distinguished from Redis/Valkey or SQL async request/result queues and from S3/filesystem file bytes.
- [x] SQL is identified as experimental, with the result-delivery/restart limitation and image-compatibility gate.
- [x] The `Authorization` pass-through persistence caveat is called out; product security owners should confirm the recommended deployment posture.
- [x] The async inference base URL includes the model namespace/name prefix matched by the internal `HTTPRoute`.

## Release compatibility (must be resolved before publication)

- [ ] Product documentation owner confirms the exact Red Hat AI Inference 3.6 support phase for batch inference (TP/GA/other) and approved wording. The latest accessible batch-inference docs reviewed were for 3.5; they identify the feature as Technology Preview.
- [ ] Product release owner confirms the RHOAI/RHAII 3.6 DataScienceCluster API version and supported patch procedure for the target release. (Observed on `rhods-operator.3.6.0`: the DSC CRD serves `v2` and `v3`.)
- [ ] Product release owner confirms that the AI Gateway Operator's RHOAI bundle uses the expected Batch Gateway Operator source/API commit and that the published images correspond to that CRD.
- [ ] Confirm the required operator and operand image digests/tags from the 3.6 product bundle; do not infer them from source branch names or `odh-stable` placeholders.
- [ ] Confirm whether 3.6-promoted Batch Gateway and llm-d-async images support the experimental SQL producer before promoting SQL details beyond the clearly marked alternative.
- [x] Confirm `spec.httpRoute`, cert-manager fields, and their rendered behavior in the exact installed 3.6 CRD/chart before presenting them as available in every 3.6 environment. (The `rhods-operator.3.6.0` CRD has `httpRoute.{enabled,parentRefs,annotations}` and `tls.{enabled,secretName,certManager}`; the operator rendered an owned `batch-gateway-apiserver-tls` Certificate.)
- [ ] Confirm product policy for storing configured pass-through headers in PostgreSQL batch metadata, particularly when `Authorization` is forwarded.
- [ ] Confirm the approved token-lifetime/credential strategy for queued work when a request's Authorization header is captured at submission and may expire before dispatch.

## Commands requiring a live cluster

- [x] Run `oc api-resources` / `oc explain` to verify the installed `DataScienceCluster` and `LLMBatchGateway` schemas.
- [x] Confirm the `DataScienceCluster` opt-in and AI Gateway / Batch Gateway Operator readiness on a RHOAI 3.6 cluster. (Observed existing opt-in: `aigateway` and `batchGateway` `Managed`, `default-aigateway` Ready, both operator Deployments 1/1. The patch itself was not re-applied.)
- [ ] Apply the CR in a disposable namespace after provisioning PostgreSQL, Redis/Valkey, S3-compatible storage, Gateway API resources, model route, and authentication policy.
- [x] Inspect `LLMBatchGateway` status conditions and owned Deployments, StatefulSet, Services, ConfigMaps, Secret references, optional Certificate and HTTPRoute.
- [ ] Execute the sample upload → create → poll → retrieve workflow with an authorized token and a reachable model.
- [x] Run `batch-gateway-examples/validate.sh` against the installed CRD and verify the expected admission rejection.
- [ ] Apply the semantic invalid example only in a disposable namespace; confirm `Ready=False`, reason `ValidationFailed`, then delete it.
- [ ] Test cancellation, partial/error output, TLS, and route attachment where those features are enabled.

## Publication/editing checks

- [x] Embed the 16:9 architecture and concentric lifecycle SVGs with descriptive alt text and captions; visually inspect browser renders.
- [x] Keep the lifecycle retry branch limited to configured transient file-storage retries; do not imply generic inference retries.
- [x] Fill the cluster inventory placeholders with actual `oc`/`kubectl` evidence or keep the fields explicitly marked as placeholders in an editorial draft.
- [x] Do not add sample `kubectl` output that was not captured from a real cluster. (All output blocks were captured from the `rhods-operator.3.6.0` test cluster.)
- [x] Check article prose length is 2,200–3,000 words excluding code blocks. (2,514 words excluding code blocks and tables.)
- [ ] Preserve links to exact commits/line ranges for implementation claims.
- [ ] Keep the article focused on operator ownership/reconciliation and avoid repeating the July 2026 architecture/workflow article.
- [ ] Product/editorial review approves support-status language, install path, and example artifacts before public submission.
