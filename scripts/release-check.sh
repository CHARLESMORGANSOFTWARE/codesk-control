#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"

cd "$repo_root"

if ! xcrun --find xctest >/dev/null 2>&1 && [[ -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

swift test
swift build -c release
.build/release/codesk selftest
scripts/package-release.sh
