#!/usr/bin/env bash
set -euo pipefail

: "${BATCH_NAMESPACE:=batch-inference}"
: "${BATCH_SECRET_ENV_FILE:?Set this to a mode-0600 env file with postgresql-url, redis-url, and s3-secret-access-key keys}"

kubectl create namespace "$BATCH_NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic batch-gateway-secrets \
  --namespace "$BATCH_NAMESPACE" \
  --from-env-file="$BATCH_SECRET_ENV_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -
