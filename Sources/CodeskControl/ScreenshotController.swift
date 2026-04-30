import Foundation

struct ScreenshotController {
    func capture(to requestedPath: String?) throws -> URL {
        let output: URL
        if let requestedPath, !requestedPath.isEmpty {
            output = URL(fileURLWithPath: NSString(string: requestedPath).expandingTildeInPath)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd-HHmmss"
            let name = "codesk-screenshot-\(formatter.string(from: Date())).png"
            output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(name)
        }

        try runProcess("/usr/sbin/screencapture", arguments: ["-x", output.path])
        return output
    }
}

