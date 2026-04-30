#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
plugin_source="$repo_root/plugins/codesk-control"
marketplace_dir="$HOME/.agents/plugins"
marketplace_file="$marketplace_dir/marketplace.json"
home_plugins_dir="$HOME/plugins"
home_plugin_link="$home_plugins_dir/codesk-control"

mkdir -p "$marketplace_dir" "$home_plugins_dir"
ln -sfn "$plugin_source" "$home_plugin_link"

if [[ ! -f "$marketplace_file" ]]; then
  cat > "$marketplace_file" <<'JSON'
{
  "name": "local",
  "interface": {
    "displayName": "Local Plugins"
  },
  "plugins": []
}
JSON
fi

node - "$marketplace_file" <<'NODE'
const fs = require("fs");
const file = process.argv[2];
const data = JSON.parse(fs.readFileSync(file, "utf8"));
data.name ||= "local";
data.interface ||= {};
data.interface.displayName ||= "Local Plugins";
data.plugins ||= [];
const entry = {
  name: "codesk-control",
  source: {
    source: "local",
    path: "./plugins/codesk-control"
  },
  policy: {
    installation: "INSTALLED_BY_DEFAULT",
    authentication: "ON_INSTALL"
  },
  category: "Productivity"
};
const index = data.plugins.findIndex(plugin => plugin.name === entry.name);
if (index >= 0) data.plugins[index] = entry;
else data.plugins.push(entry);
fs.writeFileSync(file, JSON.stringify(data, null, 2) + "\n");
NODE

echo "Installed Codesk Control plugin symlink:"
echo "  $home_plugin_link -> $plugin_source"
echo "Updated marketplace:"
echo "  $marketplace_file"
echo
echo "Restart Codex to load newly installed MCP tools."

