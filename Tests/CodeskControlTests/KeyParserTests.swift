import CoreGraphics
import Testing
@testable import CodeskControl

struct KeyParserTests {
    @Test func parsesModifiedCharacterChord() throws {
        let stroke = try KeyParser.parse("cmd+shift+p")

        #expect(stroke.keyCode == CGKeyCode(35))
        #expect(stroke.flags.contains(.maskCommand))
        #expect(stroke.flags.contains(.maskShift))
        #expect(stroke.display == "cmd+shift+p")
    }

    @Test func shiftedSymbolAddsShiftModifier() throws {
        let stroke = try KeyParser.parse("?")

        #expect(stroke.keyCode == CGKeyCode(44))
        #expect(stroke.flags.contains(.maskShift))
    }

    @Test func rejectsMultipleNonModifierKeys() {
        do {
            _ = try KeyParser.parse("a+b")
            Issue.record("Expected parse to throw")
        } catch let error as CommandError {
            #expect(error.exitCode == 64)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
