# fireflies-pull — Development Roadmap

## Immediate (low effort, high value)

### `--list` flag
Show recent N transcripts so the user can find an ID without opening the Fireflies web UI.

```
fireflies-pull --list [N]   # default N=10
```

Output (tab-separated, pipe-friendly):
```
2026-06-23  ASxwZxCstx  Q3 Planning — Product & Engineering
2026-06-20  BRyzWyDtuy  1:1 Marek / Anna
```

The `transcripts` query already accepts a `limit` param — needs only a new display path, no new GraphQL fields.

### `--stdout`
Print Markdown to stdout instead of writing a file.

```bash
fireflies-pull --stdout | llm "summarize action items"
fireflies-pull --id ID --stdout | pbcopy
```

Mutually exclusive with `--output`. File path is not printed when `--stdout` is used.

### `--no-summary`
Omit the Fireflies AI Summary block. Useful when feeding raw transcripts to an LLM that will do its own summarization, avoiding summary-of-summary artifacts.

### Action items as a checklist
Currently `action_items` is dumped as a raw text blob. Parse newlines into `- [ ] …` entries.

```markdown
### AI Action Items

- [ ] Schedule follow-up with design team
- [ ] Send Q3 numbers to stakeholders
```

---

## Near-term

### Topics and keywords formatting
- Topics: bulleted list instead of comma-joined string
- Keywords: could be rendered as `#hashtags` for Obsidian compatibility (opt-in flag)

### Speaker stats
Append a table to the summary block with per-speaker word count and approximate talk-time percentage. All data is already present in `sentences` — just needs a counter.

```markdown
### Speaker Stats

| Speaker       | Words | Share |
|---------------|-------|-------|
| Marek         |  1842 |  61 % |
| Anna          |  1180 |  39 % |
```

### Rate-limit handling
The Fireflies free tier allows 50 requests/day. On a 429 response, print a clear message with the reset time (from `Retry-After` header if present) and exit 2.

### Date field validation
The `date` field is treated as milliseconds since epoch. If the parsed year falls outside a plausible range (e.g. < 2015 or > current year + 1), warn to stderr and fall back to today's date rather than silently writing a nonsense date.

---

## Larger directions

### Batch fetch (`--since DATE` / `--limit N`)
Fetch multiple transcripts in one invocation. Useful for initial sync or catching up after a gap.

```bash
fireflies-pull --since 2026-06-01 --output ~/notes/meetings/
```

Prints one file path per line to stdout. Respects rate limits with a short sleep between requests.

### Local cache
Store raw API responses in `~/.cache/fireflies-pull/<id>.json`. Skip the API call if the cached response already has a complete summary. Eliminates redundant requests during re-formatting or re-processing.

### `--watch` mode
Poll every N minutes and auto-fetch new transcripts as they appear. Useful as a background daemon in post-meeting automation pipelines.

```bash
fireflies-pull --watch --interval 5 --output ~/notes/meetings/
```

---

## Known bugs fixed

- `slugify()` raised `FileNotFoundError` when `sanitize` was not on PATH; the fallback never fired. Fixed by wrapping the `subprocess.run` call in `try/except FileNotFoundError`.
- `slugify()` was calling `san` (file renaming tool) instead of `sanitize` (string sanitizer).
