# AGENTS.md — Color Anima Public Shell

This file is the canonical entry point for contributors and AI assistants
working in `kori-labs/color-anima-app`. Read this before touching code.

For human-friendly orientation see also `README.md` and the per-doc references
in `docs/`. For project-wide AI behavior, see `CLAUDE.md`.

## 1. Repository role

This repository is the **public-shell** of Color Anima:

- The macOS SwiftUI **app surface** (`Sources/ColorAnima` executable +
  workspace targets).
- The **release intake surface** for the encrypted kernel binary
  (`CoreBinary.env`, `scripts/fetch-core-binary.sh`,
  `scripts/verify-core-binary-intake.sh`).
- Public licensing, security, and contributing material (`LICENSE`,
  `SECURITY.md`, `CONTRIBUTING.md`).

It is **not** the engine repository. Production compute source lives in the
private kernel repo — see Section 11.

License: **PolyForm Noncommercial 1.0.0**. External pull requests are not
accepted (see `CONTRIBUTING.md`). Commercial licensing inquiries:
`rodifish@gmail.com`.

## 2. Quick start

```sh
bash scripts/dev-bootstrap.sh
swift build --target ColorAnima
```

`scripts/dev-bootstrap.sh` is the supported one-shot bootstrap: it fetches and
decrypts the kernel binary into `.local-core/` (when the maintainer key is
available) and prepares the local build environment. Without a maintainer key,
the package still builds with the kernel bridge in unavailable mode.

For day-to-day commands see Section 8 (build / test / labels).

## 3. Module layout

Every SwiftPM target declared in `Package.swift`. The kernel binary target
(`ColorAnimaKernel`) is intake-conditional and only appears when
`COLOR_ANIMA_KERNEL_PATH` or (`COLOR_ANIMA_KERNEL_URL` +
`COLOR_ANIMA_KERNEL_CHECKSUM`) is set.

| Target | Role | Depends on |
| --- | --- | --- |
| `ColorAnimaKernelBridge` | **Sole importer of the binary `ColorAnimaKernel`.** Wraps the C-API in Swift; exposes nothing else. | `ColorAnimaKernel` (binary, conditional) |
| `ColorAnimaAppEngine` | App-side engine client. Calls into the bridge; owns no algorithms. | `ColorAnimaKernelBridge` |
| `ColorAnimaAppWorkspaceApplication` | Workspace orchestration layer (sessions, intents, contracts). | `ColorAnimaAppEngine` |
| `ColorAnimaAppWorkspaceDesignSystem` | Reusable SwiftUI tokens / primitives. | — |
| `ColorAnimaAppWorkspaceCutEditor` | Cut editor surface. | `ColorAnimaAppWorkspaceApplication`, `…DesignSystem` |
| `ColorAnimaAppWorkspacePlatformMacOS` | macOS-specific platform glue. | `…Application`, `…CutEditor` |
| `ColorAnimaAppWorkspaceProjectTree` | Project tree / browser surface. | `…Application`, `…DesignSystem` |
| `ColorAnimaAppWorkspaceShell` | Workspace shell scaffolding. | `…Application`, `…DesignSystem` |
| `ColorAnimaAppWorkspace` | Aggregator umbrella for the workspace stack. | `…AppEngine`, `…Application`, `…CutEditor`, `…DesignSystem`, `…PlatformMacOS`, `…ProjectTree`, `…Shell`, `…AppShell` |
| `ColorAnimaAppShell` | App-shell scaffolding (shared chrome). | — |
| `ColorAnima` (executable) | The macOS app entry point. | `ColorAnimaAppWorkspace`, `ColorAnimaAppShell` |

Test targets mirror the source targets: `ColorAnimaKernelBridgeTests`,
`ColorAnimaAppEngineTests`, `ColorAnimaAppWorkspaceTests`,
`ColorAnimaAppWorkspaceApplicationTests`, `ColorAnimaAppWorkspaceCutEditorTests`,
`ColorAnimaAppWorkspaceProjectTreeTests`,
`ColorAnimaAppWorkspacePlatformMacOSTests`, `ColorAnimaAppWorkspaceShellTests`,
`ColorAnimaAppShellTests`, and the boundary contract test
`ColorAnimaPublicSurfaceTests`.

**Boundary invariant:** `ColorAnimaKernelBridge` is the **only** target that
imports the binary kernel target. Any other target that needs kernel
functionality must consume it through `ColorAnimaAppEngine`.

## 4. Kernel binary intake

The public app does not contain compute source. The `ColorAnimaKernel` SwiftPM
binary target is **intake-conditional** (see `Package.swift:166-172`).

Intake inputs (one of):

- `COLOR_ANIMA_KERNEL_PATH` — path to a local artifact under ignored
  `.local-core/` (default for maintainer machines).
