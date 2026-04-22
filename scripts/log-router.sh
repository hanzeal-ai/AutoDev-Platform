#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <log-dir> <base-name>" >&2
  exit 1
fi

LOG_DIR="$1"
BASE_NAME="$2"

BASE_DIR="$LOG_DIR/$BASE_NAME"
COMBINED_LOG="$BASE_DIR/combined.log"
INFO_LOG="$BASE_DIR/info.log"
WARN_LOG="$BASE_DIR/warn.log"
ERROR_LOG="$BASE_DIR/error.log"

mkdir -p "$BASE_DIR"
touch "$COMBINED_LOG" "$INFO_LOG" "$WARN_LOG" "$ERROR_LOG"

while IFS= read -r line || [[ -n "$line" ]]; do
  timestamp="$(date '+%Y-%m-%d %H:%M:%S %z')"
  if [[ "$line" =~ ^\[[0-9]{4}-[0-9]{2}-[0-9]{2}\ [0-9]{2}:[0-9]{2}:[0-9]{2}\ [+-][0-9]{4}\] ]]; then
    prefixed="$line"
  else
    prefixed="[$timestamp] $line"
  fi

  printf '%s\n' "$prefixed" >> "$COMBINED_LOG"
  lower_line="$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')"
  if [[ "$lower_line" =~ (error|failed|fatal|panic|no\ such\ file\ or\ directory|connection\ refused|permission\ denied|request_failed|could\ not|cannot\ find|not\ found) ]]; then
    printf '%s\n' "$prefixed" >> "$ERROR_LOG"
  elif [[ "$lower_line" =~ (warning|warn|blocking\ waiting\ for\ file\ lock) ]]; then
    printf '%s\n' "$prefixed" >> "$WARN_LOG"
  else
    printf '%s\n' "$prefixed" >> "$INFO_LOG"
  fi
done

: <<'DISABLED_AWK_LOG_ROUTER'
awk -v combined="$COMBINED_LOG" -v info="$INFO_LOG" -v warn="$WARN_LOG" -v error="$ERROR_LOG" '
function lower(text,    out, i, ch) {
  out = ""
  for (i = 1; i <= length(text); i++) {
    ch = substr(text, i, 1)
    out = out tolower(ch)
  }
  return out
}

function has_timestamp(line) {
  return line ~ /^\[[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} [+-][0-9]{4}\]/
}

function prefix_line(line) {
  if (has_timestamp(line)) {
    return line
  }
  return "[" timestamp() "] " line
}

function write_line(path, line) {
  print line >> path
  fflush(path)
}

{
  line = $0
  prefixed = prefix_line(line)
  write_line(combined, prefixed)

  lower_line = lower(line)
  if (lower_line ~ /(error|failed|fatal|panic|no such file or directory|connection refused|permission denied|request_failed|could not|cannot find|not found)/) {
    write_line(error, prefixed)
  } else if (lower_line ~ /(warning|warn|blocking waiting for file lock)/) {
    write_line(warn, prefixed)
  } else {
    write_line(info, prefixed)
  }
}
' 
DISABLED_AWK_LOG_ROUTER
