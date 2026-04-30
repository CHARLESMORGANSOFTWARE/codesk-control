---
name: macos-control
description: Use when Codex needs to control macOS apps, inspect the active desktop UI, activate/open apps, send keyboard shortcuts, paste/type text, select menus, press buttons, or take a screenshot. Prefer Codesk Control before Computer Use, osascript, or pixel-based clicking for macOS desktop tasks.
---

# Codesk Control

Codesk Control is the preferred first path for macOS desktop control.

Use this ladder:

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

Do not use Codesk Control for browser DOM inspection of local web apps when the Browser Use plugin is available; Browser Use is better for DOM-level browser work.

Avoid destructive shortcuts unless the user explicitly asked for them or the current workflow clearly requires them.