- `COLOR_ANIMA_KERNEL_URL` + `COLOR_ANIMA_KERNEL_CHECKSUM` — approved remote
  SwiftPM artifact.

Without either input, the package still builds; the bridge runs in unavailable
mode.

### Encrypted release flow

1. The kernel maintainer release process publishes
   `ColorAnimaKernel.xcframework.zip.enc` plus checksum sidecars to the public
   app release page.
2. `CoreBinary.env` (tracked) carries version, tag, asset name, and the two
   checksums (encrypted + plaintext). It contains **no** secret material.
3. Maintainer fetch:

   ```sh
   ./scripts/fetch-core-binary.sh
   ```

   The script verifies the encrypted checksum, decrypts into `.local-core/`,
   verifies the plaintext checksum, and leaves
   `.local-core/ColorAnimaKernel.xcframework`.
4. Activate the binary target:

   ```sh
   COLOR_ANIMA_KERNEL_PATH=".local-core/ColorAnimaKernel.xcframework" \
     ./scripts/verify-core-binary-intake.sh
   ```

The decryption key is supplied **only** to maintainers, via either:

- environment variable `COLOR_ANIMA_KERNEL_DECRYPTION_KEY`, or
- macOS Keychain service `color-anima-kernel-release-key`, account
  `kori-labs/color-anima`.

Public forks and external pull requests do **not** receive the key.

Source-of-truth doc: `docs/core-binary-intake.md`. Public-surface boundary
rules: `docs/public-shell.md`. Ignore-rule policy: `docs/gitignore-targets.md`.

## 5. C-API surface (current)

The bridge exposes exactly **seven** `ca_pipeline_*` functions today. All are
C-ABI-only and return integer status codes; none panic across the boundary.

| Function | One-line role |
| --- | --- |
| `ca_pipeline_create` | Create an opaque pipeline context handle. |
| `ca_pipeline_destroy` | Destroy a pipeline context and release its resources. |
| `ca_pipeline_upload_rgba` | Upload an RGBA frame buffer into the pipeline. |
| `ca_pipeline_release_buffer` | Release a buffer handle returned by the pipeline. |
| `ca_pipeline_read_back` | Read back a processed frame from the pipeline. |
| `ca_pipeline_preprocess` | Run the preprocess stage on an uploaded frame. |
| `ca_pipeline_version` | Return the bridge ABI version string. |

**Not exposed by the current public binary:**

- propagation
- tracking
- region extraction
- region rewrite

These remain owned by the kernel repo. New surface area is added by a kernel
release (`scripts/release-public-kernel.sh --bump patch …` in the kernel repo)
followed by a `CoreBinary.env` update here. Do not stage Swift wrappers in this
repo for surface that the binary does not yet expose.

## 6. Banned types (moat policy)

<!-- moat-doc -->

The following identifier vocabulary is **moat-protected**. It must not appear
in this public repo as Swift type names, file names, public API, or
documentation prose outside this section.

Banned identifiers (the public-known vocabulary of the moat):

- `AppModel`
- `CutWorkspaceModel`
- `RasterBitmap`
- `DetectedRegion`
- `Propagation*` (any type name beginning with `Propagation` followed by an
  uppercase letter — e.g. propagation stage observers, propagation kernels,
  propagation contracts)
- `RegionExtractor*` (any type name beginning with `RegionExtractor`)
- `ColorAnimaKernelInternals`
- `ColorAnimaKernelImpl`

Rules:

- Public-shell Swift code must not declare or import these names.
- Public docs (`README.md`, `docs/**`, this file outside this section) must
  not narrate algorithm-class semantics under these names.
- Tests that assert on the absence of these names belong in
  `Tests/ColorAnimaPublicSurfaceTests/`.
- The encrypted kernel binary intentionally does not export these names
  through its `.swiftinterface`. The structural fix lives in the kernel repo's
  Wave 3 Rust port; this list is the surface-level guardrail.

Source-of-truth plans (kernel repo, private):

- `/Users/hataemin/Desktop/codebase/color anima/docs/plans/done/2026-04-28-house-guard/`
  — house-guard red-team audit + structural fix.
- `/Users/hataemin/Desktop/codebase/color anima/docs/plans/done/2026-05-03-app-workspace-adapter-rollout/4-banned-type-reclassification.md`
  — reclassification of public-shell adapter naming away from the banned
  vocabulary.

If you are about to introduce a name that pattern-matches the banned list,
stop and consult the kernel-repo plans above before continuing.

<!-- /moat-doc -->

## 7. Adapter rollout dependency

Public-shell **workspace UI activation** is gated on the kernel-repo plan
`2026-05-03-app-workspace-adapter-rollout` reaching state `cleaned`.

- Current kernel-repo state: `docs-ready`.
- Until that plan is `cleaned`, the workspace targets in this repo build but
  must not be wired up to user-visible app entry flows beyond the existing
  shell scaffolding.

