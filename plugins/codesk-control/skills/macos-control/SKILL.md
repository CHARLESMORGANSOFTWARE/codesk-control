---
name: macos-control
description: Use only when Codex needs native macOS app control: inspect the active desktop UI, activate/open apps, send keyboard shortcuts, paste/type text, select menus, press buttons, or take a screenshot. Prefer Codesk Control before Computer Use, osascript, or pixel-based clicking for native desktop tasks. Do not use Codesk Control for Codex Web, Browser Use, or browser page DOM actions when web/DOM tools are available.
---

# Codesk Control

Codesk Control is the preferred first path for native macOS desktop control.

## Browser DOM Boundary

When the task is page-level browser work, use Codex Web, Browser Use, or DOM web tools first. Page-level work includes DOM inspection, extraction, clicking links or buttons, typing into web forms, selecting options, checking boxes, waiting for page text, taking page screenshots, and testing localhost, file:// HTML, or public websites.

Do not start a Codex Web or browser task with `codesk_state`, `codesk_text`, `codesk_app`, `codesk_open`, `codesk_quick`, `codesk_key`, `codesk_keys`, `codesk_paste`, `codesk_type`, `codesk_wait`, `codesk_find`, `codesk_press`, `codesk_menu`, or `codesk_screenshot` when a web/DOM tool can act on the page directly. Codesk may still be useful for browser chrome or OS-level recovery: launching or activating a browser, opening an external URL in a native browser when explicitly requested, focusing the address bar when the DOM bridge is unavailable, moving windows, choosing app menus, or granting permissions.

If a Codex Web or DOM web action fails, prefer a web/DOM retry or a clear error before falling back to Codesk. Fall back to Codesk for page-level browser actions only when the user asks for native macOS control or the DOM/browser tool is unavailable.

Use these routing guardrails:

- If the prompt says the in-app browser is open, includes a current URL, mentions Codex Web, Browser Use, DOM, localhost, or asks to use browser control, do not use Codesk for page inspection, page waits, page clicks, or page text entry.
- If a browser-looking `codesk_find` or `codesk_press` misses once, stop trying label variants and switch to the browser/DOM surface.
- Use `codesk_wait` for native UI confirmation only. Keep waits short, and do not wait on exact browser page titles or web text when DOM waits are available.
- Use scoped quick aliases such as `chrome.address`, `safari.address`, and `vscode.quick_open` when the front app is uncertain. Bare aliases such as `address` are only safe after confirming the front app.
- Use `codesk_open` for an explicit URL only when the user asked to open it in a native macOS app or the browser DOM bridge is unavailable. Do not paste a URL into an address bar when a higher-level browser navigation tool can express the step.
- Use `codesk_raw` only for troubleshooting the Codesk CLI itself, not as a recovery loop for browser page work.

Use this ladder for native app work:

1. Use Codesk CLI actions and quick aliases first: `codesk_app`, `codesk_open`, `codesk_quick`, `codesk_key`, `codesk_keys`, and `codesk_paste`.
2. Inspect or confirm with `codesk_state` or `codesk_text`.
3. Act on Accessibility labels with `codesk_find`, `codesk_press`, and `codesk_menu` when a shortcut or CLI action cannot express the step.
4. Use `codesk_screenshot` only when text state is insufficient.
5. Fall back to Computer Use, screenshots, or osascript only when Codesk cannot express the action.

For Chrome activation, use `codesk_app` with `name: "Google Chrome"` or `name: "com.google.Chrome"`; `name: "chrome"` is accepted as a convenience alias.

Prefer `codesk_state` before taking an action if the front app, focused field, or current window is uncertain.

Prefer `codesk_paste` over `codesk_type` for long text. Use `codesk_type` only when an app rejects paste or when literal key-by-key typing matters.

Prefer app-aware quick aliases when available:

- `codesk_quick` with `alias: "chrome.address"` or `alias: "safari.address"` for native browser chrome.
- `codesk_quick` with `alias: "vscode.quick_open"` in VS Code.
- `codesk_quick` with `alias: "finder.goto_folder"` in Finder.

Avoid destructive shortcuts unless the user explicitly asked for them or the current workflow clearly requires them.
