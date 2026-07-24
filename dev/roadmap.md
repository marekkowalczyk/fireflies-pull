# fireflies-pull — Development Roadmap

## Immediate (low effort, high value)

### ~~`--list` flag~~ ✓ done 2026-06-29
~~Show recent N transcripts so the user can find an ID without opening the Fireflies web UI.~~

### ~~`--stdout`~~ ✓ done 2026-06-29
~~Print Markdown to stdout instead of writing a file.~~ Also added `-o` short flag, `--output -` alias, SIGPIPE handling, and atomic writes.

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

### Show which transcripts are already downloaded (design 2026-07-24)
Visually mark, in `fp` (and optionally `--list`), which meetings already exist as
saved notes — so you don't re-download.

**Match on `meeting_id`, never on filename.** The filename (`{date}-{slug}-transcript.md`)
is a lossy projection of the title (titles change, slugs collide). The ground truth
is the `meeting_id:` line already written into every file's YAML frontmatter — so a
title that changed after download still matches correctly.

Architecture (recommended split):
- **Data source: scan, not a ledger.** Grep the notes dir(s) for frontmatter
  `meeting_id` to build the "seen" set. Self-healing (delete a note → auto-unmarked),
  no writable state, no coupling to the writer. A ledger only wins if downloads are
  scattered across unknown dirs — they aren't (user picks `-o`).
- **Location config: `FIREFLIES_NOTES_DIR`** (space/colon list). Unset → no marking,
  silently (feature degrades to current behavior, zero config).
- **Placement: opt-in `--seen DIR` (repeatable) in the core; render in `fp`.**
  `--seen` makes `--list` **append** a trailing status field, leaving the documented
  `date\tduration\tid\ttitle` columns byte-identical (pipelines and `cut -f3` keep
  working). Set-building lives in Python (robust, testable); presentation stays in `fp`.
- **`fp` refinement:** default the scanned dir to `fp`'s own `-o` target (fall back to
  `FIREFLIES_NOTES_DIR`), so "✓" means "already saved *where I'm about to save*."
- **Rendering:** `fp` turns the status field into a leading `✓ ` / dimmed row via
  `fzf --ansi`; core emits no ANSI. Update `--with-nth` for the new display column;
  ID column and `cut` unchanged.

Performance: non-issue — the `--list` network call dominates (~1 s); a grep over the
notes dir is sub-100 ms for thousands of files. Add mtime-keyed caching only if a
library ever gets huge; don't build it preemptively.

Do NOT:
- match by filename/slug (lossy, title-fragile);
- make it default-on (needs config; would change the stable `--list` contract) — opt-in only;
- reorder/reformat the existing 4 `--list` columns (append only);
- reach for SQLite/a DB (a grep over Markdown is the right weight);
- conflate with the raw-JSON local cache below ("fetched into cache" ≠ "saved as a note").

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

## Performance (analysis 2026-07-24)

**Finding: the script is not the bottleneck — it is I/O-bound on the Fireflies API.**
Measured on this machine:

| What | Time |
|---|---|
| Python startup + all local code (`--version`, no network) | ~0.13 s |
| Script's own CPU work during `--list` | ~0.10 s (user+sys) |
| `--list` **wall time** | 0.9–5.4 s, at **2–12 % CPU** (i.e. asleep on the socket) |
| Raw `curl` to endpoint (no Python) | ~0.85 s |

The process spends nearly all its wall time waiting on the network. The 5.4 s
cold run vs. 0.9 s warm run is DNS/TLS/connection setup and API-server variance,
none of which Python controls.

### Do: request gzip  ← the one genuine win
`urllib` does not send `Accept-Encoding` by default, so every transcript download
pulls the uncompressed payload. The server already supports gzip
(`content-encoding: gzip`). Measured on a 122-min transcript:
**150 KB uncompressed → 35.7 KB gzipped (4.2× smaller).**

Add `Accept-Encoding: gzip` to the request headers and decompress the response
(with a fallback if a response ever arrives uncompressed). ~6 lines in `graphql()`.

*Honest scope:* on fast wifi you won't feel it — round-trip latency and server
processing dominate, not payload size. It matters on long meetings and on
slow/metered/mobile links, and it is simply the correct default. Low risk, do it.

### Maybe: two-phase fetch for `--last` / `--id` — conditional, NOT a default win
Today, if the AI summary isn't ready, the script downloads the **entire**
transcript (all `sentences`, 150 KB+) only to check `summary.overview` and exit 1.
Polling a not-ready transcript re-pulls the whole payload each time. A cheap
summary-only pre-query would fix that — **but** it adds a second round-trip to the
*normal* (ready) path, and since latency dominates, that makes the common case
*slower*. Only implement if a real "poll while waiting for summary" workflow
emerges. If built, it should reuse the same summary-only query as the FZF preview
(below).

