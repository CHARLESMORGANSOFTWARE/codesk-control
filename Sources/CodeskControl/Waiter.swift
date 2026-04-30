import Foundation

struct Waiter {
    func wait(condition: String, value: String, timeout: TimeInterval, interval: TimeInterval) throws {
        let normalizedCondition = condition.lowercased()
        let deadline = Date().addingTimeInterval(timeout)
        let ax = AccessibilityController()

        repeat {
            let snapshot = ax.snapshot(textLimit: 200)
            if matches(snapshot: snapshot, condition: normalizedCondition, value: value) {
                print("matched \(condition): \(value)")
                return
            }
            Thread.sleep(forTimeInterval: max(interval, 0.02))
        } while Date() < deadline

        throw CommandError("timed out waiting for \(condition): \(value)", exitCode: 2)
    }

    private func matches(snapshot: StateSnapshot, condition: String, value: String) -> Bool {
        switch condition {
        case "text", "visible":
            return snapshot.visibleText.contains { $0.containsLoose(value) }
        case "title", "window":
            return snapshot.windowTitle?.containsLoose(value) == true
        case "app", "application":
            return snapshot.frontApp?.containsLoose(value) == true ||
                snapshot.bundleIdentifier?.containsLoose(value) == true
        case "focus", "focused":
            return snapshot.focusedTitle?.containsLoose(value) == true ||
                snapshot.focusedValue?.containsLoose(value) == true ||
                snapshot.focusedRole?.containsLoose(value) == true
        default:
            return false
        }
    }
}

