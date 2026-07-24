# After Action Review

Continuous improvement log. Each session ends with a brief review: what went well, what didn't, what to change. This is the POOGI (Process Of Ongoing Improvement) record for this project.

## 2026-06-23 — Initial session: bug fixes, CLAUDE.md, roadmap

**What went well:**
- Bug identification was sharp: caught the `FileNotFoundError` fallback failure and the `san`/`sanitize` tool confusion as distinct issues
- `dev/roadmap.md` came out well-structured — concrete CLI examples, rationale per feature, three clear tiers
- CLAUDE.md captured non-obvious things (GraphQL field names, exit codes, `sentences` not `sentence`) that save real time next session

**What didn't go well:**
- When fixing `san` → `sanitize`, updated three files but missed the Architecture section in CLAUDE.md — caught only at close
- Should have questioned the binary name earlier: the README linked to a repo called "sanitize" but the code called `san`; both were there to read from the start

**What we'll do differently:**
- Before editing a fact that appears in multiple files, grep for all occurrences first
- When a README references an external tool, verify the binary name matches the repo/description before writing it into code

## 2026-06-29 — --list/--last/--help, 1.0.0 release

**What went well:**
- Clarifying questions before implementation caught all the edge cases (optional `--list N`, default help, `--last` vs old implicit default)
- `parse_args` refactor to return `mode` was clean — `main()` dispatch is easy to follow
- Smoke-testing the parser inline before touching the API saved a round-trip
- `.env` / export debugging was methodical: traced shell → bashrc → env → os.environ in one pass
- Caught the README being stale before pushing to GitHub; `.gitignore` added proactively

**What didn't go well:**
- `~/.env` missing `export` keyword caused confusing "key not set" errors even though `echo $VAR` showed the value — took a few exchanges to land on `export | grep` as the diagnostic
- Edit tool rejected a no-op change (README URL was already correct) — small friction but harmless

**What we'll do differently:**
- When diagnosing "env var not found" in a subprocess, go straight to `export | grep VAR` rather than checking sourcing chain first

## 2026-06-29 — Unix citizenship: --stdout, -o, atomic writes, SIGPIPE, tab-separated --list

**What went well:**
- "Unix citizenship" framing produced a clean, prioritized list without scope creep
- All six changes landed in a single commit with no rework
- Smoke-testing `parse_args` inline caught the `--stdout`-alone edge case before it could cause confusion
- Atomic write pattern (`mkstemp` + `rename`) added real robustness with minimal code

**What didn't go well:**
- CLAUDE.md wasn't updated alongside the code changes — caught only at close, same pattern as session 1
- Roadmap `--stdout` entry wasn't ticked until close

**What we'll do differently:**
- After any feature commit, immediately check CLAUDE.md and roadmap for stale entries before moving on

## 2026-06-30 — Bug fix: duplicate date prefix in filenames

**What went well:**
- User caught the edge case immediately from live output; root cause was obvious in one grep
- Fix was minimal (`re.sub` on one line) and used the already-imported `re` — no new dependencies
- Full cycle (fix → commit → push) was fast and clean

**What didn't go well:**
- Nothing significant

**What we'll do differently:**
- When constructing filenames from user-supplied strings, be defensive about prefixes: if the prefix is about to be prepended, strip it from the slug first

## 2026-07-24 — fp --version fix, up-front validation, flag-parity guard, 1.2.1 release

**What went well:**
- Diagnosed the `fp --version` bug from a single screenshot before being told what was wrong — read the exit-0-then-picker behavior as a fall-through, confirmed against the script
- The Socratic design thread (why `-V` not `-v`, "is no-shared-code sensible", "config file?", "runtime `--forwardable-flags`?", "do we need a hook?") landed on a *proportionate* solution each time — resisted over-engineering with concrete reasons (runtime derivation breaks the validate-first property + adds version-skew fallback; a shared config relocates drift rather than removing it; a per-commit hook guards a rare event and isn't portable without a dependency)
- Got argument-parsing *order* right: moved validation ahead of the dependency/TTY probes so a typo is reported as a typo regardless of environment
- Proved the parity check by *injecting* drift (`--format` → exit 1), not just confirming it passes — tested the failure path, not only the happy path
- Applied the long-recurring lesson (sessions 1 & 3): CLAUDE.md was updated *alongside* the code this time, not at close
- Release ritual followed cleanly: ran the parity gate first, split feat/bump commits, annotated tag, pushed branch + tag

**What didn't go well:**
- The parity script shipped two avoidable bugs to its first run, both in a script explicitly marked `#!/usr/bin/env sh`: bashism process substitution `diff <(...) <(...)`, and an over-broad `awk` that scraped `--` (from `set --`) and `-lt` (from `[ ... -lt ]`) out of the arms' *code* lines instead of only the case labels
- Reached for GNU-only tool flags on darwin — `cat -A` failed; had to redo with `sed -n l`. Same portability class as the bashism
- Scratch cleanup used `rm` (aliased to `rm -i`), which hung waiting for a prompt and got backgrounded — should have used `rm -f`

**What we'll do differently:**
- In a `#!/usr/bin/env sh` script, treat bashisms (`<()`, here-strings, `[[ ]]`) as errors by reflex; use temp files. Run the script (not just `sh -n`) before wiring it into anything
- On macOS, don't assume GNU tools: prefer portable equivalents (`sed -n l` over `cat -A`, `od -c` for bytes) and always `sed -i ''` with the explicit empty suffix
- Use `rm -f` for scratch/temp cleanup to avoid interactive `-i` hangs
