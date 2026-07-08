#!/usr/bin/env bash
set -euo pipefail

# Upload dataset/ ou un LoRA vers S3 (mode DISTRIBUTED).
#
# Exemples:
#   S3_BUCKET=... S3_PREFIX=infographiste-virtuel ./scripts/upload_to_s3.sh dataset
#   S3_BUCKET=... S3_PREFIX=infographiste-virtuel ./scripts/upload_to_s3.sh lora/my_lora.safetensors

SRC="${1:-}"
if [[ -z "${SRC}" ]]; then
  echo "Usage: $0 <dataset|path/to/file>"
  exit 1
fi

: "${S3_BUCKET:?S3_BUCKET requis}"
: "${S3_PREFIX:=infographiste-virtuel}"

if [[ -d "${SRC}" ]]; then
  aws s3 sync "${SRC}" "s3://${S3_BUCKET}/${S3_PREFIX}/${SRC}" --delete
  echo "OK: sync ${SRC} -> s3://${S3_BUCKET}/${S3_PREFIX}/${SRC}"
else
  aws s3 cp "${SRC}" "s3://${S3_BUCKET}/${S3_PREFIX}/${SRC}"
  echo "OK: cp ${SRC} -> s3://${S3_BUCKET}/${S3_PREFIX}/${SRC}"
fi

