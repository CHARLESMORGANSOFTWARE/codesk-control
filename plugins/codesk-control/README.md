# Codesk Control Plugin

This plugin exposes the native `codesk` CLI to Codex as MCP tools.

The intended behavior is simple:

1. Inspect macOS through text with `codesk_state` and `codesk_text`.
2. Move quickly with app activation, URLs, shortcut aliases, raw key chords, and paste.
3. Use Accessibility labels for menus and buttons.
4. Take screenshots only when text and Accessibility are not enough.

Codesk Control is for native macOS control, not browser page DOM automation. When Browser Use or DOM web tools are available, use them for page inspection, extraction, clicks, form entry, waits, and screenshots. Reserve Codesk for browser chrome, app launch/activation, opening external URLs, menus, permissions, or recovery when the DOM path is unavailable.

The MCP server runs inside the native Swift binary:

```sh
../../.build/release/codesk mcp
```

from the plugin directory.

Build the binary before enabling the plugin:

```sh
swift build -c release
```

For release archives, the launcher also accepts `CODESK_BIN`, `../../bin/codesk`, or `codesk` on `PATH`.
