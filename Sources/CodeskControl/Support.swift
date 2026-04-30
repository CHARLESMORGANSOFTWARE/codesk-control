import Darwin
import Foundation

struct CommandError: Error {
    var message: String
    var exitCode: Int32

    init(_ message: String, exitCode: Int32 = 1) {
        self.message = "codesk: \(message)"
        self.exitCode = exitCode
    }
}

struct ArgumentCursor {
    private var arguments: [String]
    private var index = 0

    init(_ arguments: [String]) {
        self.arguments = arguments
    }

    mutating func next() -> String? {
        guard index < arguments.count else { return nil }
        defer { index += 1 }
        return arguments[index]
    }

    func remaining() -> [String] {
        guard index < arguments.count else { return [] }
        return Array(arguments[index...])
    }

    mutating func requireDouble(after option: String) throws -> Double {
        guard let raw = next() else {
            throw CommandError("missing value after \(option)", exitCode: 64)
        }
        return try parseDouble(raw, name: option)
    }
}

struct StateOptions {
    var json = false
    var limit = 120

    init(_ args: [String]) {
        var cursor = ArgumentCursor(args)
        while let arg = cursor.next() {
            if arg == "--json" {
                json = true
            } else if arg == "--limit", let next = cursor.next(), let value = Int(next) {
                limit = value
            } else if let value = arg.valueForLongOption("--limit"), let parsed = Int(value) {
                limit = parsed
            }
        }
    }
}

func standardError(_ message: String) {
    FileHandle.standardError.write(Data((message + "\n").utf8))
}

func parseDouble(_ raw: String, name: String) throws -> Double {
    guard let value = Double(raw) else {
        throw CommandError("invalid numeric value for \(name): \(raw)", exitCode: 64)
    }
    return value
}

func textFromArguments(_ args: [String], purpose: String) throws -> String {
    if !args.isEmpty {
        return args.joined(separator: " ")
    }
    if isatty(STDIN_FILENO) == 0 {
        let data = FileHandle.standardInput.readDataToEndOfFile()
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }
    }
    throw CommandError("missing \(purpose)", exitCode: 64)
}

func printEncodedJSON<T: Encodable>(_ value: T) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(value)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

extension String {
    func valueForLongOption(_ option: String) -> String? {
        let prefix = option + "="
        guard hasPrefix(prefix) else { return nil }
        return String(dropFirst(prefix.count))
    }

    var compactWhitespace: String {
        split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    var menuComparable: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "…", with: "...")
            .compactWhitespace
            .lowercased()
    }

    var aliasComparable: String {
        lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    func containsLoose(_ needle: String) -> Bool {
        range(of: needle, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
}

