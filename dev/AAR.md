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