Wave state (mirrors the kernel-repo plan structure):

| Wave | State |
| --- | --- |
| 1A | not-started |
| 1B | not-started |
| 1C | not-started |
| 1D | not-started |
| 1E | not-started |
| 2A | not-started |
| 2B | not-started |
| 2C | not-started |
| 2D | not-started |
| 2E | not-started |
| 3  | not-started |
| 4  | not-started |

When the kernel-repo plan advances, update this table in a follow-up PR — do
not infer state from local code.

## 8. Build / test / labels

Use **targeted** commands only. Do not run full `swift build` or `swift test`
in this repo during normal feature work.

- `swift build --target <Target>` — narrow build of one SwiftPM target.
- `swift test --filter <TestNamePattern>` — narrow run of one test.
- `swift package describe` — confirm the manifest resolves with current intake
  inputs.

CI is the authoritative verification gate. The required CI for this repo is
the single self-hosted macOS PR job:

- **`pr-macos-gate`** — required. One physical Mac Studio host, three sibling
  runners; one PR consumes one runner at a time.

Optional, **user-applied only** labels (do not auto-apply from path filters):

- `ci/perf` — general performance investigation lane.
- `ci/rust-boundary` — Rust-boundary promotion-candidate threshold lane.
- Legacy `perf` alias is being phased out.

Reintroducing path-based perf selection or splitting the PR gate into multiple
macOS jobs requires an explicit policy update first.

## 9. Plan stack convention

This repo follows the same plan-stack convention as the kernel repo.

- Active plans: `docs/plans/active/YYYY-MM-DD-topic/`.
- Templates: `docs/plans/plan-template.md` (and any sibling templates) — these
  are tracked.
- Plan **instances** under `docs/plans/active/**` and `docs/plans/done/**` are
  gitignored. Templates remain visible.
- Parent orchestration docs are numbered (`0-…`, `4-0-…`) with implementation
  detail pushed into numbered child docs (`1-…`, `2-…`, `3-…`).

To verify a plan-only change set:

```sh
git status --short --ignored
```

This surfaces both tracked changes and ignored plan files so you can confirm
your plan additions are visible to your local tools without leaking into PRs.

## 10. Forbidden actions

Do not, in this repo:

- Run `gh pr merge` or otherwise self-merge. Merges require explicit per-batch
  user authorization (see `CLAUDE.md` and the kernel-repo charter).
- Force-push to `main` or any protected branch.
- Skip git hooks (`--no-verify`, `--no-gpg-sign`) or bypass signing.
- Broaden a PR's scope mid-flight to fix adjacent issues. Open a separate
  branch instead.
- Auto-apply `ci/perf` or `ci/rust-boundary` labels from path filters or
  scripts. They are user-applied only.
- Commit plaintext kernel artifacts, decryption keys, GitHub tokens, or any
  customer/project material.
- Introduce algorithm class names from the moat vocabulary (Section 6) into
  Swift sources, file names, or public docs.
- Rebroaden `.gitignore` to hide uncertain files. If something is unsafe for
  public history, remove it instead.
- Add a source fallback target that reimplements compute when the kernel
  binary is absent. The unavailable-mode bridge is the supported fallback.

## 11. Where the engine lives

The engine — extraction, propagation, tracking, rendering, and all associated
algorithms — lives in the **private kernel repository**:

```
/Users/hataemin/Desktop/codebase/color anima/
```

That repo:

- Owns kernel + engine source, tests, and CI.
- Owns the `scripts/release-public-kernel.sh` flow that builds, encrypts,
  tags, and mirrors the kernel binary into this public repo's release page.
- Owns the moat policy (Section 6) and the adapter-rollout plan (Section 7).
- Is **not** a code dependency of this repo at the source level. This repo
  only consumes the encrypted xcframework + headers via `CoreBinary.env`.

If a question is about how the engine works, the answer lives in that repo,
not here. If a question is about how the public app surface ingests, exposes,
or ships the engine, the answer lives here.

## 12. References

Public-repo docs (this repo):

- `README.md`
- `CONTRIBUTING.md`
- `SECURITY.md`
- `LICENSE`
- `docs/public-shell.md`
- `docs/core-binary-intake.md`
- `docs/gitignore-targets.md`
- `Package.swift`

Active plan that produced this file:

- `docs/plans/active/2026-05-04-public-shell-context-and-intake-normalization/1-agents-md-authoring.md`

Kernel-repo plan paths used to source policy (private; paths only, not
contents):

- `/Users/hataemin/Desktop/codebase/color anima/AGENTS.md`
- `/Users/hataemin/Desktop/codebase/color anima/docs/plans/done/2026-04-28-house-guard/`
- `/Users/hataemin/Desktop/codebase/color anima/docs/plans/done/2026-05-03-app-workspace-adapter-rollout/4-banned-type-reclassification.md`
