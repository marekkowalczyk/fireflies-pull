# fireflies-pull

Fetch a [Fireflies.ai](https://fireflies.ai) meeting transcript via the GraphQL API and save it as Pandoc Markdown — ready for further processing, archiving, or feeding into an LLM pipeline.

## What it produces

A single `.md` file with:

- YAML frontmatter (title, date, participants, meeting ID, transcript URL, duration)
- Fireflies AI summary block (overview, topics, keywords, action items)
- Full transcript with speaker labels (`**Speaker Name:** text`) — consecutive turns from the same speaker are merged

No timestamps in the body. The `transcript_url` in frontmatter links back to the exact Fireflies session for audio navigation.

## Requirements

- Python 3.6+
- `FIREFLIES_API_KEY` environment variable ([get yours here](https://app.fireflies.ai/integrations/custom/fireflies))
- [`sanitize`](https://github.com/marekkowalczyk/sanitize) _(optional)_ — for clean kebab-case slugs from strings; falls back to basic ASCII slugification

## Installation

```bash
git clone https://github.com/marekkowalczyk/fireflies-pull.git
ln -s "$PWD/fireflies-pull/fireflies-pull" /usr/local/bin/fireflies-pull
ln -s "$PWD/fireflies-pull/fp" /usr/local/bin/fp   # optional fzf picker (see below)
```

Add your API key to your shell environment:

```bash
echo 'export FIREFLIES_API_KEY=your_key_here' >> ~/.env
```

## Usage

```
fireflies-pull --list [N]            # list N most recent transcripts (default 5)
fireflies-pull --last                # download most recent transcript → ./
fireflies-pull --last -o DIR         # save to DIR (-o is short for --output)
fireflies-pull --last --stdout       # write Markdown to stdout
fireflies-pull --last --output -     # write Markdown to stdout (alias)
fireflies-pull --id MEETING_ID       # download a specific meeting by ID
fireflies-pull --version             # show version
fireflies-pull --help                # show help
```

`--list` output is tab-separated: `date\tduration_min\tid\ttitle` — pipe-friendly for `cut`, `awk`, etc.

### `fp` — interactive fzf picker

`fp` is a small companion script (POSIX `sh`, requires [`fzf`](https://github.com/junegunn/fzf)) that pipes the recent-transcript list through fzf so you search by date/title instead of copying meeting IDs:

```
fp                 # pick from the 30 most recent, download to ./
fp 50              # list 50 instead of 30
fp -o ~/notes/     # forward flags to the download (e.g. -o DIR, --stdout)
fp 50 -o ~/notes/  # combine: list 50, save selection to ~/notes/
fp -h              # help
fp -V              # version
```

In the picker: type to filter, `TAB` to mark several (multi-select downloads all), `Enter` to download, `Esc` to cancel. The meeting ID is hidden from the list but recovered automatically for the download.

`fp` validates its arguments up front, before it fetches or opens the picker: an unknown flag (or a typo like `--outpt`) fails immediately with a clear message instead of after you've already picked a transcript. It forwards only the download-output flags — `-o`/`--output`/`--stdout` — to `fireflies-pull`; mode flags such as `--last` are rejected, since forwarding them would override the transcript you selected.

Typical workflow:

```bash
fireflies-pull --list                          # browse recent meetings
fireflies-pull --list | cut -f3 | head -1 \
  | xargs fireflies-pull --id               # download the most recent by ID
fireflies-pull --last --stdout | llm "summarize action items"
```

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success — file path printed to stdout (or Markdown if `--stdout`) |
| 1 | Transcript found but AI summary not ready yet — try again in a few minutes |
| 2 | Error — API failure, missing key, or no transcripts found |

### Example

```bash
# Fetch latest and open in editor
fireflies-pull --last -o ~/notes/ | xargs mate
```

## Output format

```markdown
---
title: "Q3 Planning — Product & Engineering"
date: 2026-06-23
document_type: Transcript
source: fireflies
meeting_id: "ASxwZxCstx"
transcript_url: "https://app.fireflies.ai/view/..."
organizer: "marek@example.com"
duration: 47 min
participants:
  - "Marek Kowalczyk <marek@example.com>"
  - "Anna Nowak <anna@example.com>"
---

## Fireflies AI Summary

[overview text]

...

## Full Transcript

**Marek Kowalczyk:** Welcome everyone. Today we're looking at...

**Anna Nowak:** Thanks Marek. I wanted to start with the Q3 numbers...
```

## Notes on Fireflies plan limits

- Free: 50 API requests/day
- Pro: 500 requests/day
- Business/Enterprise: 60 requests/minute

One `fireflies-pull` invocation = one API request.

## Development

`fireflies-pull` and `fp` share no code. `fireflies-pull` is a self-contained, dependency-free Python tool that never knows about `fp` or `fzf`; `fp` is a thin `sh` wrapper that depends on `fireflies-pull` through its **CLI contract** — the tab-separated `--list` format and the set of download flags safe to forward. That contract is the coupling between them, so it is guarded rather than trusted:

- `fireflies-pull` owns the authoritative set as the `FORWARDABLE_FLAGS` constant and exposes it via `fireflies-pull --forwardable-flags` (a machine-readable line list; needs no API key).
- `fp` keeps a matching allowlist inline (between the `FORWARDABLE` sentinels), so it can validate arguments instantly without shelling out.
- `dev/check-flag-parity.sh` proves the two agree and fails loudly on drift. Run it before committing a flag change:

  ```bash
  dev/check-flag-parity.sh
  ```

When you add a download flag to `fireflies-pull`, add it to `FORWARDABLE_FLAGS` and to `fp`'s allowlist; the check will remind you if you forget one. See `CLAUDE.md` for the full "one-directional independence" rule.

## License

MIT © 2026 Marek Kowalczyk
