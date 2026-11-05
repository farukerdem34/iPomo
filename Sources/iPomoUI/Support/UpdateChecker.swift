import Foundation

struct AvailableUpdate: Equatable, Sendable {
    let version: String
    let releaseURL: URL
    let downloadURL: URL?
}

enum UpdateCheckError: LocalizedError, Sendable {
    case invalidResponse
    case httpStatus(Int)
    case invalidRelease

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The update server returned an unexpected response."
        case .httpStatus(403):
            return "GitHub is rate-limiting update checks. Try again later."
        case .httpStatus(404):
            return "No published release was found."
        case .httpStatus(let code):
            return "The update server returned HTTP \(code)."
        case .invalidRelease:
            return "The release information was not valid."
        }
    }
}

struct UpdateChecker: Sendable {
    private static let releasesURL = URL(string: "https://api.github.com/repos/farukerdem34/iPomo/releases/latest")!

    /// nil in development builds that have no bundle identifier or version.
    static var currentVersion: String? {
        guard Bundle.main.bundleIdentifier != nil,
              let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !version.isEmpty else { return nil }
        return version
    }

    func latestRelease() async throws -> AvailableUpdate {
        var request = URLRequest(url: Self.releasesURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("iPomo/\(Self.currentVersion ?? "dev")", forHTTPHeaderField: "User-Agent")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        let (data, response) = try await URLSession(configuration: configuration).data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw UpdateCheckError.invalidResponse
        }
        guard http.statusCode == 200 else {
            throw UpdateCheckError.httpStatus(http.statusCode)
        }
        return try Self.parseRelease(data)
    }

    static func parseRelease(_ data: Data) throws -> AvailableUpdate {
        let release: ReleasePayload
        do {
            release = try JSONDecoder().decode(ReleasePayload.self, from: data)
        } catch {
            throw UpdateCheckError.invalidRelease
        }

        var version = release.tagName.trimmingCharacters(in: .whitespacesAndNewlines)
        if version.hasPrefix("v") || version.hasPrefix("V") { version.removeFirst() }
        guard !version.isEmpty else { throw UpdateCheckError.invalidRelease }

        guard let releaseURL = trusted(release.htmlURL) else {
            throw UpdateCheckError.invalidRelease
        }
        let downloadURL = release.assets
            .filter { $0.name.lowercased().hasSuffix(".dmg") }
            .compactMap { trusted($0.browserDownloadURL) }
            .first

        return AvailableUpdate(version: version, releaseURL: releaseURL, downloadURL: downloadURL)
    }

    /// Only HTTPS GitHub URLs in this repository's releases path may be opened.
    private static func trusted(_ url: URL) -> URL? {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "github.com",
              url.path.lowercased().hasPrefix("/farukerdem34/ipomo/releases/") else { return nil }
        return url
    }

    private struct ReleasePayload: Decodable {
        let tagName: String
        let htmlURL: URL
        let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
            case assets
        }

        struct Asset: Decodable {
            let name: String
            let browserDownloadURL: URL

            enum CodingKeys: String, CodingKey {
                case name
                case browserDownloadURL = "browser_download_url"
            }
        }
    }
}
