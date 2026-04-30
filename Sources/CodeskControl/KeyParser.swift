import CoreGraphics
import Foundation

struct KeyStroke: Equatable {
    var keyCode: CGKeyCode
    var flags: CGEventFlags
    var display: String
}

enum KeyParser {
    private static let modifiers: [String: CGEventFlags] = [
        "cmd": .maskCommand,
        "command": .maskCommand,
        "⌘": .maskCommand,
        "shift": .maskShift,
        "⇧": .maskShift,
        "option": .maskAlternate,
        "opt": .maskAlternate,
        "alt": .maskAlternate,
        "⌥": .maskAlternate,
        "control": .maskControl,
        "ctrl": .maskControl,
        "⌃": .maskControl,
        "fn": .maskSecondaryFn
    ]

    private static let keyCodes: [String: CGKeyCode] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "1": 18, "2": 19, "3": 20, "4": 21, "6": 22,
        "5": 23, "=": 24, "equal": 24, "9": 25, "7": 26, "-": 27,
        "minus": 27, "8": 28, "0": 29, "]": 30, "rightbracket": 30,
        "o": 31, "u": 32, "[": 33, "leftbracket": 33, "i": 34, "p": 35,
        "return": 36, "enter": 36, "l": 37, "j": 38, "'": 39, "quote": 39,
        "k": 40, ";": 41, "semicolon": 41, "\\": 42, "backslash": 42,
        ",": 43, "comma": 43, "/": 44, "slash": 44, "n": 45, "m": 46,
        ".": 47, "period": 47, "tab": 48, "space": 49, "spacebar": 49,
        "`": 50, "grave": 50, "backtick": 50, "delete": 51, "backspace": 51,
        "esc": 53, "escape": 53, "help": 114, "home": 115, "pageup": 116,
        "forwarddelete": 117, "del": 117, "end": 119, "pagedown": 121,
        "f1": 122, "f2": 120, "f3": 99, "f4": 118, "f5": 96, "f6": 97,
        "f7": 98, "f8": 100, "f9": 101, "f10": 109, "f11": 103, "f12": 111,
        "left": 123, "leftarrow": 123, "arrowleft": 123, "right": 124,
        "rightarrow": 124, "arrowright": 124, "down": 125, "downarrow": 125,
        "arrowdown": 125, "up": 126, "uparrow": 126, "arrowup": 126
    ]

    private static let shiftedKeys: [String: (CGKeyCode, CGEventFlags)] = [
        "!": (18, .maskShift), "@": (19, .maskShift), "#": (20, .maskShift),
        "$": (21, .maskShift), "%": (23, .maskShift), "^": (22, .maskShift),
        "&": (26, .maskShift), "*": (28, .maskShift), "(": (25, .maskShift),
        ")": (29, .maskShift), "plus": (24, .maskShift), "_": (27, .maskShift),
        "{": (33, .maskShift), "}": (30, .maskShift), "|": (42, .maskShift),
        ":": (41, .maskShift), "\"": (39, .maskShift), "<": (43, .maskShift),
        ">": (47, .maskShift), "?": (44, .maskShift), "~": (50, .maskShift)
    ]

    static func parse(_ chord: String) throws -> KeyStroke {
        let parts = chord
            .split(separator: "+", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        guard !parts.isEmpty else {
            throw CommandError("empty key chord", exitCode: 64)
        }

        var flags = CGEventFlags()
        var keyName: String?

        for part in parts {
            if let modifier = modifiers[part] {
                flags.insert(modifier)
            } else if keyName == nil {
                keyName = part
            } else {
                throw CommandError("too many non-modifier keys in chord: \(chord)", exitCode: 64)
            }
        }

        guard let keyName else {
            throw CommandError("missing key in chord: \(chord)", exitCode: 64)
        }

        if let shifted = shiftedKeys[keyName] {
            flags.insert(shifted.1)
            return KeyStroke(keyCode: shifted.0, flags: flags, display: chord)
        }

        guard let code = keyCodes[keyName] else {
            throw CommandError("unknown key in chord: \(keyName)", exitCode: 64)
        }
        return KeyStroke(keyCode: code, flags: flags, display: chord)
    }
}

