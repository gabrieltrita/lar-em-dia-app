#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ] || ! [[ "$1" =~ ^[0-9]+$ && "$2" =~ ^[1-9][0-9]*$ ]] || [ "$1" -ge "$2" ]; then
  echo "Usage: tool/test_files.sh SHARD_INDEX SHARD_COUNT" >&2
  exit 64
fi

cd "$(dirname "$0")/.."

find test -name '*_test.dart' | LC_ALL=C sort | awk -v index_="$1" -v count="$2" '(NR - 1) % count == index_'
