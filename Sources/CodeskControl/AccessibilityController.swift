import AppKit
import ApplicationServices
import Foundation

struct StateSnapshot: Codable {
    var frontApp: String?
    var bundleIdentifier: String?
    var processIdentifier: Int?
    var windowTitle: String?
    var focusedRole: String?
    var focusedTitle: String?
    var focusedValue: String?
    var selectedText: String?
    var accessibilityTrusted: Bool
    var visibleText: [String]

    func humanReadable() -> String {
        var lines: [String] = []
        lines.append("front_app: \(frontApp ?? "-")")
        lines.append("bundle_id: \(bundleIdentifier ?? "-")")
        lines.append("pid: \(processIdentifier.map(String.init) ?? "-")")
        lines.append("window: \(windowTitle ?? "-")")
        lines.append("focused_role: \(focusedRole ?? "-")")
        if let focusedTitle, !focusedTitle.isEmpty { lines.append("focused_title: \(focusedTitle)") }
        if let focusedValue, !focusedValue.isEmpty { lines.append("focused_value: \(focusedValue)") }
        if let selectedText, !selectedText.isEmpty { lines.append("selected_text: \(selectedText)") }
        lines.append("accessibility: \(accessibilityTrusted ? "trusted" : "not trusted")")
        if !accessibilityTrusted {
            lines.append("hint: run `codesk permissions --prompt` to enable text/control access")
        }
        if !visibleText.isEmpty {
            lines.append("visible_text:")
            lines.append(contentsOf: visibleText.map { "  \($0)" })
        }
        return lines.joined(separator: "\n")
    }
}

struct ElementMatch {
    var element: AXUIElement
    var role: String?
    var title: String?
    var value: String?
    var description: String?

    var descriptionLine: String {
        var parts: [String] = []
        if let role { parts.append(role) }
        if let title, !title.isEmpty { parts.append("title=\"\(title)\"") }
        if let value, !value.isEmpty { parts.append("value=\"\(value)\"") }
        if let description, !description.isEmpty { parts.append("description=\"\(description)\"") }
        return parts.joined(separator: " ")
    }

    func score(for query: String) -> Int {
        let comparable = query.menuComparable
        let fields = [title, value, description].compactMap { $0?.menuComparable }
        if fields.contains(comparable) { return 100 }
        if isActionable { return 40 }
        if fields.contains(where: { $0.contains(comparable) }) { return 20 }
        return 0
    }

    var isActionable: Bool {
        let actionableRoles = ["AXButton", "AXMenuItem", "AXCheckBox", "AXRadioButton", "AXPopUpButton", "AXLink", "AXDisclosureTriangle"]
        return role.map { actionableRoles.contains($0) } ?? false
    }
}

final class AccessibilityController {
    var isTrusted: Bool {
        Self.accessibilityTrusted(prompt: false)
    }

    static func accessibilityTrusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func snapshot(textLimit: Int) -> StateSnapshot {
        let front = NSWorkspace.shared.frontmostApplication
        let pid = front?.processIdentifier
        var windowTitle: String?
        var focusedRole: String?
        var focusedTitle: String?
        var focusedValue: String?
        var selectedText: String?
        var visibleText: [String] = []
        let trusted = isTrusted

        if trusted, let appElement = frontApplicationElement() {
            if let window = elementAttribute(appElement, "AXFocusedWindow") {
                windowTitle = stringAttribute(window, "AXTitle")
                visibleText = collectVisibleText(from: window, limit: textLimit)
            } else {
                visibleText = collectVisibleText(from: appElement, limit: textLimit)
            }

            if let focused = elementAttribute(appElement, "AXFocusedUIElement") {
                focusedRole = stringAttribute(focused, "AXRole")
                focusedTitle = stringAttribute(focused, "AXTitle")
                focusedValue = stringAttribute(focused, "AXValue")
                selectedText = stringAttribute(focused, "AXSelectedText")
            }
        }

        return StateSnapshot(
            frontApp: front?.localizedName,
            bundleIdentifier: front?.bundleIdentifier,
            processIdentifier: pid.map(Int.init),
            windowTitle: windowTitle,
            focusedRole: focusedRole,
            focusedTitle: focusedTitle,
            focusedValue: focusedValue,
            selectedText: selectedText,
            accessibilityTrusted: trusted,
            visibleText: visibleText
        )
    }

    func findElements(matching query: String, limit: Int) -> [ElementMatch] {
        guard let root = focusedRoot() else { return [] }
        var matches: [ElementMatch] = []
        visit(root, maxDepth: 9, limit: 500) { element in
            guard matches.count < limit else { return }
            let match = describe(element)
            let fields = [match.title, match.value, match.description].compactMap { $0 }
            if fields.contains(where: { $0.containsLoose(query) }) {
                matches.append(match)
            }
        }
        return matches
    }

