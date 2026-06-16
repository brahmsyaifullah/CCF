#!/usr/bin/env bash
# Run the CCF test suite. Requires bats-core (https://github.com/bats-core/bats-core) and jq.
#   ./tests/run_tests.sh
set -euo pipefail
cd "$(dirname "$0")"

command -v jq >/dev/null 2>&1 || { echo "jq is required"; exit 1; }
if ! command -v bats >/dev/null 2>&1; then
  cat <<'EOF'
bats-core not found. Install it:
  macOS:  brew install bats-core
  Debian: sudo apt-get install -y bats
  npm:    npm i -g bats
EOF
  exit 1
fi

echo "== CCF tests =="
bats ./*.bats
