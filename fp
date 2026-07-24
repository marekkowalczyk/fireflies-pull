#!/usr/bin/env sh
# fp — fuzzy-pick Fireflies transcript(s) and download them.
#
# A thin, portable companion to `fireflies-pull`: it pipes the recent-transcript
# list through fzf so you search by date/title instead of copying meeting IDs.
#
# Usage:
#   fp                 pick from the 30 most recent, download to current dir
#   fp 50              list 50 instead of 30
#   fp -o ~/notes/     forward flags to the download (e.g. -o DIR, --stdout)
#   fp 50 -o ~/notes/  combine: list 50, save selection to ~/notes/
#   fp -h              show this help
#
# In the picker: type to filter, TAB to mark several (multi-select),
# Enter to download, Esc to cancel.
#
# Requires: fzf, and `fireflies-pull` on PATH (FIREFLIES_API_KEY in env).
set -u

case "${1:-}" in
  -h|--help)
    # Print the contiguous comment header (skip the shebang), stripping "# ".
    awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"
    exit 0
    ;;
esac

command -v fzf >/dev/null 2>&1 || {
  echo "fp: fzf not found — install it (e.g. brew install fzf)" >&2
  exit 2
}
command -v fireflies-pull >/dev/null 2>&1 || {
  echo "fp: fireflies-pull not found on PATH" >&2
  exit 2
}

# A leading plain-integer arg is the list size; everything else is forwarded
# to the per-transcript download (e.g. -o DIR, --stdout).
limit=30
case "${1:-}" in
  '' | *[!0-9]*) : ;;   # absent or not a bare number — leave default
  *) limit=$1; shift ;;
esac

# --list is tab-separated: date<TAB>duration<TAB>id<TAB>title.
# --with-nth=1,2,4 shows date/duration/title and hides the ID, but fzf still
# returns the whole line, so `cut -f3` recovers the ID for the download.
ids=$(
  fireflies-pull --list "$limit" |
    fzf --multi --delimiter='\t' --with-nth=1,2,4 --no-hscroll \
        --prompt='transcript> ' --height=40% --reverse |
    cut -f3
) || exit 0            # non-zero fzf (Esc/no match) → nothing to do

[ -n "$ids" ] || exit 0

# One download per selected ID; extra args ("$@") pass straight through.
printf '%s\n' "$ids" | while IFS= read -r id; do
  [ -n "$id" ] && fireflies-pull --id "$id" "$@"
done
