#!/usr/bin/env sh
# check-flag-parity.sh — prove fp's forward-allowlist matches fireflies-pull's.
#
# fp and fireflies-pull share no code, but they are coupled through a CLI
# contract: the set of download-output flags fp may forward to `fireflies-pull
# --id` (see the "one-directional independence" rule in CLAUDE.md). Nothing at
# import time enforces that contract, so this check does — statically, at
# commit/CI time, so drift is caught before it ships rather than surfacing as a
# late failure after a user has already picked a transcript.
#
# Authoritative set : `fireflies-pull --forwardable-flags` (the FORWARDABLE_FLAGS
#                     constant, exposed by the tool itself — the single source of
#                     truth, living next to the parser it governs).
# fp's set          : the flags accepted between the FORWARDABLE-START/END
#                     sentinels in fp's validation `case`.
#
# Exit 0 if they match, 1 (with a diff) if they drift, 2 on a setup problem.
# No API key or network needed — --forwardable-flags short-circuits like --version.
set -u

here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo=$(dirname -- "$here")
ff=$repo/fireflies-pull
fp=$repo/fp

for f in "$ff" "$fp"; do
  [ -r "$f" ] || { echo "check-flag-parity: cannot read $f" >&2; exit 2; }
done

# Authoritative set, one flag per line, sorted for a stable comparison.
authoritative=$(python3 "$ff" --forwardable-flags | sort) || {
  echo "check-flag-parity: 'fireflies-pull --forwardable-flags' failed" >&2
  exit 2
}

# fp's set: pull the case-arm labels between the sentinels. A label is a line
# whose first non-blank character is '-' (e.g. "--stdout)" or "-o | --output)");
# that gate skips the arms' code lines (`set --`, `if [ ... -lt ]`). Split the
# label on '|' and ')', keep the flag-looking tokens. Order-independent.
fp_set=$(awk '
  /# FORWARDABLE-START/ { on = 1; next }
  /# FORWARDABLE-END/   { on = 0 }
  on && /^[ \t]*-/ {
    label = $0
    sub(/\).*/, "", label)          # drop everything from the ")" onward
    gsub(/[|]/, " ", label)         # "-o | --output" -> "-o   --output"
    n = split(label, t, /[ \t]+/)
    for (k = 1; k <= n; k++) if (t[k] ~ /^-/) print t[k]
  }
' "$fp" | sort)

if [ -z "$authoritative" ]; then
  echo "check-flag-parity: authoritative set is empty — is --forwardable-flags wired up?" >&2
  exit 2
fi
if [ -z "$fp_set" ]; then
  echo "check-flag-parity: fp set is empty — are the FORWARDABLE sentinels present in fp?" >&2
  exit 2
fi

if [ "$authoritative" = "$fp_set" ]; then
  echo "check-flag-parity: OK — fp and fireflies-pull agree on forwardable flags:"
  echo "$authoritative" | sed 's/^/  /'
  exit 0
fi

echo "check-flag-parity: DRIFT — fp's forward-allowlist and fireflies-pull disagree." >&2
echo "  '<' = only in fireflies-pull (fp should forward it); '>' = only in fp (would fail late):" >&2
a_tmp=$(mktemp) || exit 2
b_tmp=$(mktemp) || { rm -f "$a_tmp"; exit 2; }
trap 'rm -f "$a_tmp" "$b_tmp"' EXIT INT TERM
printf '%s\n' "$authoritative" >"$a_tmp"
printf '%s\n' "$fp_set" >"$b_tmp"
diff "$a_tmp" "$b_tmp" | sed 's/^/  /' >&2
exit 1
