import Foundation

final class MCPServer {
    private let output = FileHandle.standardOutput
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    func run() throws {
        while let rawLine = readLine(strippingNewline: true) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            handle(line: line)
        }
    }

    private func handle(line: String) {
        let message: [String: Any]
        do {
            guard let data = line.data(using: .utf8),
                  let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                sendError(id: NSNull(), code: -32600, message: "Invalid JSON-RPC message")
                return
            }
            message = object
        } catch {
            sendError(id: NSNull(), code: -32700, message: "Parse error: \(error.localizedDescription)")
            return
        }

        let id = message["id"]
        guard let method = message["method"] as? String else {
            if let id {
                sendError(id: id, code: -32600, message: "Missing method")
            }
            return
        }

        if id == nil, method.hasPrefix("notifications/") {
            return
        }

        do {
            let params = message["params"] as? [String: Any] ?? [:]
            let result = try dispatch(method: method, params: params)
            if let id {
                send(["jsonrpc": "2.0", "id": id, "result": result])
            }
        } catch let error as MCPError {
            if let id {
                sendError(id: id, code: error.code, message: error.message)
            }
        } catch let error as CommandError {
            if let id {
                sendError(id: id, code: -32603, message: error.message)
            }
        } catch {
            if let id {
                sendError(id: id, code: -32603, message: String(describing: error))
            }
        }
    }

    private func dispatch(method: String, params: [String: Any]) throws -> [String: Any] {
        switch method {
        case "initialize":
            return [
                "protocolVersion": params["protocolVersion"] as? String ?? "2024-11-05",
                "capabilities": ["tools": [:]],
                "serverInfo": ["name": "codesk-control", "version": CodeskVersion.current]
            ]
        case "ping", "logging/setLevel":
            return [:]
        case "tools/list":
            return ["tools": MCPToolDefinitions.tools]
        case "tools/call":
            return try callTool(params: params)
        case "resources/list":
            return ["resources": []]
        case "prompts/list":
            return ["prompts": []]
        default:
            throw MCPError(code: -32601, message: "Method not found: \(method)")
        }
    }

    private func callTool(params: [String: Any]) throws -> [String: Any] {
        guard let name = params["name"] as? String else {
            throw MCPError(code: -32602, message: "Missing tool name")
        }

        guard MCPToolDefinitions.names.contains(name) else {
            throw MCPError(code: -32602, message: "Unknown tool: \(name)")
        }

        let arguments = params["arguments"] as? [String: Any] ?? [:]
        do {
            let text = try toolOutput(name: name, arguments: arguments)
            return textResult(text.isEmpty ? "ok" : text)
        } catch let error as CommandError {
            return textResult(error.message, isError: true)
        } catch let error as MCPError {
            throw error
        } catch {
            return textResult(String(describing: error), isError: true)
        }
    }

    private func toolOutput(name: String, arguments: [String: Any]) throws -> String {
        switch name {
        case "codesk_state":
            let limit = intValue(arguments["limit"], default: 120)
            let json = boolValue(arguments["json"], default: true)
            let snapshot = AccessibilityController().snapshot(textLimit: limit)
            if json {
                return try encode(snapshot)
            }
            return snapshot.humanReadable()

        case "codesk_text":
            let limit = intValue(arguments["limit"], default: 120)
            let ax = AccessibilityController()
            guard ax.isTrusted else {
                throw CommandError("accessibility is not trusted. Run `codesk permissions --prompt` first.", exitCode: 69)
            }
            return ax.snapshot(textLimit: limit).visibleText.joined(separator: "\n")

        case "codesk_app":
            try ApplicationController().activate(requiredString(arguments, "name"))
            return "ok"

        case "codesk_open":
            try ApplicationController().openTarget(requiredString(arguments, "target"))
            return "ok"

        case "codesk_key":
            try KeyboardController().press(KeyParser.parse(requiredString(arguments, "chord")))
            return "ok"

        case "codesk_keys":
            let keyboard = KeyboardController()
            for chord in try requiredStringArray(arguments, "chords") {
                try keyboard.press(KeyParser.parse(chord))
                Thread.sleep(forTimeInterval: 0.035)
            }
            return "ok"

        case "codesk_quick":
            let alias = try QuickAliases.resolve(
                requiredString(arguments, "alias"),
                frontAppName: ApplicationController().frontmostApplicationName
            )
            try KeyboardController().press(KeyParser.parse(alias.chord))
            return "ok"

        case "codesk_quick_list":
            return QuickAliases.listText()

        case "codesk_paste":
            try ClipboardController().paste(
                requiredString(arguments, "text"),
                restoreClipboard: !boolValue(arguments["leaveClipboard"], default: false),
                restoreDelay: 0.16
            )
            return "ok"

        case "codesk_type":
            try KeyboardController().typeText(
                requiredString(arguments, "text"),
                delay: doubleValue(arguments["delayMs"], default: 3) / 1000.0
            )
            return "ok"

        case "codesk_wait":
            return try Waiter().wait(
                condition: requiredString(arguments, "condition"),
                value: requiredString(arguments, "value"),
                timeout: doubleValue(arguments["timeout"], default: 5),
                interval: doubleValue(arguments["interval"], default: 0.1)
            )

        case "codesk_find":
            let label = try requiredString(arguments, "text")
            let ax = AccessibilityController()
            guard ax.isTrusted else {
                throw CommandError("accessibility is not trusted. Run `codesk permissions --prompt` first.", exitCode: 69)
            }
            let matches = ax.findElements(matching: label, limit: 30)
            if matches.isEmpty {
                throw CommandError("no visible accessibility elements matched: \(label)", exitCode: 2)
            }
            return matches.map(\.descriptionLine).joined(separator: "\n")

        case "codesk_press":
            let ax = AccessibilityController()
            guard ax.isTrusted else {
                throw CommandError("accessibility is not trusted. Run `codesk permissions --prompt` first.", exitCode: 69)
            }
            try ax.pressElement(label: requiredString(arguments, "label"))
            return "ok"

        case "codesk_menu":
            let ax = AccessibilityController()
            guard ax.isTrusted else {
                throw CommandError("accessibility is not trusted. Run `codesk permissions --prompt` first.", exitCode: 69)
            }
            try ax.selectMenu(path: requiredString(arguments, "path"))
            return "ok"

        case "codesk_screenshot":
            let path = arguments["path"] as? String
            return try ScreenshotController().capture(to: path).path

        case "codesk_permissions":
            let prompt = boolValue(arguments["prompt"], default: false)
            let trusted = AccessibilityController.accessibilityTrusted(prompt: prompt)
            var lines = ["accessibility: \(trusted ? "trusted" : "not trusted")"]
            if !trusted {
                lines.append("hint: run `codesk permissions --prompt`, then enable the built binary in System Settings > Privacy & Security > Accessibility.")
            }
            return lines.joined(separator: "\n")

        case "codesk_raw":
            return try runProcessCapture(
                executable: Bundle.main.executablePath ?? "codesk",
                arguments: requiredStringArray(arguments, "args"),
                timeout: doubleValue(arguments["timeoutMs"], default: 10_000) / 1000.0
            )

        default:
            throw MCPError(code: -32602, message: "Unhandled tool: \(name)")
        }
    }

    private func encode<T: Encodable>(_ value: T) throws -> String {
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? ""
    }

    private func textResult(_ text: String, isError: Bool = false) -> [String: Any] {
        [
            "content": [["type": "text", "text": text]],
            "isError": isError
        ]
    }

    private func sendError(id: Any, code: Int, message: String) {
        send(["jsonrpc": "2.0", "id": id, "error": ["code": code, "message": message]])
    }

    private func send(_ object: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: object)
            output.write(data)
            output.write(Data("\n".utf8))
        } catch {
            standardError("codesk mcp: could not encode JSON-RPC response: \(error)")
        }
    }

    private func requiredString(_ arguments: [String: Any], _ key: String) throws -> String {
        guard let value = arguments[key] as? String, !value.isEmpty else {
            throw MCPError(code: -32602, message: "Missing required string argument: \(key)")
        }
        return value
    }

    private func requiredStringArray(_ arguments: [String: Any], _ key: String) throws -> [String] {
        guard let value = arguments[key] as? [String] else {
            throw MCPError(code: -32602, message: "Missing required string array argument: \(key)")
        }
        return value
    }

    private func boolValue(_ value: Any?, default defaultValue: Bool) -> Bool {
        if let value = value as? Bool { return value }
        if let value = value as? NSNumber { return value.boolValue }
        return defaultValue
    }

    private func intValue(_ value: Any?, default defaultValue: Int) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return defaultValue
    }

    private func doubleValue(_ value: Any?, default defaultValue: Double) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        return defaultValue
    }
}

