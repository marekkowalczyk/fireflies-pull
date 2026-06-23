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
- [`san`](https://github.com/marekkowalczyk/sanitize) _(optional)_ — for clean kebab-case filenames; falls back to basic ASCII slugification

## Installation

```bash
git clone https://github.com/marekkowalczyk/fireflies-pull.git
ln -s "$PWD/fireflies-pull/fireflies-pull" /usr/local/bin/fireflies-pull
```

Add your API key to your shell environment:

```bash
echo 'export FIREFLIES_API_KEY=your_key_here' >> ~/.env
```

## Usage

```
fireflies-pull                       # fetch most recent transcript → ./
fireflies-pull --output DIR          # save to DIR
fireflies-pull --id MEETING_ID       # fetch a specific meeting
fireflies-pull --id ID --output DIR  # specific meeting, specific directory
```

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success — file path printed to stdout |
| 1 | Transcript found but AI summary not ready yet — try again in a few minutes |
| 2 | Error — API failure, missing key, or no transcripts found |

### Example

```bash
# Fetch latest and pipe the path to your editor
fireflies-pull --output ~/notes/ | xargs mate
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

## License

MIT © 2026 Marek Kowalczyk
