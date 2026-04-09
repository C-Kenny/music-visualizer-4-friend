#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if ! command -v rg >/dev/null 2>&1; then
  echo "[error] ripgrep (rg) is required for pde_style_audit.sh" >&2
  exit 1
fi

REPORT_FILE="/tmp/pde_style_audit_report.txt"
: > "$REPORT_FILE"

echo "Processing PDE style audit"
echo "Repository: $REPO_ROOT"
echo

print_section() {
  local title="$1"
  echo "=== $title ===" | tee -a "$REPORT_FILE"
}

print_section "Potential snake_case identifiers (excluding constants)"
rg -n --glob 'Music_Visualizer_CK/*.pde' '\b[a-z]+_[a-z0-9_]+\b' \
  | rg -v '\b[A-Z0-9_]{3,}\b' \
  | tee -a "$REPORT_FILE" || true

echo | tee -a "$REPORT_FILE"
print_section "Short identifiers (<5 chars), excluding common math exceptions"

# This pattern extracts identifier-like words and filters exceptions.
rg -n -o --glob 'Music_Visualizer_CK/*.pde' '\b[A-Za-z_][A-Za-z0-9_]*\b' \
  | awk -F: '
    {
      file=$1; line=$2; token=$3;
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", token);
      # Skip keywords and common short symbols in math-heavy rendering code.
      if (token ~ /^(if|for|int|void|float|char|long|true|false|null|new|try|catch|else|return|class|final|static|do)$/) next;
      if (token ~ /^(i|j|k|x|y|z|r|g|b|a|t|u|v|dx|dy|dz|cx|cy|cz|sx|sy|tx|ty|pg)$/) next;
      if (length(token) >= 5) next;
      print file ":" line ":" token;
    }
  ' | sort -u | tee -a "$REPORT_FILE" || true

echo | tee -a "$REPORT_FILE"
print_section "Tab indentation check"
rg -n --glob 'Music_Visualizer_CK/*.pde' '\t' | tee -a "$REPORT_FILE" || true

echo
echo "Audit complete. Full report: $REPORT_FILE"