struct MCPError: Error {
    var code: Int
    var message: String
}

enum MCPToolDefinitions {
    static var names: Set<String> {
        Set(tools.compactMap { $0["name"] as? String })
    }

    static var tools: [[String: Any]] {
        [
            tool(
                "codesk_state",
                "Preferred first step for inspecting macOS UI state. Returns front app, bundle id, window title, focused element, selected text, and visible Accessibility text.",
                properties: [
                    "json": ["type": "boolean", "description": "Return JSON. Defaults to true."],
                    "limit": ["type": "number", "description": "Maximum visible text lines to collect.", "default": 120]
                ]
            ),
            tool(
                "codesk_text",
                "Return visible Accessibility text from the frontmost macOS window. Use after navigation to confirm what the app shows without screenshots.",
                properties: [
                    "limit": ["type": "number", "description": "Maximum visible text lines to collect.", "default": 120]
                ]
            ),
            tool(
                "codesk_app",
                "Activate or launch a macOS app by name or bundle id. Preferred before sending app-specific shortcuts.",
                properties: ["name": ["type": "string", "description": "Application name or bundle id."]],
                required: ["name"]
            ),
            tool(
                "codesk_open",
                "Open a URL or filesystem path with macOS Launch Services.",
                properties: ["target": ["type": "string", "description": "URL or file/folder path to open."]],
                required: ["target"]
            ),
            tool(
                "codesk_key",
                "Send one native keyboard shortcut to macOS, such as cmd+l, cmd+shift+p, enter, escape, or option+left.",
                properties: ["chord": ["type": "string", "description": "Shortcut chord."]],
                required: ["chord"]
            ),
            tool(
                "codesk_keys",
                "Send a short sequence of native keyboard shortcuts to macOS.",
                properties: ["chords": ["type": "array", "items": ["type": "string"], "description": "Shortcut chords to send in order."]],
                required: ["chords"]
            ),
            tool(
                "codesk_quick",
                "Send an app-aware quick shortcut alias. Preferred over raw key chords for common actions like address, new_tab, find, quick_open, command_palette, goto_folder, and terminal.",
                properties: ["alias": ["type": "string", "description": "Quick alias name, for example address, safari.address, or finder.goto_folder."]],
                required: ["alias"]
            ),
            tool("codesk_quick_list", "List available Codesk quick shortcut aliases."),
            tool(
                "codesk_paste",
                "Paste text into the focused macOS field using the clipboard and cmd+v. Preferred for long text.",
                properties: [
                    "text": ["type": "string", "description": "Text to paste."],
                    "leaveClipboard": ["type": "boolean", "description": "Leave pasted text on the clipboard.", "default": false]
                ],
                required: ["text"]
            ),
            tool(
                "codesk_type",
                "Type text key by key into the focused macOS field. Use when paste is rejected or literal typing matters.",
                properties: [
                    "text": ["type": "string", "description": "Text to type."],
                    "delayMs": ["type": "number", "description": "Delay between characters in milliseconds.", "default": 3]
                ],
                required: ["text"]
            ),
            tool(
                "codesk_wait",
                "Wait for macOS UI state to match text, title, app, or focused element. Use after actions to confirm completion.",
                properties: [
                    "condition": ["type": "string", "enum": ["text", "title", "app", "focus"], "description": "Condition type to wait for."],
                    "value": ["type": "string", "description": "Expected value or substring."],
                    "timeout": ["type": "number", "description": "Timeout in seconds.", "default": 5],
                    "interval": ["type": "number", "description": "Polling interval in seconds.", "default": 0.1]
                ],
                required: ["condition", "value"]
            ),
            tool(
                "codesk_find",
                "Find visible Accessibility elements matching text in the front window. Use before pressing ambiguous controls.",
                properties: ["text": ["type": "string", "description": "Text to find."]],
                required: ["text"]
            ),
            tool(
                "codesk_press",
                "Press a visible Accessibility element by label, title, value, or description.",
                properties: ["label": ["type": "string", "description": "Visible label to press."]],
                required: ["label"]
            ),
            tool(
                "codesk_menu",
                "Select an app menu path through Accessibility, for example File > Save or View > Reload Page.",
                properties: ["path": ["type": "string", "description": "Menu path separated by >."]],
                required: ["path"]
            ),
            tool(
                "codesk_screenshot",
                "Capture a screenshot only when text and Accessibility state are insufficient.",
                properties: ["path": ["type": "string", "description": "Optional PNG output path."]]
            ),
            tool(
                "codesk_permissions",
                "Check whether Codesk has macOS Accessibility permission. Can prompt the user to grant it.",
                properties: ["prompt": ["type": "boolean", "description": "Show the macOS Accessibility permission prompt.", "default": false]]
            ),
            tool(
                "codesk_raw",
                "Advanced escape hatch: run a raw codesk CLI command as an argument array, without a shell.",
                properties: [
                    "args": ["type": "array", "items": ["type": "string"], "description": "Arguments after the codesk executable."],
                    "timeoutMs": ["type": "number", "description": "Timeout in milliseconds.", "default": 10_000]
                ],
                required: ["args"]
            )
        ]
    }

