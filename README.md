# Codesk Control

Codesk Control is a text-first macOS control surface for Codex-style agents. It gives agents a fast, structured way to inspect and operate desktop apps through native UI state, keyboard shortcuts, Accessibility labels, menus, paste/type actions, app activation, URL/file opening, and screenshots only when the interface cannot describe itself.

The project is built around a simple idea:

> Use text to know. Use shortcuts to move. Use Accessibility to confirm. Use vision only when the screen refuses to describe itself.

Why this matters: screenshot-first desktop control is general, but it often forces an agent through a slow loop of capture, visual interpretation, coordinate selection, and delayed verification. Codesk Control makes the common path semantic instead. The native MCP server exposes macOS state and actions as typed tools, so an agent can read the front app, focused element, selected text, visible Accessibility text, and window title, then activate apps, send app-aware shortcuts, paste text, press named controls, select menus, wait for UI changes, or capture a screenshot as a last resort.

The executable is `codesk`. Run it directly as a CLI, or launch the persistent stdio MCP server with `codesk mcp`.

## Product Demo

Watch/download the short product promo: [codesk-control-product-promo.mp4](docs/assets/codesk-control-product-promo.mp4).

## Performance Snapshot

In a live Codex desktop environment, moving the plugin path from a Node MCP wrapper that spawned the CLI per request to a persistent native Swift MCP server reduced median `codesk_mcp_state` latency from **34.69 ms** to **1.37 ms**.

```text
codesk_mcp_state       34.69 ms ->   1.37 ms   25.32x faster
osascript_front_app   124.39 ms -> 124.92 ms   about same
screencapture_png      77.05 ms ->  76.11 ms   about same
```

After the native MCP change, repeated `codesk_mcp_state` calls were roughly:

```text
55.6x faster than screenshot capture
91.2x faster than an AppleScript front-app query
104.9x faster than an AppleScript window-title query
```

The benchmark measures latency and structured observation coverage. In the saved live run, Codesk CLI/MCP returned the front app, bundle id, process id presence, window-title presence, Accessibility permission state, and visible text count; the screenshot path returned pixels only. See:

- [Benchmark docs](benchmarks/README.md)
- [Paper source](paper/arxiv-source/codesk-control.tex)

## What The MCP Server Exposes

`codesk mcp` is a native Swift stdio MCP server. It keeps the desktop-control process alive and exposes narrow, typed tools instead of asking an agent to run raw shell commands or click coordinates.

| Capability | MCP tools | What agents use it for |
| --- | --- | --- |
| Inspect UI state | `codesk_state`, `codesk_text` | Read front app, bundle id, PID presence, window title, focused element, selected text, permission state, and visible Accessibility text. |
| Move between apps and targets | `codesk_app`, `codesk_open` | Activate or launch apps, open files/folders, and open URLs through Launch Services for native macOS workflows. |
| Drive common shortcuts | `codesk_quick`, `codesk_quick_list`, `codesk_key`, `codesk_keys` | Use app-aware aliases such as explicit browser chrome controls, VS Code quick open, Finder Go to Folder, or shortcut chords. |
| Enter text | `codesk_paste`, `codesk_type` | Paste longer content with clipboard restoration, or type key-by-key when paste is rejected. |
| Wait and locate | `codesk_wait`, `codesk_find` | Wait for text/title/app/focus changes and find visible Accessibility elements before acting. |
| Act semantically | `codesk_press`, `codesk_menu` | Press named buttons/controls and choose menu paths such as `File > Save`. |
| Fallback and admin | `codesk_screenshot`, `codesk_permissions`, `codesk_raw` | Capture screenshots only when text state is insufficient, check/request Accessibility permission, or run a raw `codesk` command as an escape hatch. |

## Highlights