    func pressElement(label: String) throws {
        let matches = findElements(matching: label, limit: 80)
            .sorted { left, right in
                left.score(for: label) > right.score(for: label)
            }

        guard let match = matches.first else {
            throw CommandError("no visible accessibility element matched: \(label)", exitCode: 2)
        }

        let result = AXUIElementPerformAction(match.element, "AXPress" as CFString)
        guard result == .success else {
            throw CommandError("matched \(match.descriptionLine), but AXPress failed with \(result.rawValue)", exitCode: 1)
        }
    }

    func selectMenu(path: String) throws {
        let parts = path.split(separator: ">")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else {
            throw CommandError("empty menu path", exitCode: 64)
        }
        guard let appElement = frontApplicationElement(),
              let menuBar = elementAttribute(appElement, "AXMenuBar") else {
            throw CommandError("front application does not expose an AXMenuBar", exitCode: 1)
        }

        var scope = menuBar
        for part in parts {
            guard let item = findDescendant(named: part, under: scope, maxDepth: 5) else {
                throw CommandError("menu item not found: \(part)", exitCode: 2)
            }
            let result = AXUIElementPerformAction(item, "AXPress" as CFString)
            guard result == .success else {
                throw CommandError("pressing menu item failed: \(part) (\(result.rawValue))", exitCode: 1)
            }
            scope = item
            Thread.sleep(forTimeInterval: 0.14)
        }
    }

    private func focusedRoot() -> AXUIElement? {
        guard let appElement = frontApplicationElement() else { return nil }
        return elementAttribute(appElement, "AXFocusedWindow") ?? appElement
    }

    private func frontApplicationElement() -> AXUIElement? {
        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else { return nil }
        return AXUIElementCreateApplication(pid)
    }

    private func describe(_ element: AXUIElement) -> ElementMatch {
        ElementMatch(
            element: element,
            role: stringAttribute(element, "AXRole"),
            title: stringAttribute(element, "AXTitle"),
            value: stringAttribute(element, "AXValue"),
            description: stringAttribute(element, "AXDescription")
        )
    }

    private func findDescendant(named name: String, under root: AXUIElement, maxDepth: Int) -> AXUIElement? {
        let target = name.menuComparable
        var bestContains: AXUIElement?
        var found: AXUIElement?

        visit(root, maxDepth: maxDepth, limit: 400) { element in
            guard found == nil else { return }
            let fields = [
                stringAttribute(element, "AXTitle"),
                stringAttribute(element, "AXValue"),
                stringAttribute(element, "AXDescription")
            ].compactMap { $0?.menuComparable }

            if fields.contains(target) {
                found = element
            } else if bestContains == nil, fields.contains(where: { $0.contains(target) }) {
                bestContains = element
            }
        }

        return found ?? bestContains
    }

    private func collectVisibleText(from root: AXUIElement, limit: Int) -> [String] {
        var lines: [String] = []
        var seen = Set<String>()

        visit(root, maxDepth: 8, limit: 900) { element in
            guard lines.count < limit else { return }
            if stringAttribute(element, "AXRole") == "AXSecureTextField" {
                return
            }
            for attribute in ["AXTitle", "AXValue", "AXDescription", "AXHelp"] {
                guard let raw = stringAttribute(element, attribute) else { continue }
                let line = raw.compactWhitespace
                guard line.count >= 1, line.count <= 500, !seen.contains(line) else { continue }
                seen.insert(line)
                lines.append(line)
                if lines.count >= limit { return }
            }
        }

        return lines
    }

    private func visit(_ root: AXUIElement, maxDepth: Int, limit: Int, body: (AXUIElement) -> Void) {
        var visited = 0

        func walk(_ element: AXUIElement, depth: Int) {
            guard depth <= maxDepth, visited < limit else { return }
            visited += 1
            body(element)
            for child in arrayAttribute(element, "AXChildren") {
                walk(child, depth: depth + 1)
            }
        }

        walk(root, depth: 0)
    }
}

func copyAttribute(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
    var value: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else { return nil }
    return value
}

func elementAttribute(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
    guard let value = copyAttribute(element, attribute),
          CFGetTypeID(value) == AXUIElementGetTypeID() else {
        return nil
    }
    return (value as! AXUIElement)
}

func arrayAttribute(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
    copyAttribute(element, attribute) as? [AXUIElement] ?? []
}

func stringAttribute(_ element: AXUIElement, _ attribute: String) -> String? {
    guard let value = copyAttribute(element, attribute) else { return nil }

    if let string = value as? String {
        return string
    }
    if let attributed = value as? NSAttributedString {
        return attributed.string
    }
    if let number = value as? NSNumber {
        return number.stringValue
    }
    return nil
}
