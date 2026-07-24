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
#   fp -V              show version
#
# In the picker: type to filter, TAB to mark several (multi-select),
# Enter to download, Esc to cancel.
#
# Exit status:
#   0    downloaded, or nothing selected / no match
#   1    a selected transcript's AI summary was not ready yet
#   2    fzf or fireflies-pull missing, no controlling terminal, or an error
#   130  cancelled (Esc / Ctrl-C)
#
# stdout carries only the downloaded file path(s); all diagnostics go to stderr.
#
# Requires: fzf, and `fireflies-pull` on PATH (FIREFLIES_API_KEY in env).
set -u

VERSION=1.2.0

case "${1:-}" in
  -h|--help)
    # Print the contiguous comment header (skip the shebang), stripping "# ".
    awk 'NR>1 && /^#/ { sub(/^# ?/, ""); print; next } NR>1 { exit }' "$0"
    exit 0
    ;;
  -V|--version)
    echo "fp $VERSION"
    exit 0
    ;;
esac

# Parse and validate arguments up front — before any dependency/TTY probing or
# network call — so a typo is reported as a typo regardless of environment, and
# instantly rather than after you've fetched the list and picked from it.
#
# A leading plain-integer arg is the list size; the rest is forwarded to the
# per-transcript download (e.g. -o DIR, --stdout).
limit=30
case "${1:-}" in
  '' | *[!0-9]*) : ;;   # absent or not a bare number — leave default
  *) limit=$1; shift ;;
esac

# fp only forwards the download flags it documents; anything else is rejected
# here rather than silently handed to `fireflies-pull --id`, which would only
# error at the very end of the flow. We rebuild "$@" as the exact, validated
# forward list (rotate idiom: append the accepted token(s), shift past them,
# loop $end times).
#
# The accepted flags below MUST match `fireflies-pull --forwardable-flags`.
# dev/check-flag-parity.sh proves it; the FORWARDABLE sentinels mark the set it
# reads, so keep them wrapping exactly the case arms that accept a flag.
end=$#
i=0
while [ "$i" -lt "$end" ]; do
  case $1 in
    # FORWARDABLE-START (kept in sync with fireflies-pull; see dev/check-flag-parity.sh)
    --stdout)
      set -- "$@" "$1"; shift; i=$((i + 1)) ;;
    -o | --output)
      if [ $# -lt 2 ]; then
        echo "fp: $1 requires an argument (an output directory)." >&2
        exit 2
      fi
      set -- "$@" "$1" "$2"; shift 2; i=$((i + 2)) ;;
    # FORWARDABLE-END
    *)
      echo "fp: unknown option '$1'" >&2
      echo "fp: usage: fp [N] [-o DIR | --output DIR | --stdout]  (see 'fp -h')" >&2
      exit 2 ;;
  esac
done

command -v fzf >/dev/null 2>&1 || {
  echo "fp: fzf not found — install it (e.g. brew install fzf)" >&2
  exit 2
}
command -v fireflies-pull >/dev/null 2>&1 || {
  echo "fp: fireflies-pull not found on PATH" >&2
  exit 2
}

# fp is interactive: fzf reads keystrokes from the controlling terminal. Fail
# clearly rather than hang or misbehave when there is no TTY — e.g. under cron,
# CI, or when fp is placed in the middle of a pipe.
if ! (exec </dev/tty) 2>/dev/null; then
  echo "fp: no controlling terminal — fp is interactive and needs a TTY for fzf." >&2
  exit 2
fi

# Fetch the list first so a fetch failure (missing key, no transcripts, network)
# propagates fireflies-pull's own exit code instead of being masked by the pipe.
list=$(fireflies-pull --list "$limit") || exit $?
[ -n "$list" ] || { echo "fp: no transcripts to choose from." >&2; exit 2; }

# --list is tab-separated: date<TAB>duration<TAB>id<TAB>title.
# --with-nth=1,2,4 shows date/duration/title and hides the ID, but fzf still
# returns the whole line, so `cut -f3` recovers the ID for the download.
selection=$(
  printf '%s\n' "$list" |
    fzf --multi --delimiter='\t' --with-nth=1,2,4 --no-hscroll \
        --prompt='transcript> ' --height=40% --reverse
)
status=$?

# Distinguish fzf outcomes instead of collapsing everything to success.
case $status in
  0)   : ;;                                   # one or more rows selected
  1)   exit 0 ;;                              # no match — nothing to do
  130) exit 130 ;;                            # aborted (Esc / Ctrl-C) — propagate
  *)   echo "fp: fzf exited with status $status" >&2; exit 2 ;;
esac

ids=$(printf '%s\n' "$selection" | cut -f3)
[ -n "$ids" ] || exit 0

# One download per selected ID; extra args ("$@") pass straight through. Iterate
# without a pipeline subshell so a failed download is reflected in fp's own
# exit status (last failure wins, preserving fireflies-pull's 1/2 semantics).
rc=0
oldIFS=$IFS
IFS='
'
for id in $ids; do
  [ -n "$id" ] || continue
  fireflies-pull --id "$id" "$@" || rc=$?
done
IFS=$oldIFS

exit $rc
