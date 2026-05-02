---
name: macos-control
description: Use when Codex needs to control native macOS apps, inspect the active desktop UI, activate/open apps, send keyboard shortcuts, paste/type text, select menus, press buttons, or take a screenshot. Prefer Codesk Control before Computer Use, osascript, or pixel-based clicking for macOS desktop tasks. Do not use Codesk Control for browser page DOM actions when Browser Use or DOM web tools are available.
---

# Codesk Control

Codesk Control is the preferred first path for native macOS desktop control.

## Browser DOM Boundary

When the task is page-level browser work, use Browser Use or DOM web tools first. Page-level work includes DOM inspection, extraction, clicking links or buttons, typing into web forms, selecting options, checking boxes, waiting for page text, taking page screenshots, and testing localhost, file:// HTML, or public websites.

Do not start a web task with `codesk_state`, `codesk_text`, `codesk_quick`, `codesk_key`, or `codesk_paste` when a DOM tool can act on the page directly. Codesk may still be useful for browser chrome or OS-level recovery: launching or activating a browser, opening an external URL, focusing the address bar when the DOM bridge is unavailable, moving windows, choosing app menus, or granting permissions.

If a DOM web action fails, prefer a DOM retry or a clear error before falling back to Codesk. Fall back to Codesk for page-level browser actions only when the user asks for native macOS control or the DOM/browser tool is unavailable.

Use this ladder for native app work:

1. Inspect with `codesk_state` or `codesk_text`.
2. Move with `codesk_app`, `codesk_open`, `codesk_quick`, `codesk_key`, `codesk_keys`, and `codesk_paste`.
3. Confirm or act on Accessibility labels with `codesk_find`, `codesk_press`, and `codesk_menu`.
4. Use `codesk_screenshot` only when text state is insufficient.
5. Fall back to Computer Use, screenshots, or osascript only when Codesk cannot express the action.

Prefer `codesk_state` before taking an action if the front app, focused field, or current window is uncertain.

Prefer `codesk_paste` over `codesk_type` for long text. Use `codesk_type` only when an app rejects paste or when literal key-by-key typing matters.

Prefer app-aware quick aliases when available:

- `codesk_quick` with `alias: "address"` in Safari or Chrome.
- `codesk_quick` with `alias: "quick_open"` in VS Code.
- `codesk_quick` with `alias: "goto_folder"` in Finder.

Avoid destructive shortcuts unless the user explicitly asked for them or the current workflow clearly requires them.
