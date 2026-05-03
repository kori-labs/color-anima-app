#!/usr/bin/env bash
set -euo pipefail

if [[ -d "Sources/ColorAnimaKernel" ]]; then
  echo "Source fallback directory is not allowed: Sources/ColorAnimaKernel" >&2
  exit 65
fi

if [[ -n "${COLOR_ANIMA_KERNEL_PATH:-}" ]]; then
  if [[ ! -e "$COLOR_ANIMA_KERNEL_PATH" ]]; then
    echo "COLOR_ANIMA_KERNEL_PATH does not exist: $COLOR_ANIMA_KERNEL_PATH" >&2
    echo "For encrypted intake, run ./scripts/fetch-core-binary.sh first." >&2
    exit 64
  fi
else
  if [[ -z "${COLOR_ANIMA_KERNEL_URL:-}" ]]; then
    echo "COLOR_ANIMA_KERNEL_URL is required when COLOR_ANIMA_KERNEL_PATH is unset" >&2
    exit 64
  fi

  if [[ -z "${COLOR_ANIMA_KERNEL_CHECKSUM:-}" ]]; then
    echo "COLOR_ANIMA_KERNEL_CHECKSUM is required when COLOR_ANIMA_KERNEL_PATH is unset" >&2
    exit 64
  fi
fi

if grep -R --line-number --fixed-strings ".binaryTarget(" Package.swift | grep -E 'path:[[:space:]]*"' >/dev/null; then
  echo "Hard-coded local binary target paths are not allowed in Package.swift" >&2
  exit 65
fi

if [[ -n "${COLOR_ANIMA_KERNEL_PATH:-}" ]] && [[ "$COLOR_ANIMA_KERNEL_PATH" != .local-core/* ]]; then
  echo "Local kernel paths must stay under ignored .local-core/" >&2
  exit 65
fi

PACKAGE_DESCRIPTION="$(mktemp)"
swift package describe --type json > "$PACKAGE_DESCRIPTION"
python3 - "$PACKAGE_DESCRIPTION" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    package = json.load(handle)

target_names = {target["name"] for target in package.get("targets", [])}
product_names = {product["name"] for product in package.get("products", [])}

if "ColorAnimaKernel" not in target_names:
    raise SystemExit("ColorAnimaKernel binary target is not active")
if "ColorAnimaKernel" not in product_names:
    raise SystemExit("ColorAnimaKernel product is not active")
PY
rm -f "$PACKAGE_DESCRIPTION"

swift package resolve
swift build --product ColorAnima
