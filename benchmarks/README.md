# Benchmarks

`scripts/benchmark-control.mjs` creates a repeatable speed and behavior baseline for macOS control approaches.

It measures:

- Codesk native state and text commands.
- Codesk through the plugin MCP server.
- Legacy AppleScript/`osascript` front-app and window-title queries.
- `screencapture` as the substrate for screenshot/vision workflows.
- A live process inventory for currently running Codex, Computer Use, Webtool, Telecodex, and browser systems.

Run:

```sh
swift build -c release
scripts/benchmark-control.mjs
```

Useful options:

```sh
scripts/benchmark-control.mjs --iterations 30 --warmup 5
scripts/benchmark-control.mjs --skip-screenshot
scripts/benchmark-control.mjs --text-limit 80
```

Results are written to `benchmarks/results/<timestamp>-baseline.json` and `.md`.

The benchmark redacts home-directory paths and stores behavior summaries instead of full UI text so results are useful without becoming a transcript of the screen.

