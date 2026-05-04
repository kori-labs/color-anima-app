# CLAUDE.md

Operational guide for AI assistants (Claude Code, Codex, Gemini-CLI) working
inside the Color Anima public-shell repo. AGENTS.md is canonical "what is this
repo"; this file is "how to work in it day-to-day".

## Quick read order

1. `AGENTS.md` — repository role, module layout, kernel-binary intake, moat
   policy, banned-types list. Read first; treat its facts as canonical.
2. `CLAUDE.md` (this file) — workflow rules, common scripts, recurring AI
   pitfalls, branch hygiene.
3. `docs/public-shell.md`, `docs/core-binary-intake.md`,
   `docs/gitignore-targets.md` — referenced for specific topics; AGENTS.md
   cross-links to them.

When the two files disagree, AGENTS.md wins. Open a PR to fix the drift; do
not paper over it locally.

## Workflow rule of thumb

- **Targeted build only.** Use `swift build --target <Module>` and
  `swift test --filter <Suite>`. Do not run bare `swift build` or
  `swift test` against the workspace — full workspace builds are slow and
  routinely tickle unrelated targets that the current branch is not meant to
  touch.
- **Test target naming.** Tests for module `ColorAnimaApp{Module}` live in
  `ColorAnimaApp{Module}Tests`. Match this pattern when adding new tests so
  the `--filter` selector stays predictable.
- **Plan instances are gitignored.** `docs/plans/` is excluded by
  `.gitignore`; only directly-tracked files (e.g. plan templates intentionally
  promoted to the repo) ship to remotes. Verify with
  `git status --short --ignored` before assuming a plan-doc edit is part of
  your PR.
- **Label discipline.** Default required CI label is `pr-macos-gate`. Do
  **not** auto-apply `ci/perf` or `ci/rust-boundary`; those are user-applied
  and host-sensitive. See user global rules for the rationale.
- **Manual merge.** Stop at merge-ready. Never run `gh pr merge`. The user
  performs the final merge themselves.

## Banned types reminder

The full banned-type list (moat policy) lives in **AGENTS.md → "Banned types
(moat policy)"**. Do not duplicate it here. If you are about to introduce a
type whose name looks like an internal kernel symbol, stop and re-read that
section before writing code.

## kori-flow / ralph integration

- Plan stack lives at `docs/plans/active/YYYY-MM-DD-topic/` per the kernel
  repo's plan-template convention. A `0-orchestration.md` parent doc collects
  child docs (`1-foo.md`, `2-bar.md`, …) when work fans out.
- Worker prompts mirror the kernel-repo standard prompt (REPO / BRANCH /
  FILE-TO-CREATE / required reading / output / verification / hard
  constraints). Keep them self-contained.
- Multi-PR work uses dependency-aware stacked PRs. The kori-flow skill owns
  branch/worktree gates; the assistant fills slots, it does not invent its
  own queue policy.
- **PR push is the LAST step.** After local verification passes, push the
  branch, open the PR, and stop. Do not poll for CI here; do not merge.

## Common scripts

All scripts live under `scripts/`. Each one is intended to be safe to re-run.

| Script | Purpose |
| --- | --- |
| `scripts/dev-bootstrap.sh` | One-step kernel staging + sanity check (added by this PR; thin wrapper around the fetch + verify scripts). |
| `scripts/fetch-core-binary.sh` | Fetch + decrypt the encrypted kernel xcframework into `.local-core/` using `CoreBinary.env` plus a key from env or macOS Keychain. |
| `scripts/build-macos-app.sh` | Build the local `.app` bundle (release or debug). Requires kernel binary already staged. |
| `scripts/verify-core-binary-intake.sh` | Sanity-check the staged kernel: presence, header surface, `CoreBinary.env` agreement. Run after `fetch-core-binary.sh`. |
| `scripts/release-macos-app.sh` | Local release packaging. Out of scope for routine PR work; see script header. |
| `scripts/smoke-test-macos-app.sh` | Launch + smoke-test the built `.app`. |

If `scripts/dev-bootstrap.sh` is missing in your worktree, your branch
predates the public-shell intake plan — pull `main` or use
`fetch-core-binary.sh` + `verify-core-binary-intake.sh` directly.

## Common pitfalls

Concrete mistakes already observed during this repo's bring-up. Each one
costs at least one wasted iteration when repeated:

- **Assuming the xcframework exposes propagation.** It does not. The current
  C-API surface is preprocess + GPU buffer management only. Do not write
  Swift code that reaches for a `propagate*` entry point — there is no such
  symbol in the binary.
- **Trying to port a banned moat type from a pre-separation snapshot.** This
  is explicitly disallowed; the full list lives in AGENTS.md. Use the
  adapter-based replacement landed in the kernel repo; if the replacement
  isn't published yet, the public-shell stays in interim state until it is.
- **Building `.app` without staging the kernel binary first.** The build
  succeeds, but the running app shows the intake-only screen. That is
  expected interim behavior, not a bug. Run `scripts/dev-bootstrap.sh` (or
  the underlying fetch + verify pair) before re-launching.
- **Confusing intake-only with broken.** When the workspace UI fails to
  launch, the cause is almost always missing kernel binary or the
  adapter-rollout dependency described in AGENTS.md, not a regression in the
  shell.
- **Treating `docs/plans/` as "fully tracked".** It is gitignored. Plan
  template files (`plan-template.md`, `plan-template-reference.md`) are
  intended as repo-canonical references, but check `git ls-files
  docs/plans/` before assuming any plan-doc change will be picked up by a
  PR. If a template needs to ship, that is a separate, intentional commit.
- **Running `swift build` (no `--target`).** Slow, noisy, and frequently
  re-builds modules unrelated to the active branch. Always pass
  `--target`.

## Where to look first by task

| Question | Look here |
| --- | --- |
| "What is this repo for?" | `AGENTS.md` → Repository role |
| "How does the build wire up?" | `AGENTS.md` → Module layout |
| "How do I test my change?" | This file → Workflow rule of thumb |
| "Why doesn't the workspace UI launch?" | `AGENTS.md` → Adapter rollout dependency |
| "How is the kernel binary fetched?" | `AGENTS.md` → Kernel binary intake; `docs/core-binary-intake.md` |
| "What is banned and why?" | `AGENTS.md` → Banned types (moat policy) |
| "How do I add a new C-API function?" | Kernel repo (private) — out of scope here |
| "Can I run a full `swift build`?" | This file → Workflow rule of thumb (no) |
| "Where do plan docs go?" | `docs/plans/active/YYYY-MM-DD-topic/` (gitignored) |

## Branch hygiene

- **Don't touch unrelated dirty files.** A scoped PR stays scoped. If
  `git status` shows untracked files outside your task (e.g. `.DS_Store`,
  unrelated docs, scratch artifacts), leave them alone.
- **Don't auto-clean `.worktrees/` or `.local-core/`.** Both are workspace
  state managed by the user / kori-flow tooling. Removing them mid-PR
  destroys other workers' state.
- **`docs/plans/` is gitignored.** Do not stage plan-instance edits as part
  of an unrelated PR. If a plan doc needs to ship, do it in its own commit
  with explicit intent.
- **Don't skip hooks** (`--no-verify`, `--no-gpg-sign`) unless the user
  asked for it.
- **Don't force-push `main`.** Don't force-push other people's branches.
  Force-push your own feature branch only when needed and only after
  confirming the rewrite is what you want.
- **One branch, one concern.** If you discover a "while I'm here" fix,
  write it down for a follow-up PR rather than slipping it into the current
  diff.
