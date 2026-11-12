#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: tool/merge_coverage.sh OUTPUT LCOV_FILE..." >&2
  exit 64
fi

output="$1"
shift

awk '
  /^SF:/ {
    file = substr($0, 4)
    if (!(file in known)) {
      known[file] = 1
      files[++file_count] = file
    }
    next
  }
  /^DA:/ {
    split(substr($0, 4), fields, ",")
    key = file SUBSEP fields[1]
    if (!(key in hits)) {
      line_count[file]++
      lines[file, line_count[file]] = fields[1]
    }
    hits[key] += fields[2]
  }
  END {
    for (i = 1; i <= file_count; i++) {
      file = files[i]
      print "SF:" file
      hit = 0
      for (j = 1; j <= line_count[file]; j++) {
        line = lines[file, j]
        count = hits[file, line]
        print "DA:" line "," count
        if (count > 0) hit++
      }
      print "LF:" line_count[file] + 0
      print "LH:" hit
      print "end_of_record"
    }
  }
' "$@" > "$output"
