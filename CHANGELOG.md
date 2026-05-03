# Changelog

All notable changes to Codesk Control will be documented in this file.

## [Unreleased]

- Add stricter routing guidance for browser/page work so Codesk Control stays on native macOS surfaces unless explicit OS recovery is needed.
- Improve ambiguous quick-alias errors with scoped suggestions such as `chrome.address` and `safari.address`.
- Resolve common app aliases through exact bundle identifiers and verify app activation reaches the frontmost app.
- Add persistent MCP shortcut-registry timing to the benchmark harness.
- Tighten Codex Web and browser DOM boundaries in plugin metadata, skill guidance, and MCP tool descriptions.
- Add GitHub CI and release packaging.
- Add unit tests for key parsing, quick aliases, support parsing, and MCP tool definitions.
- Keep generated benchmark outputs out of source control.

## [0.2.0] - 2026-04-30

- Add native stdio MCP server through `codesk mcp`.
- Add Codex plugin metadata and macOS control skill.
- Add benchmarking for CLI, MCP, AppleScript, and screenshot control paths.
- Add CLI commands for app activation, opening targets, keyboard shortcuts, quick aliases, paste/type, waits, Accessibility actions, screenshots, and permissions checks.
