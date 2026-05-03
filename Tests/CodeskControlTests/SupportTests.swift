import Testing
@testable import CodeskControl

struct SupportTests {
    @Test func stateOptionsParseJsonAndLimitForms() {
        let spaced = StateOptions(["--json", "--limit", "40"])
        let equals = StateOptions(["--limit=80"])

        #expect(spaced.json)
        #expect(spaced.limit == 40)
        #expect(equals.limit == 80)
    }

    @Test func longOptionValueExtraction() {
        #expect("--timeout=2.5".valueForLongOption("--timeout") == "2.5")
        #expect("--timeout".valueForLongOption("--timeout") == nil)
    }

    @Test func menuComparableNormalizesWhitespaceAndEllipsis() {
        #expect("  Export   As…  ".menuComparable == "export as...")
    }

    @Test func applicationLaunchTargetResolvesChromeAlias() {
        let target = ApplicationLaunchTarget.resolve("chrome")

        #expect(target.launchName == "Google Chrome")
        #expect(target.bundleIdentifier == "com.google.Chrome")
    }

    @Test func applicationLaunchTargetKeepsBundleIdentifiers() {
        let target = ApplicationLaunchTarget.resolve("com.google.Chrome")

        #expect(target.launchName == "com.google.Chrome")
        #expect(target.bundleIdentifier == "com.google.Chrome")
    }
}
