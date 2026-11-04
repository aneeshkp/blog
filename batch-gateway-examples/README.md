# Batch Gateway examples

These examples are source-checked against the AI Gateway Operator's RHOAI manifest pin (`opendatahub-io/llm-d-batch-gateway-operator` commit `93f1c2c021a7ebae6f44c9e1dd05d7c9a34a46e8`) and its pinned ODH chart/async source commits. Verify the installed CRD with `kubectl explain llmbatchgateway.spec --recursive` before applying to a cluster.

Replace every `<...>` placeholder in `llmbatchgateway.yaml` and configure an actual S3 endpoint, model ID, InferencePool, Gateway, Prometheus service, and namespace labels. Provision a same-namespace Secret with `postgresql-url`, `redis-url`, and `s3-secret-access-key` using an approved secret manager. `create-secret.sh` consumes a private env file; do not commit that file or use demo credentials in production.

`internal-model-route.yaml` is a separate model-side `HTTPRoute` and `InferenceObjective`; it is not created by the Batch Gateway Operator. The `asyncConfig.inferenceGateway.url` in `llmbatchgateway.yaml` includes the same `/<model-namespace>/<model-name>` prefix matched by this route. The referenced internal Gateway must already exist, its listener must allow routes from the labeled model namespace, and the backend InferencePool must exist. Check served API groups and the selected product release before applying.

The example selects Redis/Valkey. The product-pinned source also exposes an experimental SQL transport; the article and source notes describe its additional compatibility and recovery caveats.

`validate.sh` requires a live API server with the matching CRD. It performs a server-side dry run and passes only when the schema rejects the deliberately invalid two-transport manifest. The `invalid-no-model-gateway.yaml` case is different: it passes CRD admission and is intended to make the controller set a `ValidationFailed` status in a disposable namespace.

The `submit-batch.sh` script requires `BATCH_URL`, a short-lived `TOKEN`, `curl`, and `jq`. It makes real API requests; do not run it against a production endpoint without authorization.
