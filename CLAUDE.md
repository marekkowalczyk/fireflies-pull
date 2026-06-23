# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`fireflies-pull` is a single-file Python CLI tool (the `fireflies-pull` script, no `.py` extension) that fetches a Fireflies.ai meeting transcript via GraphQL and writes it as Pandoc Markdown.

## Running the tool

```bash
FIREFLIES_API_KEY=your_key ./fireflies-pull
FIREFLIES_API_KEY=your_key ./fireflies-pull --id MEETING_ID --output ~/notes/
```

No build step, no dependencies to install. Standard library only.

## Architecture

Everything lives in the single `fireflies-pull` script:

- `graphql(query, variables)` — makes the HTTP POST to the Fireflies GraphQL endpoint, exits on error
- `build_participant_list(t)` — prefers `meeting_attendees` displayName+email pairs over raw `participants`
- `build_markdown(t)` — assembles YAML frontmatter + AI summary block + full transcript; merges consecutive sentences from the same speaker into single paragraphs
- `slugify(text)` — tries the external `sanitize` binary first, falls back to ASCII kebab-case
- `parse_args` / `main` — manual arg parsing (no argparse)

Exit codes: 0 = success (file path printed to stdout), 1 = summary not ready yet, 2 = any error.

## GraphQL schema notes

- Recent transcripts: `transcripts(mine: true, limit: 1)` returns a list
- By ID: `transcript(id: $id)` returns a single object
- Sentences field is `sentences { speaker_name text }` (not `sentence`)
- `keywords` in summary is an array of strings

## Optional dependency

`sanitize` (https://github.com/marekkowalczyk/sanitize) produces cleaner kebab-case slugs from strings. If absent, `slugify()` falls back gracefully. Note: `san` (from the same repo) operates on filenames — `slugify()` uses `sanitize` for string input.
