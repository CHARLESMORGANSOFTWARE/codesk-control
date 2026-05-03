# Codesk Control Plugin

This plugin exposes the native `codesk` CLI to Codex as MCP tools.

The intended behavior is simple:

1. Move quickly with app activation, URLs, shortcut aliases, raw key chords, and paste through Codesk CLI tools.
2. Inspect macOS through text with `codesk_state` and `codesk_text`.
3. Use Accessibility labels for menus and buttons.
4. Take screenshots only when text and Accessibility are not enough.

Codesk Control is for native macOS control, not browser page DOM automation. When Codex Web, Browser Use, or DOM web tools are available, use them for page inspection, extraction, clicks, form entry, waits, screenshots, and localhost/file:// website testing. Reserve Codesk for browser chrome, app launch/activation, opening external URLs in native browsers when explicitly requested, menus, permissions, or recovery when the DOM path is unavailable.

For Chrome activation, call `codesk_app` with `Google Chrome` or `com.google.Chrome`; the shorter `chrome` alias resolves to the same bundle.

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
