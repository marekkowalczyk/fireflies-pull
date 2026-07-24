# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`fireflies-pull` is a single-file Python CLI tool (the `fireflies-pull` script, no `.py` extension) that fetches a Fireflies.ai meeting transcript via GraphQL and writes it as Pandoc Markdown.

`fp` is a small POSIX-`sh` companion script (same repo, separately symlinked) that pipes `fireflies-pull --list` through `fzf` for interactive title/date search, then downloads the selection(s) via `fireflies-pull --id`. Requires `fzf`; degrades with a clear error if absent.

**Design rule — one-directional independence:** `fireflies-pull` must never depend on `fp` or `fzf`; it stays a self-contained, dependency-free, single-file tool usable by any consumer (fp, an LLM pipeline, cron, another picker). `fp` may — and does — depend on `fireflies-pull`, which it invokes on PATH. That dependency runs through `fireflies-pull`'s **CLI contract**, which is its public API: the tab-separated `--list` format (`date\tduration\tid\ttitle`) and the set of flags safe to forward to a download (the *output* flags `-o`/`--output`/`--stdout`, not the *mode* flags `--list`/`--last`/`--id`). "No shared code" is a consequence, not the rule: the two scripts share no module, but they are coupled through that contract. Because nothing at import time enforces it, the contract is guarded rather than trusted: `fireflies-pull` owns the forwardable set as the `FORWARDABLE_FLAGS` constant and exposes it via `fireflies-pull --forwardable-flags`; `fp` keeps a matching inline allowlist (between its `FORWARDABLE` sentinels); and `dev/check-flag-parity.sh` proves the two agree, failing on drift. Adding a download flag means updating `FORWARDABLE_FLAGS`, `fp`'s allowlist, and running that check.

## Running the tool

```bash
./fireflies-pull --list              # list 5 most recent transcripts (tab-separated)
./fireflies-pull --list 10           # list 10 most recent transcripts
./fireflies-pull --last              # download most recent transcript
./fireflies-pull --last --stdout     # write Markdown to stdout
./fireflies-pull --last -o ~/notes/  # download to specific dir (-o = --output)
./fireflies-pull --id MEETING_ID -o ~/notes/
```

No arguments prints help. No build step, no dependencies to install. Standard library only.

`--list` output is tab-separated: `date\tduration_min\tid\ttitle`.

Requires `FIREFLIES_API_KEY` exported in the environment (e.g. via `~/.env` sourced from `~/.bashrc`).

## Architecture

Everything lives in the single `fireflies-pull` script:

- `graphql(query, variables)` — makes the HTTP POST to the Fireflies GraphQL endpoint, exits on error
- `cmd_list(n)` — fetches and prints the N most recent transcripts (id, date, duration, title), then exits
- `fetch_and_save(t, output_dir)` — checks summary readiness, builds markdown; writes atomically via mkstemp+rename, or streams to stdout if `output_dir == "-"`
- `build_participant_list(t)` — prefers `meeting_attendees` displayName+email pairs over raw `participants`
- `build_markdown(t)` — assembles YAML frontmatter + AI summary block + full transcript; merges consecutive sentences from the same speaker into single paragraphs
- `slugify(text)` — tries the external `sanitize` binary first, falls back to ASCII kebab-case
- `parse_args` — manual arg parsing (no argparse); returns `(mode, meeting_id, output_dir, list_n)`. Also handles `--version`/`-V` and `--forwardable-flags` (both short-circuit with no API key/network)
- `FORWARDABLE_FLAGS` — module constant, the authoritative set of download-output flags a wrapper may forward; printed by `--forwardable-flags` and kept in sync with `fp` via `dev/check-flag-parity.sh`
- `main` — dispatches on mode: `help`, `list`, `last`, `id`

`fp` mirrors these on the shell side: it parses/validates its own args up front (before any dependency/TTY probe or network call), accepts an optional leading integer as the list size, and forwards only `FORWARDABLE_FLAGS` to each `--id` download — rejecting anything else with a clear message rather than deferring the error to `fireflies-pull`.

Exit codes: 0 = success (file path printed to stdout), 1 = summary not ready yet, 2 = any error.

## GraphQL schema notes

- Recent transcripts: `transcripts(mine: true, limit: 1)` returns a list
- By ID: `transcript(id: $id)` returns a single object
- Sentences field is `sentences { speaker_name text }` (not `sentence`)
- `keywords` in summary is an array of strings

## Optional dependency

`sanitize` (https://github.com/marekkowalczyk/sanitize) produces cleaner kebab-case slugs from strings. If absent, `slugify()` falls back gracefully. Note: `san` (from the same repo) operates on filenames — `slugify()` uses `sanitize` for string input.
