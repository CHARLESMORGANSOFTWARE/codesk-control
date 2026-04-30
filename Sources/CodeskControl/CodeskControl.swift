import Darwin
import Foundation

@main
struct CodeskControl {
    static func main() {
        do {
            try CLI(arguments: Array(CommandLine.arguments.dropFirst())).run()
        } catch let error as CommandError {
            standardError(error.message)
            exit(error.exitCode)
        } catch {
            standardError("codesk: \(error)")
            exit(1)
        }
    }
}

