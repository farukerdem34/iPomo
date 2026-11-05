import Foundation
import Testing
@testable import iPomoUI

@Suite struct UpdateCheckerTests {
    @Test func parsesReleaseAndSelectsDMG() throws {
        let json = """
        {
          "tag_name": "v1.4.0",
          "html_url": "https://github.com/farukerdem34/iPomo/releases/tag/v1.4.0",
          "assets": [
            {
              "name": "iPomo-1.4.0.dmg",
              "browser_download_url": "https://github.com/farukerdem34/iPomo/releases/download/v1.4.0/iPomo-1.4.0.dmg"
            },
            {
              "name": "iPomo-1.4.0.dmg.sha256",
              "browser_download_url": "https://github.com/farukerdem34/iPomo/releases/download/v1.4.0/iPomo-1.4.0.dmg.sha256"
            }
          ]
        }
        """
        let update = try UpdateChecker.parseRelease(Data(json.utf8))
        #expect(update.version == "1.4.0")
        #expect(update.releaseURL.absoluteString == "https://github.com/farukerdem34/iPomo/releases/tag/v1.4.0")
        #expect(update.downloadURL?.lastPathComponent == "iPomo-1.4.0.dmg")
    }

    @Test func releaseWithoutDMGHasaNilDownloadURL() throws {
        let json = """
        {"tag_name":"v1.4.0","html_url":"https://github.com/farukerdem34/iPomo/releases/tag/v1.4.0","assets":[]}
        """
        let update = try UpdateChecker.parseRelease(Data(json.utf8))
        #expect(update.downloadURL == nil)
    }

    @Test func ignoresUntrustedDownloadURL() throws {
        let json = """
        {"tag_name":"v1.4.0","html_url":"https://github.com/farukerdem34/iPomo/releases/tag/v1.4.0","assets":[{"name":"iPomo-1.4.0.dmg","browser_download_url":"https://evil.example.com/iPomo-1.4.0.dmg"}]}
        """
        let update = try UpdateChecker.parseRelease(Data(json.utf8))
        #expect(update.downloadURL == nil)
    }

    @Test func rejectsUntrustedReleasePage() {
        let json = """
        {"tag_name":"v1.4.0","html_url":"https://evil.example.com/farukerdem34/iPomo/releases/tag/v1.4.0","assets":[]}
        """
        #expect(throws: UpdateCheckError.self) {
            _ = try UpdateChecker.parseRelease(Data(json.utf8))
        }
    }

    @Test func rejectsAnotherRepository() {
        let json = """
        {"tag_name":"v1.4.0","html_url":"https://github.com/someone/else/releases/tag/v1.4.0","assets":[]}
        """
        #expect(throws: UpdateCheckError.self) {
            _ = try UpdateChecker.parseRelease(Data(json.utf8))
        }
    }

    @Test func rejectsMalformedPayload() {
        #expect(throws: UpdateCheckError.self) {
            _ = try UpdateChecker.parseRelease(Data("not json".utf8))
        }
    }
}
