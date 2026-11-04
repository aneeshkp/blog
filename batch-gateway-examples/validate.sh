#!/usr/bin/env bash
set -euo pipefail

example_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
kubectl_cmd=${KUBECTL:-kubectl}

if output=$("$kubectl_cmd" apply --dry-run=server -f "$example_dir/invalid-both-transports.yaml" 2>&1); then
  printf '%s\n' "$output"
  echo "FAIL: admission accepted mutually exclusive Redis and SQL transports" >&2
  exit 1
fi

if ! grep -Fq 'asyncConfig.redis and asyncConfig.sql are mutually exclusive' <<<"$output"; then
  printf '%s\n' "$output" >&2
  echo "FAIL: server-side dry run failed for a reason other than the expected CEL validation" >&2
  exit 1
fi

echo "PASS: API-server admission rejected the invalid transport combination (expected negative test)."
echo "To test controller semantic validation in a disposable namespace, apply invalid-no-model-gateway.yaml"
echo "and verify Ready=False with reason ValidationFailed, then delete that LLMBatchGateway."
