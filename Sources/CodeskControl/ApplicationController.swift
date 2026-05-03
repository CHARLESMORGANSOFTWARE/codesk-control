import AppKit
import Foundation

struct ApplicationController {
    var frontmostApplicationName: String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }

    @discardableResult
    func activate(_ query: String) throws -> ApplicationLaunchTarget {
        let target = ApplicationLaunchTarget.resolve(query)

        if let app = matchingRunningApplication(target) {
            guard app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) else {
                throw CommandError("could not activate \(query)")
            }
            try waitForFrontmost(target, query: query, timeout: 1.2)
            return target
        }

        if let bundleIdentifier = target.bundleIdentifier {
            try runProcess("/usr/bin/open", arguments: ["-b", bundleIdentifier])
        } else {
            try runProcess("/usr/bin/open", arguments: ["-a", target.launchName])
        }

        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            if let app = matchingRunningApplication(target) {
                guard app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) else {
                    throw CommandError("could not activate \(query)")
                }
                try waitForFrontmost(target, query: query, timeout: 1.2)
                return target
            }
            Thread.sleep(forTimeInterval: 0.10)
        }

        throw CommandError("could not launch \(query)")
    }

    func openTarget(_ target: String) throws {
        let expanded = NSString(string: target).expandingTildeInPath
        let url: URL
        if let parsed = URL(string: target), parsed.scheme != nil {
            url = parsed
        } else {
            url = URL(fileURLWithPath: expanded)
        }

        guard NSWorkspace.shared.open(url) else {
            throw CommandError("could not open \(target)")
        }
    }

    private func waitForFrontmost(_ target: ApplicationLaunchTarget, query: String, timeout: TimeInterval) throws {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if let frontmost = NSWorkspace.shared.frontmostApplication,
               application(frontmost, matches: target) {
                return
            }
            Thread.sleep(forTimeInterval: 0.03)
        } while Date() < deadline

        throw CommandError("could not make \(target.launchName) frontmost for \(query)")
    }

    private func matchingRunningApplication(_ target: ApplicationLaunchTarget) -> NSRunningApplication? {
        NSWorkspace.shared.runningApplications.first { application($0, matches: target) }
    }

    private func application(_ app: NSRunningApplication, matches target: ApplicationLaunchTarget) -> Bool {
        let normalizedLaunchName = target.launchName.lowercased()
        let normalizedQuery = target.originalQuery.lowercased()

        if let bundleIdentifier = target.bundleIdentifier?.lowercased(),
           app.bundleIdentifier?.lowercased() == bundleIdentifier {
            return true
        }

        if app.localizedName?.lowercased() == normalizedLaunchName {
            return true
        }

        if app.localizedName?.lowercased() == normalizedQuery {
            return true
        }

        return app.activationPolicy == .regular &&
            app.localizedName?.lowercased().contains(normalizedQuery) == true
    }
}

struct ApplicationLaunchTarget: Equatable {
    var originalQuery: String
    var launchName: String
    var bundleIdentifier: String?

    var description: String {
        if let bundleIdentifier {
            return "\(launchName) (\(bundleIdentifier))"
        }
        return launchName
    }

    static func resolve(_ query: String) -> ApplicationLaunchTarget {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let canonical = trimmed.aliasComparable
        if let known = knownApplications[canonical] {
            return ApplicationLaunchTarget(
                originalQuery: query,
                launchName: known.launchName,
                bundleIdentifier: known.bundleIdentifier
            )
        }

        if looksLikeBundleIdentifier(trimmed) {
            return ApplicationLaunchTarget(
                originalQuery: query,
                launchName: trimmed,
                bundleIdentifier: trimmed
            )
        }

        return ApplicationLaunchTarget(
            originalQuery: query,
            launchName: trimmed,
            bundleIdentifier: nil
        )
    }

    private static let knownApplications: [String: (launchName: String, bundleIdentifier: String)] = [
        "chrome": ("Google Chrome", "com.google.Chrome"),
        "googlechrome": ("Google Chrome", "com.google.Chrome"),
        "safari": ("Safari", "com.apple.Safari"),
        "firefox": ("Firefox", "org.mozilla.firefox"),
        "calculator": ("Calculator", "com.apple.calculator"),
        "calc": ("Calculator", "com.apple.calculator"),
        "vscode": ("Visual Studio Code", "com.microsoft.VSCode"),
        "visualstudiocode": ("Visual Studio Code", "com.microsoft.VSCode"),
        "code": ("Visual Studio Code", "com.microsoft.VSCode")
    ]

    private static func looksLikeBundleIdentifier(_ value: String) -> Bool {
        value.contains(".") && !value.contains("/") && !value.contains(" ")
    }
}

func runProcess(_ executable: String, arguments: [String]) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: executable)
    process.arguments = arguments
    try process.run()
    process.waitUntilExit()
    if process.terminationStatus != 0 {
        throw CommandError("\(executable) exited with status \(process.terminationStatus)")
    }
}
