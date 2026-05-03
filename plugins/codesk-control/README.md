# Codesk Control Plugin

This plugin exposes the native `codesk` CLI to Codex as MCP tools.

The intended behavior is simple:

1. Move quickly with app activation, URLs, shortcut aliases, raw key chords, and paste through Codesk CLI tools.
2. Inspect macOS through text with `codesk_state` and `codesk_text`.
3. Use Accessibility labels for menus and buttons.
4. Take screenshots only when text and Accessibility are not enough.

Codesk Control is for native macOS control, not browser page DOM automation. When Codex Web, Browser Use, or DOM web tools are available, use them for page inspection, extraction, clicks, form entry, waits, screenshots, and localhost/file:// website testing. Reserve Codesk for browser chrome, app launch/activation, opening external URLs in native browsers when explicitly requested, menus, permissions, or recovery when the DOM path is unavailable.

Routing guardrails:

- If the user context includes an in-app browser, a current URL, Codex Web, Browser Use, DOM, localhost, or "use browser control", keep page work on the browser/DOM surface.
- Treat a failed `codesk_find` or `codesk_press` against browser page text as a routing signal, not an invitation to try many label variants.
- Prefer DOM waits over `codesk_wait` for browser titles or page text; native waits should be short and tied to app/window/focus changes.
- Use scoped quick aliases such as `chrome.address`, `safari.address`, or `vscode.quick_open` unless the front app has already been confirmed.
- Keep `codesk_raw` for troubleshooting the CLI itself. It should not become the fallback path for browser page automation.

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
