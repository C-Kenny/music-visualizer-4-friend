#!/usr/bin/env bash
# run-tests.sh — compile-check the sketch then run all unit tests
# Usage: ./run-tests.sh
set -euo pipefail

run_processing() {
  if command -v snap >/dev/null 2>&1; then
    snap run processing cli "$@"
  elif [[ -x /snap/bin/processing ]]; then
    /snap/bin/processing cli "$@"
  elif command -v processing >/dev/null 2>&1; then
    processing cli "$@"
  else
    fail "Processing CLI not found. Install Processing 4 CLI or make 'snap run processing cli' available."
  fi
}

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SKETCH_DIR="$REPO_ROOT/Music_Visualizer_CK"
TESTS_DIR="$REPO_ROOT/tests"

# ── colours ───────────────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

pass() { echo -e "${GREEN}✓ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }
info() { echo -e "${YELLOW}▸ $1${NC}"; }

# ── 1. Compile smoke test via processing CLI ──────────────────────────────────
info "Compile check: processing cli --build ..."
if run_processing --sketch="$SKETCH_DIR" --build 2>&1 | grep -qi "error"; then
  fail "Sketch failed to compile — fix errors before running tests"
fi
pass "Sketch compiles cleanly"

# ── 2. Ensure Maven is available ──────────────────────────────────────────────
if ! command -v mvn &>/dev/null; then
  fail "Maven not found. Install Maven and rerun tests, e.g. 'sudo apt-get install -y maven' or use your OS package manager."
fi

# ── 3. Unit tests ─────────────────────────────────────────────────────────────
info "Running unit tests..."
cd "$TESTS_DIR"
if mvn --quiet test; then
  pass "All unit tests passed"
else
  fail "Unit tests failed — see output above"
fi
