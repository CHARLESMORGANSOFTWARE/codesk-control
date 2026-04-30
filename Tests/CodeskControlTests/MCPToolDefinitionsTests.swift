import Testing
@testable import CodeskControl

struct MCPToolDefinitionsTests {
    @Test func toolNamesAreUniqueAndIncludeCoreTools() {
        let names = MCPToolDefinitions.tools.compactMap { $0["name"] as? String }

        #expect(Set(names).count == names.count)
        #expect(names.contains("codesk_state"))
        #expect(names.contains("codesk_quick"))
        #expect(names.contains("codesk_permissions"))
    }

    @Test func everyToolHasAnInputSchema() {
        for tool in MCPToolDefinitions.tools {
            #expect((tool["description"] as? String) != nil, "missing description for \(tool)")
            #expect((tool["inputSchema"] as? [String: Any]) != nil, "missing input schema for \(tool)")
        }
    }
}
