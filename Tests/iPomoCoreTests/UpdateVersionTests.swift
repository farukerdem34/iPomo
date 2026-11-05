import Testing
@testable import iPomoCore

@Suite struct UpdateVersionTests {
    @Test func comparesNumericComponents() {
        #expect(UpdateVersion.isNewer("1.3.0", than: "1.2.9"))
        #expect(!UpdateVersion.isNewer("1.2.9", than: "1.3.0"))
        #expect(!UpdateVersion.isNewer("1.2.3", than: "1.2.3"))
        #expect(!UpdateVersion.isNewer("1.2", than: "1.2.0"))
        #expect(!UpdateVersion.isNewer("1.2.0", than: "1.2"))
        #expect(UpdateVersion.isNewer("1.2.1", than: "1.2"))
        #expect(UpdateVersion.isNewer("1.10.0", than: "1.9.9"))
    }

    @Test func acceptsTagPrefixAndPrereleaseSuffix() {
        #expect(UpdateVersion.isNewer("v1.3.0", than: "1.2.0"))
        #expect(UpdateVersion.isNewer("V1.3", than: "1.2.9"))
        #expect(!UpdateVersion.isNewer("1.2.3-beta.1", than: "1.2.3"))
        #expect(UpdateVersion.isNewer("1.2.3-beta.1", than: "1.2.2"))
    }

    @Test func rejectsStringsWithoutANumericVersion() {
        #expect(!UpdateVersion.isNewer("", than: "1.0.0"))
        #expect(!UpdateVersion.isNewer("1.0.0", than: ""))
        #expect(!UpdateVersion.isNewer("latest", than: "1.0.0"))
        #expect(!UpdateVersion.isNewer("1.0.0", than: "latest"))
        #expect(!UpdateVersion.isNewer("1..2", than: "1.0.0"))
    }
}
