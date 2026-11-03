#!/usr/bin/env bash
set -euo pipefail

lcov_file="${1:-coverage/lcov.info}"

awk '
  /^SF:/ {
    file = substr($0, 4)
    tracked = file ~ /lib\/core\// && file !~ /\.(g|freezed|config)\.dart$/
    next
  }
  tracked && /^DA:/ {
    split(substr($0, 4), fields, ",")
    total++
    if (fields[2] > 0) hit++
    else missed[file] = missed[file] " " fields[1]
  }
  END {
    if (total == 0) { print "No lib/core lines found in coverage"; exit 1 }
    printf "lib/core line coverage: %d/%d (%.2f%%)\n", hit, total, 100 * hit / total
    if (hit < total) {
      for (f in missed) print "  " f ":" missed[f]
      exit 1
    }
  }
' "$lcov_file"