    private static func tool(
        _ name: String,
        _ description: String,
        properties: [String: Any] = [:],
        required: [String] = []
    ) -> [String: Any] {
        var schema: [String: Any] = ["type": "object", "properties": properties]
        if !required.isEmpty {
            schema["required"] = required
        }
        return ["name": name, "description": description, "inputSchema": schema]
    }
}

func runProcessCapture(executable: String, arguments: [String], timeout: TimeInterval) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments

    let stdout = Pipe()
    let stderr = Pipe()
    process.standardOutput = stdout
    process.standardError = stderr

    try process.run()

    let deadline = Date().addingTimeInterval(timeout)
    while process.isRunning, Date() < deadline {
        Thread.sleep(forTimeInterval: 0.01)
    }
    if process.isRunning {
        process.terminate()
        throw CommandError("raw command timed out after \(timeout)s")
    }

    let stdoutData = stdout.fileHandleForReading.readDataToEndOfFile()
    let stderrData = stderr.fileHandleForReading.readDataToEndOfFile()
    let outputText = String(data: stdoutData, encoding: .utf8) ?? ""
    let errorText = String(data: stderrData, encoding: .utf8) ?? ""
    let text = [outputText.trimmingCharacters(in: .whitespacesAndNewlines), errorText.trimmingCharacters(in: .whitespacesAndNewlines)]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")

    guard process.terminationStatus == 0 else {
        throw CommandError(text.isEmpty ? "raw command exited with status \(process.terminationStatus)" : text)
    }
    return text
}
