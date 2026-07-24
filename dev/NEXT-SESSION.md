# Next Session

## In progress (2026-07-24) — v1.2.1 (uncommitted)
- [x] `fp -V`/`--version` — was falling through to launch the picker; now prints `fp 1.2.1`
- [x] `fp` validates args up front (before dependency/TTY probe or network): unknown flags/typos fail instantly with a clear message + usage, instead of after the picker via `fireflies-pull`
- [x] `fp` forwards only download-output flags; rejects mode flags like `--last` (rotate idiom rebuilds `"$@"` as the validated forward list)
- [x] **Flag-parity guard** — `fireflies-pull` owns `FORWARDABLE_FLAGS` + `--forwardable-flags`; `fp` keeps a matching allowlist (FORWARDABLE sentinels); `dev/check-flag-parity.sh` proves no drift (tested: catches an injected flag, exit 1)
- [x] Documented the "one-directional independence" rule in CLAUDE.md; README Development section; module docstring
- [x] **Commit + release v1.2.1** — `feat`/`fix` commit, `chore: bump`, tag `v1.2.1`, push. Ran `dev/check-flag-parity.sh` first (green).
- [x] **Drift guard = release-ritual step, no git hook** (decided: solo repo, drift only matters at ship time; a per-commit hook is overhead-heavy and not portable without a dependency). The check is now part of the release flow below.

## Completed earlier (2026-07-24) — released v1.2.0
- [x] Installed `fireflies-pull` on this machine (symlink in `/usr/local/bin`); wired `~/.env` auto-export into dotfiles `src/env.sh` (`set -a`)
- [x] Fixed redundant `./` prefix in printed output path (`os.path.normpath`) — v1.1.1
- [x] gzip transcript downloads: `Accept-Encoding: gzip`, decompress in-memory (no temp files) — v1.1.2
- [x] Added `fp` — interactive fzf transcript picker (standalone POSIX-sh script, symlinked); multi-select, forwards `-o`/`--stdout`
- [x] Hardened `fp` as an interactive Unix citizen: TTY guard, real exit codes (130 abort / 2 error / 1 not-ready), stdout=paths / stderr=diagnostics
- [x] Documented `fp` in README + CLAUDE.md; noted fzf dependency in dotfiles Brewfile

## Carried over
- Format action items as `- [ ] …` checklist instead of raw text blob
- `--no-summary` flag (omit AI summary block for LLM pipelines)

## Next up (designed, not yet built)
- **Show which transcripts are already downloaded** — full architecture captured in `dev/roadmap.md` (Near-term). Key decisions: match on frontmatter `meeting_id` (not filename); scan notes dir(s), no ledger; opt-in `--seen DIR` in core appends a backward-compatible status column; `fp` renders ✓/dimmed rows and defaults the scanned dir to its `-o` target. Good first task for next session.

## New / process
- After any feature commit: immediately update CLAUDE.md + tick roadmap (not deferred to close)
- Release flow that worked well: **run `dev/check-flag-parity.sh` (green)**, then a `fix:`/`feat:` commit, then its own `chore: bump version` commit, then annotated tag `vX.Y.Z`, then `git push && git push --tags`. Minor bump for new features (fp → 1.2.0), patch for fixes/perf (→ 1.2.1). The parity check is the drift guard — it lives here in the ritual, not in a git hook.
- Naming for symlinked tools: check `command -v` AND interactive shell functions (`whence -w`) before choosing — `ff` was already a `fff` wrapper; picked `fp`.
