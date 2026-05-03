# Benchmarks

`scripts/benchmark-control.mjs` creates a repeatable speed and behavior baseline for macOS control approaches.

It measures:

- Codesk native state and text commands.
- Codesk through the persistent plugin MCP server, including state reads and shortcut registry calls.
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
scripts/benchmark-control.mjs --include-host
```

Results are written to `benchmarks/results/<timestamp>-baseline.json` and `.md`.

The benchmark redacts hostnames by default, redacts home/repo/volume paths in process examples, and stores behavior summaries instead of full UI text so results are useful without becoming a transcript of the screen. Generated result files are intentionally ignored by git.
