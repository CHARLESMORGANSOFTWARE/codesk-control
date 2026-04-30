import AppKit
import CoreGraphics
import Foundation

final class KeyboardController {
    private let source = CGEventSource(stateID: .hidSystemState)

    func press(_ stroke: KeyStroke) throws {
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: stroke.keyCode, keyDown: false) else {
            throw CommandError("could not create key event for \(stroke.display)")
        }

        down.flags = stroke.flags
        up.flags = stroke.flags
        down.post(tap: .cghidEventTap)
        usleep(18_000)
        up.post(tap: .cghidEventTap)
    }

    func typeText(_ text: String, delay: TimeInterval = 0.003) throws {
        for character in text {
            try postUnicode(character)
            if delay > 0 {
                Thread.sleep(forTimeInterval: delay)
            }
        }
    }

    private func postUnicode(_ character: Character) throws {
        let units = Array(String(character).utf16)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
            throw CommandError("could not create text event")
        }

        units.withUnsafeBufferPointer { buffer in
            down.keyboardSetUnicodeString(stringLength: units.count, unicodeString: buffer.baseAddress)
            up.keyboardSetUnicodeString(stringLength: units.count, unicodeString: buffer.baseAddress)
        }
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

final class ClipboardController {
    func paste(_ text: String, restoreClipboard: Bool, restoreDelay: TimeInterval) throws {
        let pasteboard = NSPasteboard.general
        let snapshot = restoreClipboard ? PasteboardSnapshot.capture(from: pasteboard) : nil

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        try KeyboardController().press(KeyParser.parse("cmd+v"))

        if let snapshot {
            Thread.sleep(forTimeInterval: restoreDelay)
            snapshot.restore(to: pasteboard)
        }
    }
}

struct PasteboardSnapshot {
    struct Item {
        var values: [(NSPasteboard.PasteboardType, Data)]
    }

    var items: [Item]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            Item(values: item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            })
        }
        return PasteboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restoredItems: [NSPasteboardItem] = items.map { item in
            let restored = NSPasteboardItem()
            for (type, data) in item.values {
                restored.setData(data, forType: type)
            }
            return restored
        }
        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }
}

