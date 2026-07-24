# Next Session

## Completed last session (2026-07-24) — released v1.2.0
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
- Release flow that worked well: separate `fix:`/`feat:` commit, then its own `chore: bump version` commit, then annotated tag `vX.Y.Z`, then `git push && git push --tags`. Minor bump for new features (fp → 1.2.0), patch for fixes/perf.
- Naming for symlinked tools: check `command -v` AND interactive shell functions (`whence -w`) before choosing — `ff` was already a `fff` wrapper; picked `fp`.
