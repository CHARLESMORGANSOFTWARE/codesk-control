#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
dist_dir="$repo_root/dist"

cd "$repo_root"

swift build -c release

version="$("$repo_root/.build/release/codesk" version | awk '{print $2}')"
if [[ -z "$version" ]]; then
  echo "could not determine codesk version" >&2
  exit 1
fi

platform="macos"
arch="$(uname -m)"
name="codesk-control-$version-$platform-$arch"
staging="$dist_dir/$name"
archive="$dist_dir/$name.tar.gz"

rm -rf "$staging" "$archive" "$archive.sha256"
mkdir -p "$staging/bin" "$staging/plugins" "$staging/scripts"

cp "$repo_root/.build/release/codesk" "$staging/bin/codesk"
cp -R "$repo_root/plugins/codesk-control" "$staging/plugins/"
cp "$repo_root/scripts/install-codesk-plugin.sh" "$staging/scripts/"
cp "$repo_root/README.md" "$staging/"
cp "$repo_root/CHANGELOG.md" "$staging/"
cp "$repo_root/LICENSE" "$staging/"

tar -czf "$archive" -C "$dist_dir" "$name"
shasum -a 256 "$archive" > "$archive.sha256"

echo "Wrote:"
echo "  $archive"
echo "  $archive.sha256"
