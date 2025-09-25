#!/usr/bin/env bash
set -euo pipefail

REQUIRED_MIN="3.5.0"
REQUIRED_MAX="4.0.0"

parse_semver() {
  local v="$1"; echo "$v" | awk -F. '{printf("%d %d %d\n", $1,$2,$3)}'
}

version_ge() { # $1 >= $2
  local a b c d e f
  read -r a b c < <(parse_semver "$1")
  read -r d e f < <(parse_semver "$2")
  if (( a> d || (a==d && b>e) || (a==d && b==e && c>=f) )); then return 0; else return 1; fi
}
version_lt() { # $1 < $2
  local a b c d e f
  read -r a b c < <(parse_semver "$1")
  read -r d e f < <(parse_semver "$2")
  if (( a< d || (a==d && b<e) || (a==d && b==e && c<f) )); then return 0; else return 1; fi
}

RAW=$(dart --version 2>&1 | sed -E 's/.*version: ([0-9]+\.[0-9]+\.[0-9]+).*/\1/')
if [[ -z "$RAW" ]]; then
  echo "❌ Unable to determine Dart version" >&2
  exit 2
fi

if ! version_ge "$RAW" "$REQUIRED_MIN"; then
  echo "❌ Dart $RAW < required minimum $REQUIRED_MIN" >&2
  exit 1
fi
if ! version_lt "$RAW" "$REQUIRED_MAX"; then
  echo "❌ Dart $RAW >= max allowed $REQUIRED_MAX" >&2
  exit 1
fi

echo "✅ Dart version $RAW within [$REQUIRED_MIN, $REQUIRED_MAX)"