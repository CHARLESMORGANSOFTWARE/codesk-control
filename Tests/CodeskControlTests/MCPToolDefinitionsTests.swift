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

    @Test func browserSensitiveToolsAdvertiseDomBoundary() {
        let descriptions: [String: String] = Dictionary(uniqueKeysWithValues: MCPToolDefinitions.tools.compactMap { tool -> (String, String)? in
            guard let name = tool["name"] as? String,
                  let description = tool["description"] as? String else {
                return nil
            }
            return (name, description)
        })

        for name in ["codesk_state", "codesk_text", "codesk_app", "codesk_open", "codesk_key", "codesk_keys", "codesk_quick", "codesk_paste", "codesk_type", "codesk_wait", "codesk_find", "codesk_press", "codesk_menu", "codesk_screenshot"] {
            #expect(descriptions[name]?.contains("DOM") == true, "missing DOM boundary warning for \(name)")
            #expect(descriptions[name]?.contains("Codex Web") == true, "missing Codex Web boundary warning for \(name)")
        }
    }
}
