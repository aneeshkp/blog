#!/usr/bin/env bash
set -euo pipefail

: "${BATCH_URL:?Set BATCH_URL to the external Batch API URL}"
: "${TOKEN:?Set TOKEN to a short-lived bearer token}"

base_url=${BATCH_URL%/}
input_file=${1:-"$(dirname "$0")/input.jsonl"}
headers=(-H "Authorization: Bearer ${TOKEN}")

file_response=$(curl -fsS -X POST "$base_url/v1/files" \
  "${headers[@]}" \
  -F 'purpose=batch' \
  -F "file=@${input_file}")
file_id=$(jq -er '.id' <<<"$file_response")
printf 'Uploaded input file: %s\n' "$file_id"

batch_response=$(curl -fsS -X POST "$base_url/v1/batches" \
  "${headers[@]}" \
  -H 'Content-Type: application/json' \
  -d "$(jq -nc --arg id "$file_id" '{input_file_id:$id,endpoint:"/v1/chat/completions",completion_window:"24h"}')")
batch_id=$(jq -er '.id' <<<"$batch_response")
printf 'Created batch: %s\n' "$batch_id"

while :; do
  batch_status=$(curl -fsS "$base_url/v1/batches/$batch_id" "${headers[@]}")
  status=$(jq -er '.status' <<<"$batch_status")
  printf 'Batch status: %s\n' "$status"
  case "$status" in
    completed|failed|expired|cancelled) break ;;
  esac
  sleep 5
done

output_file_id=$(jq -r '.output_file_id // empty' <<<"$batch_status")
error_file_id=$(jq -r '.error_file_id // empty' <<<"$batch_status")
if [[ -n "$output_file_id" ]]; then
  curl -fsS "$base_url/v1/files/$output_file_id/content" \
    "${headers[@]}" -o output.jsonl
  printf 'Saved output to output.jsonl\n'
  jq -c . output.jsonl
fi
if [[ -n "$error_file_id" ]]; then
  curl -fsS "$base_url/v1/files/$error_file_id/content" \
    "${headers[@]}" -o errors.jsonl
  printf 'Saved errors to errors.jsonl\n'
  jq -c . errors.jsonl
fi

printf 'Batch ID: %s\n' "$batch_id"
