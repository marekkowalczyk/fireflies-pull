# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`fireflies-pull` is a single-file Python CLI tool (the `fireflies-pull` script, no `.py` extension) that fetches a Fireflies.ai meeting transcript via GraphQL and writes it as Pandoc Markdown.

## Running the tool

```bash
./fireflies-pull --list         # list 5 most recent transcripts
./fireflies-pull --list 10      # list 10 most recent transcripts
./fireflies-pull --last         # download most recent transcript
./fireflies-pull --id MEETING_ID --output ~/notes/  # download by ID
```

No arguments prints help. No build step, no dependencies to install. Standard library only.

Requires `FIREFLIES_API_KEY` exported in the environment (e.g. via `~/.env` sourced from `~/.bashrc`).

## Architecture

Everything lives in the single `fireflies-pull` script:

- `graphql(query, variables)` — makes the HTTP POST to the Fireflies GraphQL endpoint, exits on error
- `cmd_list(n)` — fetches and prints the N most recent transcripts (id, date, duration, title), then exits
- `fetch_and_save(t, output_dir)` — checks summary readiness, builds markdown, writes file
- `build_participant_list(t)` — prefers `meeting_attendees` displayName+email pairs over raw `participants`
- `build_markdown(t)` — assembles YAML frontmatter + AI summary block + full transcript; merges consecutive sentences from the same speaker into single paragraphs
- `slugify(text)` — tries the external `sanitize` binary first, falls back to ASCII kebab-case
- `parse_args` — manual arg parsing (no argparse); returns `(mode, meeting_id, output_dir, list_n)`
- `main` — dispatches on mode: `help`, `list`, `last`, `id`

Exit codes: 0 = success (file path printed to stdout), 1 = summary not ready yet, 2 = any error.

## GraphQL schema notes

- Recent transcripts: `transcripts(mine: true, limit: 1)` returns a list
- By ID: `transcript(id: $id)` returns a single object
- Sentences field is `sentences { speaker_name text }` (not `sentence`)
- `keywords` in summary is an array of strings

## Optional dependency

`sanitize` (https://github.com/marekkowalczyk/sanitize) produces cleaner kebab-case slugs from strings. If absent, `slugify()` falls back gracefully. Note: `san` (from the same repo) operates on filenames — `slugify()` uses `sanitize` for string input.
