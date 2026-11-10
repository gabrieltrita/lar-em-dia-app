#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "Usage: tool/prepare_web_headers.sh HEADERS_FILE API_BASE_URL" >&2
  exit 64
fi

headers_file="$1"
api_base_url="$2"

if [[ ! "$api_base_url" =~ ^(https://[a-z0-9.-]+(:[0-9]+)?)(/.*)?$ ]]; then
  echo "API_BASE_URL must start with https://host, got: $api_base_url" >&2
  exit 64
fi

sed -i "s|__API_ORIGIN__|${BASH_REMATCH[1]}|g" "$headers_file"
