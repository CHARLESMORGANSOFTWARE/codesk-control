import Testing
@testable import CodeskControl

struct QuickAliasesTests {
    @Test func resolvesExactAlias() throws {
        let alias = try QuickAliases.resolve("finder.goto_folder", frontAppName: nil)

        #expect(alias.name == "finder.goto_folder")
        #expect(alias.chord == "cmd+shift+g")
    }

    @Test func resolvesAppScopedAliasFromFrontApp() throws {
        let alias = try QuickAliases.resolve("address", frontAppName: "Safari")

        #expect(alias.name == "safari.address")
        #expect(alias.chord == "cmd+l")
    }

    @Test func acceptsLooseAliasSpelling() throws {
        let alias = try QuickAliases.resolve("command-palette", frontAppName: "Visual Studio Code")

        #expect(alias.name == "vscode.command_palette")
    }

    @Test func rejectsAmbiguousUnscopedAlias() {
        do {
            _ = try QuickAliases.resolve("address", frontAppName: nil)
            Issue.record("Expected alias resolution to throw")
        } catch let error as CommandError {
            #expect(error.exitCode == 64)
            #expect(error.message.contains("ambiguous quick alias: address"))
            #expect(error.message.contains("chrome.address"))
            #expect(error.message.contains("safari.address"))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func listTextIsSortedForStableOutput() {
        let lines = QuickAliases.listText().split(separator: "\n")

        #expect(lines.first?.prefix("chrome.address".count) == "chrome.address")
    }
}
