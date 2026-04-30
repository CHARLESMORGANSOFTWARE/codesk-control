#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
plugin_root="$(cd "$script_dir/.." && pwd -P)"
repo_root="$(cd "$plugin_root/../.." && pwd -P)"

bin="$repo_root/.build/release/codesk"
if [[ ! -x "$bin" ]]; then
  bin="$repo_root/.build/debug/codesk"
fi

if [[ ! -x "$bin" ]]; then
  echo "codesk binary not found. Run 'swift build -c release' in $repo_root." >&2
  exit 127
fi

exec "$bin" "$@"
