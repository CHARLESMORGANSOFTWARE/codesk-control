#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
plugin_root="$(cd "$script_dir/.." && pwd -P)"
repo_root="$(cd "$plugin_root/../.." && pwd -P)"

if [[ -n "${CODESK_BIN:-}" ]]; then
  bin="$CODESK_BIN"
else
  bin=""
  for candidate in \
    "$repo_root/.build/release/codesk" \
    "$repo_root/.build/debug/codesk" \
    "$repo_root/bin/codesk" \
    "$(command -v codesk || true)"
  do
    if [[ -n "$candidate" && -x "$candidate" ]]; then
      bin="$candidate"
      break
    fi
  done
fi

if [[ ! -x "$bin" ]]; then
  echo "codesk binary not found. Run 'swift build -c release' in $repo_root, set CODESK_BIN, or put codesk on PATH." >&2
  exit 127
fi

exec "$bin" "$@"
