#!/bin/sh
# scan-design-token-violations.sh
#
# Purpose:
#   Enforce a per-file baseline for raw design-token literals in Swift sources.
#   Files outside the design-system module must not introduce new occurrences of:
#     - font.system(size:       — raw font sizes
#     - padding(<edge,> N       — raw integer padding (integer literal, optional edge arg)
#     - cornerRadius(N)         — raw integer cornerRadius
#     - Color.secondary.opacity(  — raw secondary-color opacity
#
# What it DOES NOT flag:
#   - Color(nsColor:...) / Color.accentColor / Color.primary — legitimate system colors
#   - Files under Sources/ColorAnimaAppWorkspaceDesignSystem/ — the token library itself
#   - Files under Sources/Generated/ — machine-generated code
#   - Files under Tests/ — test fixtures may use literals freely
#
# Baseline file: scripts/design-token-baseline.txt
#   Format: <relative-file-path><TAB><count>  (sorted alphabetically)
#   Maintainers update it with: sh scripts/scan-design-token-violations.sh --update-baseline
#
# Exit codes:
#   0 — clean (no file exceeds its baseline)
#   1 — one or more files exceed their baseline
#   2 — usage error
#
# Flags:
#   (none)             Compare current counts against baseline; fail if any increased.
#   --update-baseline  Regenerate scripts/design-token-baseline.txt from current state.
#   --list             Print current per-file violation counts; do not compare.
#   -h / --help        Show usage and exit.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
BASELINE_FILE="${SCRIPT_DIR}/design-token-baseline.txt"
SOURCES_ROOT="${REPO_ROOT}/Sources"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
MODE="check"
for arg in "$@"; do
  case "$arg" in
    --update-baseline) MODE="update" ;;
    --list)            MODE="list"   ;;
    -h|--help)
      sed -n '2,/^set -eu/{ /^set -eu/q; p }' "$0"
      exit 0
      ;;
    *)
      printf 'error: unknown argument: %s\n' "$arg" >&2
      printf 'usage: %s [--update-baseline | --list | -h]\n' "$0" >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Detect scanner: prefer ripgrep, fall back to grep -E
# ---------------------------------------------------------------------------
if command -v rg >/dev/null 2>&1; then
  USE_RG=1
else
  USE_RG=0
fi

# scan_pattern <pattern>
# Emit "relative/path:count" lines (count > 0 only), paths relative to REPO_ROOT.
scan_pattern() {
  _pat="$1"
  if [ "$USE_RG" = "1" ]; then
    rg --count \
      --glob '*.swift' \
      --glob '!Sources/ColorAnimaAppWorkspaceDesignSystem/**' \
      --glob '!Sources/Generated/**' \
      "$_pat" \
      "${SOURCES_ROOT}" 2>/dev/null \
      | sed "s|^${REPO_ROOT}/||" \
      | grep -v ':0$' || true
  else
    find "${SOURCES_ROOT}" -name '*.swift' \
      ! -path '*/ColorAnimaAppWorkspaceDesignSystem/*' \
      ! -path '*/Generated/*' \
      | while IFS= read -r f; do
          cnt=$(grep -cE "$_pat" "$f" 2>/dev/null || true)
          if [ "${cnt:-0}" -gt 0 ]; then
            rel="${f#${REPO_ROOT}/}"
            printf '%s:%s\n' "$rel" "$cnt"
          fi
        done
  fi
}

# ---------------------------------------------------------------------------
# collect_counts
# Emit "relative/path<TAB>total_count" lines, sorted, for all files with > 0 violations.
# Accumulates counts across all four patterns using awk.
# ---------------------------------------------------------------------------
collect_counts() {
  {
    scan_pattern 'font\.system\(size:'
    scan_pattern 'padding\(\s*(\.\w+,\s*)?\d+'
    scan_pattern 'cornerRadius\([0-9]'
    scan_pattern 'Color\.secondary\.opacity\('
  } | awk -F: '
    NF >= 2 {
      # last field is the count; everything before is the path (handles paths with colons)
      n = split($0, parts, ":")
      cnt = parts[n]
      path = parts[1]
      for (i = 2; i < n; i++) path = path ":" parts[i]
      counts[path] += cnt
    }
    END {
      for (p in counts) printf "%s\t%s\n", p, counts[p]
    }
  ' | sort
}

# ---------------------------------------------------------------------------
# MODE: list
# ---------------------------------------------------------------------------
if [ "$MODE" = "list" ]; then
  result="$(collect_counts)"
  if [ -z "$result" ]; then
    printf 'No design-token violations found in scanned sources.\n'
  else
    printf 'Current per-file violation counts:\n'
    printf '%s\n' "$result"
  fi
  exit 0
fi

# ---------------------------------------------------------------------------
# MODE: update-baseline
# ---------------------------------------------------------------------------
if [ "$MODE" = "update" ]; then
  printf 'Regenerating baseline: %s\n' "$BASELINE_FILE"
  collect_counts > "$BASELINE_FILE"
  total=$(wc -l < "$BASELINE_FILE" | tr -d ' ')
  printf 'Baseline updated: %s file(s) with violations recorded.\n' "$total"
  exit 0
fi

# ---------------------------------------------------------------------------
# MODE: check (default)
# Use awk to join current counts against baseline and detect regressions.
# ---------------------------------------------------------------------------
current="$(collect_counts)"

# Build baseline content (empty string if file absent)
if [ -f "$BASELINE_FILE" ]; then
  baseline_content="$(cat "$BASELINE_FILE")"
else
  baseline_content=""
fi

# Feed both streams to awk: lines tagged B (baseline) or C (current).
# awk detects where current > baseline.
failures="$(
  {
    printf '%s\n' "$baseline_content" | awk -F'\t' 'NF==2 { printf "B\t%s\t%s\n", $1, $2 }'
    printf '%s\n' "$current"         | awk -F'\t' 'NF==2 { printf "C\t%s\t%s\n", $1, $2 }'
  } | sort -t$'\t' -k2,2 | awk -F'\t' '
    {
      tag  = $1
      path = $2
      cnt  = $3 + 0
      if (tag == "B") { base[path] = cnt }
      else            { cur[path]  = cnt }
    }
    END {
      for (p in cur) {
        b = (p in base) ? base[p] : 0
        c = cur[p]
        if (c > b) {
          printf "%s\t%s\t%s\n", p, b, c
        }
      }
    }
  ' | sort
)"

if [ -n "$failures" ]; then
  count=$(printf '%s\n' "$failures" | wc -l | tr -d ' ')
  printf 'FAIL: design-token violations increased in %s file(s):\n' "$count"
  printf '%s\n' "$failures" | while IFS=$'\t' read -r path base cur; do
    delta=$(( cur - base ))
    printf '  %s: baseline=%s, current=%s, delta=+%s\n' "$path" "$base" "$cur" "$delta"
  done
  printf '\nFix the violations or run --update-baseline after intentional migration.\n'
  exit 1
else
  printf 'OK: no design-token violations exceed the recorded baseline.\n'
  exit 0
fi
