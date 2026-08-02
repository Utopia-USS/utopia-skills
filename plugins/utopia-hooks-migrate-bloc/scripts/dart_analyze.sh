#!/usr/bin/env bash
# dart_analyze.sh - thin wrapper around `dart analyze`
# Duplicated in both plugins so each is standalone. See utopia-hooks plugin for canonical copy.

set -u

if ! command -v dart >/dev/null 2>&1; then
  exit 127
fi

start="${1:-$PWD}"
dir="$(cd "$(dirname -- "$start")" 2>/dev/null && pwd)" || dir="$PWD"
project_root=""
while [[ "$dir" != "/" && -n "$dir" ]]; do
  if [[ -f "$dir/pubspec.yaml" ]]; then
    project_root="$dir"
    break
  fi
  dir="$(dirname -- "$dir")"
done

[[ -z "$project_root" ]] && exit 0

cd "$project_root" || exit 0

if [[ $# -eq 0 ]]; then
  output="$(dart analyze 2>&1)"
else
  output="$(dart analyze "$@" 2>&1)"
fi
status=$?

if [[ $status -ne 0 ]]; then
  echo "$output" >&2
  exit 1
fi

exit 0