- Native Swift CLI and native stdio MCP server: `codesk mcp`.
- Structured UI snapshots: front app, bundle id, process id, window title, focused element, selected text, permission state, and visible Accessibility text.
- App-aware quick shortcuts: explicit browser chrome controls, Finder Go to Folder, VS Code quick open/command palette, terminal actions, and more.
- Semantic actions: press labeled controls and select menu paths such as `File > Save`.
- Fast paste/type helpers with clipboard restoration.
- Screenshot fallback when text and Accessibility state are insufficient.
- Local Codex plugin that teaches Codex to prefer Codesk Control before Computer Use, `osascript`, or pixel clicking for macOS desktop tasks.

## Requirements

- macOS 13 or newer.
- Swift 6.1 or newer.
- Xcode for `swift test` with Swift Testing.
- Node.js for the optional benchmark script.

## Build and Test

```sh
swift build
swift test
swift run codesk selftest
```

Run directly from the package:

```sh
swift run codesk help
```

Install the debug binary somewhere on your `PATH` if you want:

```sh
cp .build/debug/codesk /usr/local/bin/codesk
```

Build the optimized binary for local use or packaging:

```sh
swift build -c release
cp .build/release/codesk /usr/local/bin/codesk
```

## Model

Use this ladder for native macOS app work:

1. Fast CLI action first when the command is explicit: `codesk app`, `codesk open`, app CLIs, files, and native app URLs.
2. Keyboard shortcuts and quick aliases second: `codesk q chrome.address`, `codesk q vscode.quick_open`, `codesk key cmd+l`.
3. Text-state checks when state is uncertain or verification matters: `codesk state`, `codesk text`.
4. Accessibility actions next: `codesk press Save`, `codesk menu "File > Export..."`.
5. Screenshots last: `codesk screenshot`.

This is the same control ladder described in the paper: move through direct CLI and shortcut paths, confirm with text state when needed, act on named UI targets, and reserve screenshots for visual or inaccessible interfaces.

For Chrome activation, prefer the exact app name or bundle id: `codesk app "Google Chrome"` or `codesk app com.google.Chrome`. The shorter `chrome` alias resolves to the same bundle.

For Codex Web or browser page work, prefer Codex Web, Browser Use, or DOM web tools when they are available. Codesk can launch or focus a native browser, open an external URL in that browser when explicitly requested, operate browser chrome, choose menus, or recover from OS-level focus problems; it should not be the default path for page DOM inspection, extraction, clicks, form entry, waits, screenshots, or localhost/file:// website testing.

Avoid these common routing traps:

- If the task context says the in-app browser is open, includes a current URL, mentions Codex Web, Browser Use, DOM, localhost, or asks for browser control, keep page work on the browser/DOM surface.
- If `codesk_state` reports front app `Codex` while the target is a browser page, treat that as a surface mismatch and use browser tools or explicit OS focus recovery.
- If `codesk_find` or `codesk_press` misses once on browser page text, switch to DOM/page tooling instead of trying more label variants.
- Use scoped quick aliases such as `chrome.address`, `safari.address`, and `vscode.quick_open` when the front app is uncertain. Bare aliases such as `address` are app-aware conveniences only after the front app is known.
- Keep `codesk_wait` short for native app confirmation. Do not wait on exact browser page titles or page text when DOM waits are available.
- Keep `codesk_raw` for troubleshooting the CLI itself, not as the fallback path for browser page automation.

## Commands

```sh
codesk state [--json] [--limit n]
codesk text [--limit n]
codesk app <name-or-bundle-id>
codesk open <path-or-url>
codesk key <chord>
codesk keys <chord> [<chord> ...]
codesk q <alias> [<alias> ...]
codesk q list
codesk type <text>
codesk paste [--leave-clipboard] <text>
codesk wait <text|title|app|focus> <value> [--timeout seconds]
codesk find <text>
codesk press <label>
codesk menu "File > Save"
codesk screenshot [path.png]
codesk permissions [--prompt]
codesk mcp
```

## Examples

Open a page in Safari when the user explicitly wants native browser chrome control and DOM tooling is unavailable:

