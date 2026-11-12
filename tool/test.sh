#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

jobs="${TEST_JOBS:-$(getconf _NPROCESSORS_ONLN)}"

flutter test --coverage --concurrency "$jobs"
tool/check_core_coverage.sh
