import CoreGraphics
import Foundation

enum SelfTest {
    static func run() throws {
        let shortcut = try KeyParser.parse("cmd+shift+p")
        try expect(shortcut.keyCode == 35, "cmd+shift+p should target the P key")
        try expect(shortcut.flags.contains(.maskCommand), "cmd+shift+p should include command")
        try expect(shortcut.flags.contains(.maskShift), "cmd+shift+p should include shift")

        let safariAddress = try QuickAliases.resolve("address", frontAppName: "Safari")
        try expect(safariAddress.name == "safari.address", "Safari address alias should resolve from front app")
        try expect(safariAddress.chord == "cmd+l", "Safari address alias should use cmd+l")

        let vscodePalette = try QuickAliases.resolve("command-palette", frontAppName: "Visual Studio Code")
        try expect(vscodePalette.name == "vscode.command_palette", "VS Code aliases should accept dash spelling")

        let chromeTarget = ApplicationLaunchTarget.resolve("chrome")
        try expect(chromeTarget.launchName == "Google Chrome", "Chrome app alias should resolve to Google Chrome")
        try expect(chromeTarget.bundleIdentifier == "com.google.Chrome", "Chrome app alias should use the Chrome bundle id")

        let bundleTarget = ApplicationLaunchTarget.resolve("com.google.Chrome")
        try expect(bundleTarget.bundleIdentifier == "com.google.Chrome", "Bundle identifiers should launch with open -b")

        print("selftest: ok")
    }

    private static func expect(_ condition: Bool, _ message: String) throws {
        if !condition {
            throw CommandError("selftest failed: \(message)", exitCode: 1)
        }
    }
}
