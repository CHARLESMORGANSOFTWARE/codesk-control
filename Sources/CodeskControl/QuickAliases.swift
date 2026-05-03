import Foundation

struct QuickAlias: Equatable {
    var name: String
    var chord: String
    var description: String
}

enum QuickAliases {
    static let all: [QuickAlias] = [
        QuickAlias(name: "global.spotlight", chord: "cmd+space", description: "Open Spotlight"),
        QuickAlias(name: "global.app_switcher", chord: "cmd+tab", description: "Switch applications"),
        QuickAlias(name: "global.force_quit", chord: "cmd+option+esc", description: "Open Force Quit"),
        QuickAlias(name: "global.screenshot_area", chord: "cmd+shift+4", description: "Capture a screen area"),

        QuickAlias(name: "safari.address", chord: "cmd+l", description: "Focus the address bar"),
        QuickAlias(name: "safari.new_tab", chord: "cmd+t", description: "Open a new tab"),
        QuickAlias(name: "safari.close_tab", chord: "cmd+w", description: "Close the current tab"),
        QuickAlias(name: "safari.reload", chord: "cmd+r", description: "Reload the page"),
        QuickAlias(name: "safari.find", chord: "cmd+f", description: "Find on page"),
        QuickAlias(name: "safari.back", chord: "cmd+left", description: "Go back"),
        QuickAlias(name: "safari.forward", chord: "cmd+right", description: "Go forward"),

        QuickAlias(name: "chrome.address", chord: "cmd+l", description: "Focus the address bar"),
        QuickAlias(name: "chrome.new_tab", chord: "cmd+t", description: "Open a new tab"),
        QuickAlias(name: "chrome.close_tab", chord: "cmd+w", description: "Close the current tab"),
        QuickAlias(name: "chrome.reload", chord: "cmd+r", description: "Reload the page"),
        QuickAlias(name: "chrome.find", chord: "cmd+f", description: "Find on page"),
        QuickAlias(name: "chrome.devtools", chord: "cmd+option+i", description: "Toggle Developer Tools"),
        QuickAlias(name: "chrome.back", chord: "cmd+left", description: "Go back"),
        QuickAlias(name: "chrome.forward", chord: "cmd+right", description: "Go forward"),

        QuickAlias(name: "finder.goto_folder", chord: "cmd+shift+g", description: "Open Go to Folder"),
        QuickAlias(name: "finder.search", chord: "cmd+f", description: "Search in Finder"),
        QuickAlias(name: "finder.new_window", chord: "cmd+n", description: "Open a new Finder window"),

        QuickAlias(name: "vscode.command_palette", chord: "cmd+shift+p", description: "Open the command palette"),
        QuickAlias(name: "vscode.quick_open", chord: "cmd+p", description: "Open file by name"),
        QuickAlias(name: "vscode.terminal", chord: "ctrl+`", description: "Toggle integrated terminal"),

        QuickAlias(name: "terminal.new_tab", chord: "cmd+t", description: "Open a new terminal tab"),
        QuickAlias(name: "terminal.interrupt", chord: "ctrl+c", description: "Send interrupt")
    ]

    static func resolve(_ requested: String, frontAppName: String?) throws -> QuickAlias {
        let requestedKey = canonical(requested)
        if let exact = all.first(where: { canonical($0.name) == requestedKey }) {
            return exact
        }

        if !requested.contains("."), let prefix = appPrefix(for: frontAppName) {
            let appKey = canonical(prefix + "." + requested)
            if let appAlias = all.first(where: { canonical($0.name) == appKey }) {
                return appAlias
            }
        }

        if !requested.contains(".") {
            let matches = all.filter { alias in
                alias.name.split(separator: ".").last.map { canonical(String($0)) == requestedKey } ?? false
            }
            if matches.count == 1 {
                return matches[0]
            }
            if matches.count > 1 {
                let choices = matches.map(\.name).sorted().joined(separator: ", ")
                throw CommandError("ambiguous quick alias: \(requested). Use a scoped alias such as \(choices).", exitCode: 64)
            }
        }

        throw CommandError("unknown quick alias: \(requested). Run `codesk q list`.", exitCode: 64)
    }

    static func listText() -> String {
        all.sorted(by: { $0.name < $1.name })
            .map {
                "\($0.name.padding(toLength: 28, withPad: " ", startingAt: 0)) \($0.chord.padding(toLength: 18, withPad: " ", startingAt: 0)) \($0.description)"
            }
            .joined(separator: "\n")
    }

    private static func canonical(_ value: String) -> String {
        value.split(separator: ".").map { String($0).aliasComparable }.joined(separator: ".")
    }

    private static func appPrefix(for appName: String?) -> String? {
        guard let appName else { return nil }
        let normalized = appName.aliasComparable
        if normalized.contains("safari") { return "safari" }
        if normalized.contains("chrome") { return "chrome" }
        if normalized.contains("finder") { return "finder" }
        if normalized.contains("visualstudiocode") || normalized == "code" { return "vscode" }
        if normalized.contains("terminal") || normalized.contains("iterm") { return "terminal" }
        return nil
    }
}
