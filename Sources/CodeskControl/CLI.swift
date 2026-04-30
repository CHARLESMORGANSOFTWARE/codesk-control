import Foundation

struct CLI {
    var arguments: [String]

    func run() throws {
        var cursor = ArgumentCursor(arguments)
        guard let command = cursor.next() else {
            printHelp()
            return
        }

        switch command.lowercased() {
        case "help", "--help", "-h":
            printHelp()
        case "version", "--version":
            print(CodeskVersion.display)
        case "mcp":
            try MCPServer().run()
        case "selftest":
            try SelfTest.run()
        case "doctor", "permissions":
            try runPermissions(cursor.remaining())
        case "state":
            try runState(cursor.remaining())
        case "text":
            try runText(cursor.remaining())
        case "app", "activate":
            try runApp(cursor.remaining())
        case "open":
            try runOpen(cursor.remaining())
        case "key":
            try runKey(cursor.remaining())
        case "keys":
            try runKeys(cursor.remaining())
        case "q", "quick":
            try runQuick(cursor.remaining())
        case "type":
            try runType(cursor.remaining())
        case "paste":
            try runPaste(cursor.remaining())
        case "wait":
            try runWait(cursor.remaining())
        case "find":
            try runFind(cursor.remaining())
        case "press", "choose":
            try runPress(cursor.remaining())
        case "menu":
            try runMenu(cursor.remaining())
        case "screenshot":
            try runScreenshot(cursor.remaining())
        default:
            throw CommandError("unknown command: \(command)\nRun `codesk help` for usage.", exitCode: 64)
        }
    }

    private func runPermissions(_ args: [String]) throws {
        let prompt = args.contains("--prompt")
        let trusted = AccessibilityController.accessibilityTrusted(prompt: prompt)
        print("accessibility: \(trusted ? "trusted" : "not trusted")")
        if !trusted {
            print("hint: run `codesk permissions --prompt`, then enable the built binary in System Settings > Privacy & Security > Accessibility.")
        }
    }

    private func runState(_ args: [String]) throws {
        let options = StateOptions(args)
        let snapshot = AccessibilityController().snapshot(textLimit: options.limit)
        if options.json {
            try printEncodedJSON(snapshot)
        } else {
            print(snapshot.humanReadable())
        }
    }

    private func runText(_ args: [String]) throws {
        let options = StateOptions(args)
        let ax = AccessibilityController()
        guard ax.isTrusted else {
            throw CommandError("accessibility is not trusted. Run `codesk permissions --prompt` first.", exitCode: 69)
        }
        let snapshot = ax.snapshot(textLimit: options.limit)
        for line in snapshot.visibleText {
            print(line)
        }
    }

    private func runApp(_ args: [String]) throws {
        let name = try textFromArguments(args, purpose: "app name")
        try ApplicationController().activate(name)
    }

    private func runOpen(_ args: [String]) throws {
        let target = try textFromArguments(args, purpose: "path or URL")
        try ApplicationController().openTarget(target)
    }

    private func runKey(_ args: [String]) throws {
        guard let chord = args.first else {
            throw CommandError("usage: codesk key <chord>", exitCode: 64)
        }
        try KeyboardController().press(KeyParser.parse(chord))
    }

    private func runKeys(_ args: [String]) throws {
        guard !args.isEmpty else {
            throw CommandError("usage: codesk keys <chord> [<chord> ...]", exitCode: 64)
        }
        let keyboard = KeyboardController()
        for chord in args {
            try keyboard.press(KeyParser.parse(chord))
            Thread.sleep(forTimeInterval: 0.035)
        }
    }

    private func runQuick(_ args: [String]) throws {
        if args.isEmpty || args == ["list"] || args == ["--list"] {
            print(QuickAliases.listText())
            return
        }

        let keyboard = KeyboardController()
        let frontApp = ApplicationController().frontmostApplicationName
        for name in args {
            let alias = try QuickAliases.resolve(name, frontAppName: frontApp)
            try keyboard.press(KeyParser.parse(alias.chord))
            Thread.sleep(forTimeInterval: 0.035)
        }
    }