```sh
codesk app Safari
codesk q safari.address
codesk paste "https://example.com"
codesk key enter
codesk text
```

Open a file in VS Code:

```sh
codesk app "Visual Studio Code"
codesk q quick_open
codesk paste "Sources/CodeskControl/CLI.swift"
codesk key enter
```

Save through the menu:

```sh
codesk menu "File > Save"
```

Use cases include browser chrome navigation, editor/IDE control, document save/export flows, desktop state monitoring, and human-auditable automation traces such as `pressed AXButton title=Save` instead of `clicked x=844 y=613`.

## Permissions

Keyboard events and Accessibility inspection need macOS privacy permission for the built binary or the host terminal. Start here:

```sh
codesk permissions --prompt
```

Then enable the relevant binary or terminal in System Settings > Privacy & Security > Accessibility.

Screenshots may also require Screen Recording permission.

## Codex Plugin

This repo includes a local Codex plugin at:

```sh
plugins/codesk-control
```

It exposes the `codesk` binary as MCP tools such as `codesk_state`, `codesk_quick`, `codesk_paste`, `codesk_press`, and `codesk_menu`, plus a skill that tells Codex to prefer Codesk Control for native macOS desktop control before Computer Use, osascript, or pixel clicking. The plugin guidance explicitly leaves Codex Web and browser page DOM actions to Codex Web, Browser Use, or DOM web tools when they are available.

The plugin launches `codesk mcp`, a native stdio MCP server, so repeated tool calls do not spawn a new `codesk` process.

The plugin exposes tools including:

```text
codesk_state
codesk_text
codesk_app
codesk_open
codesk_key
codesk_keys
codesk_quick
codesk_quick_list
codesk_paste
codesk_type
codesk_wait
codesk_find
codesk_press
codesk_menu
codesk_screenshot
codesk_permissions
codesk_raw
```

To make it available to future Codex sessions:

```sh
swift build -c release
scripts/install-codesk-plugin.sh
```

Restart Codex after installing so the plugin and MCP tools are discovered.

The plugin launcher looks for the binary in this order:

1. `CODESK_BIN`, when set.
2. `.build/release/codesk`.
3. `.build/debug/codesk`.
4. `bin/codesk` from a release archive.
5. `codesk` on `PATH`.

## Benchmarking

Create a speed and behavior baseline against legacy control paths:

```sh
swift build -c release
scripts/benchmark-control.mjs
```

The benchmark compares Codesk CLI, Codesk MCP, AppleScript/`osascript`, and screenshot capture, and records a live inventory of running Codex-related systems. See [benchmarks/README.md](benchmarks/README.md).

Generated benchmark results are ignored by git because they can contain local process and machine details.

## Accuracy and Coverage

The current benchmark measures latency and structured observation coverage, not a full ground-truth task accuracy suite. In the saved live run:

```text
Codesk CLI/MCP: front app, bundle id, PID presence, window-title presence,
                Accessibility trust, and visible text count.
osascript:      narrow one-field probes.
screenshot:     pixels only, no structured text without vision/OCR.
```

Future work should add labeled end-to-end task suites for true success-rate and semantic accuracy comparisons.

## Safety

Codesk Control can send keyboard events and invoke Accessibility actions in arbitrary apps once macOS permissions are granted. Use it with the same care as other desktop automation tools:

- Grant Accessibility and Screen Recording permissions deliberately.
- Avoid destructive shortcuts unless the user explicitly requested them.
- Prefer typed MCP tools over raw command escape hatches.
- Keep audit logs semantic where possible: app, window, menu path, button label, and shortcut alias.

## Release

Run the local release gate:

```sh
scripts/release-check.sh
```

That runs tests, builds the release binary, runs `codesk selftest`, and writes a versioned archive plus SHA-256 checksum to `dist/`.

To publish through GitHub Actions:

```sh
git tag v0.2.0
git push origin v0.2.0
```

The release workflow packages the archive and creates or updates the GitHub release for the pushed tag.