### Do NOT do (measured dead ends — do not spend time here)
- **Trim Python startup / imports.** Saves milliseconds against a 1–5 s network wall.
- **Replace the `slugify` subprocess** (`sanitize`). One fork+exec, ~10–30 ms,
  save-path only. Noise.
- **Connection pooling / HTTP keep-alive.** One request per invocation; nothing to reuse.
- **Threads / async for a single request.** No concurrency to exploit. (Only
  reconsider if batch fetch lands — then bounded concurrency across *many* requests
  could help, subject to the rate limit.)
- **Rewrite in a "faster" language / compile.** The 0.1 s of CPU is already dwarfed
  by the network; this would change nothing a user can perceive.

---

## CLI ergonomics & interactive selection (FZF / TUI) — ideas 2026-07-24

The tab-separated `--list` output (`date\tduration\tid\ttitle`) is already an
ideal source for interactive pickers. Most of the value here is a few lines of
shell glue, not new Python.

### ~~Do: fzf picker~~ ✓ done 2026-07-24 — shipped as `fp`
Implemented as a small standalone POSIX-`sh` script `fp` in this repo (symlinked
alongside `fireflies-pull`), rather than a shell function — keeps the setup
self-contained and portable. Pipes `--list` into fzf, hides the ID column with
`--with-nth=1,2,4`, recovers it with `cut -f3`, supports multi-select (`TAB`) and
forwards download flags (`-o`, `--stdout`). Name: `fp` chosen over `ff` (already a
`fff` wrapper function on the dev machine — would be shadowed) and `ffp`.

### Do: `--preview ID` mode to power an fzf preview pane
A lightweight subcommand that prints just the AI summary/overview for one ID
(summary-only query — cheap, and the same query the two-phase fetch would use).
Then:

```bash
fzf --preview 'fireflies-pull --preview {3}'
```

gives a live summary preview of the highlighted meeting before downloading.

### Do: multi-select download (pairs with batch fetch)
fzf `--multi` (TAB to mark several) → download all marked in one pass. Natural
companion to the planned `--since` / batch-fetch feature; the picker emits the
selected IDs, batch mode consumes them.

### Do: accept IDs on stdin
Let `fireflies-pull` read IDs from stdin so it composes in a pipe
(`... | fireflies-pull`) without `xargs`. Makes every picker one stage shorter and
enables `fireflies-pull < ids.txt`.

### Maybe: built-in `--pick` subcommand
Detect `fzf` on PATH and run the picker internally (fall back to a numbered menu
if absent), so users don't need the shell function. Convenience only — the shell
function already covers power users.

### Maybe: human-readable `--list --pretty`
Keep tab-separated as the default (machine-friendly, feeds fzf). Add an opt-in
aligned/colorized rendering for reading in the terminal. Optionally a `--json`
list output for jq/other tooling.

### Nice-to-have
- `--open` — after download, open the file in `$EDITOR` (or reveal in Finder).
- fzf `--bind` to yank the selected ID to the clipboard (`pbcopy`).
- Shell completion for flags (bash/zsh).

### Do NOT do
- **A full-screen TUI (Textual/curses/urwid) inside the script.** It breaks the
  single-file, stdlib-only, zero-dependency design that defines this tool, for
  little gain — fzf composition delivers ~90 % of the value in ~10 lines and stays
  Unix-composable. Only revisit if the project ever deliberately becomes an
  installable package rather than a drop-in script.
- **Reimplement fuzzy matching in Python.** Delegate to fzf; don't rebuild it.
- **Make the picker the default no-arg behavior.** Keep help-on-no-args: it's the
  Unix convention and it works on machines without fzf installed. Gate any picker
  behind an explicit flag/subcommand.

---

## Known bugs fixed

- `slugify()` raised `FileNotFoundError` when `sanitize` was not on PATH; the fallback never fired. Fixed by wrapping the `subprocess.run` call in `try/except FileNotFoundError`.
- `slugify()` was calling `san` (file renaming tool) instead of `sanitize` (string sanitizer).
- Filename doubled the date when the meeting title already started with a date (e.g. `2026-06-30-dec-toc-…` → `2026-06-30-2026-06-30-…`). Fixed by stripping a leading `YYYY-MM-DD-` from the slug before prepending `date_str`.
- Printed output path carried a redundant `./` prefix for the default output dir (`./<file>.md`). Fixed in v1.1.1 by normalizing with `os.path.normpath` before printing; relative subdirs and absolute `-o` paths are unaffected.