    private func runType(_ args: [String]) throws {
        var delay = 0.003
        var textParts: [String] = []
        var cursor = ArgumentCursor(args)
        while let arg = cursor.next() {
            if arg == "--delay-ms" {
                delay = try cursor.requireDouble(after: arg) / 1000.0
            } else if let value = arg.valueForLongOption("--delay-ms") {
                delay = try parseDouble(value, name: "--delay-ms") / 1000.0
            } else {
                textParts.append(arg)
            }
        }
        let text = try textFromArguments(textParts, purpose: "text")
        try KeyboardController().typeText(text, delay: delay)
    }

    private func runPaste(_ args: [String]) throws {
        var leaveClipboard = false
        var restoreDelay = 0.16
        var textParts: [String] = []
        var cursor = ArgumentCursor(args)
        while let arg = cursor.next() {
            if arg == "--leave-clipboard" {
                leaveClipboard = true
            } else if arg == "--restore-delay-ms" {
                restoreDelay = try cursor.requireDouble(after: arg) / 1000.0
            } else if let value = arg.valueForLongOption("--restore-delay-ms") {
                restoreDelay = try parseDouble(value, name: "--restore-delay-ms") / 1000.0
            } else {
                textParts.append(arg)
            }
        }

        let text = try textFromArguments(textParts, purpose: "text")
        try ClipboardController().paste(text, restoreClipboard: !leaveClipboard, restoreDelay: restoreDelay)
    }

    private func runWait(_ args: [String]) throws {
        var cursor = ArgumentCursor(args)
        guard let condition = cursor.next() else {
            throw CommandError("usage: codesk wait <text|title|app|focus> <value> [--timeout seconds] [--interval seconds]", exitCode: 64)
        }

        var timeout = 5.0
        var interval = 0.10
        var valueParts: [String] = []
        while let arg = cursor.next() {
            if arg == "--timeout" {
                timeout = try cursor.requireDouble(after: arg)
            } else if let value = arg.valueForLongOption("--timeout") {
                timeout = try parseDouble(value, name: "--timeout")
            } else if arg == "--interval" {
                interval = try cursor.requireDouble(after: arg)
            } else if let value = arg.valueForLongOption("--interval") {
                interval = try parseDouble(value, name: "--interval")
            } else {
                valueParts.append(arg)
            }
        }

        let value = try textFromArguments(valueParts, purpose: "wait value")
        print(try Waiter().wait(condition: condition, value: value, timeout: timeout, interval: interval))
    }

    private func runFind(_ args: [String]) throws {
        let label = try textFromArguments(args, purpose: "text")
        let ax = AccessibilityController()
        guard ax.isTrusted else {
            throw CommandError("accessibility is not trusted. Run `codesk permissions --prompt` first.", exitCode: 69)
        }
        let matches = ax.findElements(matching: label, limit: 30)
        if matches.isEmpty {
            throw CommandError("no visible accessibility elements matched: \(label)", exitCode: 2)
        }
        for match in matches {
            print(match.descriptionLine)
        }
    }

    private func runPress(_ args: [String]) throws {
        let label = try textFromArguments(args, purpose: "label")
        let ax = AccessibilityController()
        guard ax.isTrusted else {
            throw CommandError("accessibility is not trusted. Run `codesk permissions --prompt` first.", exitCode: 69)
        }
        try ax.pressElement(label: label)
    }

    private func runMenu(_ args: [String]) throws {
        let path = try textFromArguments(args, purpose: "menu path")
        let ax = AccessibilityController()
        guard ax.isTrusted else {
            throw CommandError("accessibility is not trusted. Run `codesk permissions --prompt` first.", exitCode: 69)
        }
        try ax.selectMenu(path: path)
    }

    private func runScreenshot(_ args: [String]) throws {
        let path = args.isEmpty ? nil : args.joined(separator: " ")
        let output = try ScreenshotController().capture(to: path)
        print(output.path)
    }

    private func printHelp() {
        print("""
        \(CodeskVersion.display)

        Fast macOS control from text and shortcuts.

        Usage:
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
          codesk selftest

        Chords:
          cmd+l, cmd+shift+p, ctrl+`, option+left, enter, escape, up

        Examples:
          codesk app Safari
          codesk q address
          codesk paste "https://example.com"
          codesk key enter
          codesk wait title Example
        """)
    }
}
