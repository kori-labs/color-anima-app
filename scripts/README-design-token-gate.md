# Design Token Violation Gate

`scripts/scan-design-token-violations.sh` enforces a per-file baseline for raw
design-token literals across Swift sources (excluding the design-system module
itself and generated code).

## What it checks

| Pattern | What it catches |
|---|---|
| `font.system(size:` | Raw numeric font sizes |
| `padding(<edge,> N` | Raw integer padding values |
| `cornerRadius(N)` | Raw integer corner radius |
| `Color.secondary.opacity(` | Raw secondary-color opacity |

Files under `Sources/ColorAnimaAppWorkspaceDesignSystem/`, `Sources/Generated/`,
and `Tests/` are excluded.

## Baseline philosophy

`scripts/design-token-baseline.txt` records the current per-file violation count.
CI fails only when a file's count **increases** from its baseline — existing
violations are tolerated until intentionally migrated. Improvements (count goes
down) are always welcome and automatically pass.

## Usage

```sh
# Check against baseline (used by CI):
sh scripts/scan-design-token-violations.sh

# Print current counts without comparing:
sh scripts/scan-design-token-violations.sh --list

# Update baseline after intentional migration work:
sh scripts/scan-design-token-violations.sh --update-baseline
```

## Updating the baseline

After migrating a file to design tokens, run `--update-baseline` and commit the
updated `scripts/design-token-baseline.txt` alongside your view changes. The
updated baseline becomes the new floor — it can never increase back.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Clean — no file exceeds its baseline |
| 1 | One or more files exceed their baseline |
| 2 | Usage error (unknown flag) |
