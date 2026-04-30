# Codesk Control

Codesk Control is a CLI-first macOS control surface for Codex-style agents. It favors text state, native keyboard shortcuts, and Accessibility labels before falling back to screenshots.

The executable is `codesk`.

## Build

```sh
swift build
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

## Model

Use this ladder:

1. Text/CLI first: `codesk state`, `codesk text`, `codesk open`, app CLIs, files, URLs.
2. Keyboard shortcuts second: `codesk key cmd+l`, `codesk q address`.
3. Accessibility actions third: `codesk press Save`, `codesk menu "File > Export..."`.
4. Screenshots last: `codesk screenshot`.

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
```

## Examples

Open a page in Safari:

```sh
codesk app Safari
codesk q address
codesk paste "https://example.com"
codesk key enter
codesk wait title Example
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

It exposes the `codesk` binary as MCP tools such as `codesk_state`, `codesk_quick`, `codesk_paste`, `codesk_press`, and `codesk_menu`, plus a skill that tells Codex to prefer Codesk Control for macOS desktop control before Computer Use, osascript, or pixel clicking.

To make it available to future Codex sessions:

```sh
swift build -c release
scripts/install-codesk-plugin.sh
```

Restart Codex after installing so the plugin and MCP tools are discovered.

## Benchmarking

Create a speed and behavior baseline against legacy control paths:

```sh
swift build -c release
scripts/benchmark-control.mjs
```

The benchmark compares Codesk CLI, Codesk MCP, AppleScript/`osascript`, and screenshot capture, and records a live inventory of running Codex-related systems. See [benchmarks/README.md](benchmarks/README.md).
