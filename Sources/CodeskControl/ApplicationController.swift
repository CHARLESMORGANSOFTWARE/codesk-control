import AppKit
import Foundation

struct ApplicationController {
    var frontmostApplicationName: String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }

    func activate(_ query: String) throws {
        if let app = matchingRunningApplication(query) {
            guard app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps]) else {
                throw CommandError("could not activate \(query)")
            }
            return
        }

        try runProcess("/usr/bin/open", arguments: ["-a", query])
        let deadline = Date().addingTimeInterval(4)
        while Date() < deadline {
            if let app = matchingRunningApplication(query) {
                _ = app.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                return
            }
            Thread.sleep(forTimeInterval: 0.10)
        }
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

    private func matchingRunningApplication(_ query: String) -> NSRunningApplication? {
        let normalized = query.lowercased()
        return NSWorkspace.shared.runningApplications.first { app in
            if app.bundleIdentifier?.lowercased() == normalized {
                return true
            }
            if app.localizedName?.lowercased() == normalized {
                return true
            }
            return app.localizedName?.lowercased().contains(normalized) == true
        }
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

