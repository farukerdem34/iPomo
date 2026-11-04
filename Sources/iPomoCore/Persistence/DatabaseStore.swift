import Foundation

public enum DatabaseLoadOutcome: Sendable {
    case loaded(AppDatabase)
    case fresh(AppDatabase)
    case recovered(AppDatabase, String)
}

public enum DatabaseStoreError: LocalizedError, Sendable {
    case unsupportedSchema(Int)
    case invalidData(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "This backup uses schema version \(version), which is newer than this app supports."
        case .invalidData(let detail):
            return "The data could not be read: \(detail)"
        }
    }
}

public final class DatabaseStore {
    public let directoryURL: URL
    public let fileURL: URL
    public let backupsURL: URL
    private let fileManager: FileManager

    public init(
        directoryURL: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        let base = directoryURL ?? fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("iPomo", isDirectory: true)
            ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("iPomo", isDirectory: true)
        self.directoryURL = base
        self.fileURL = base.appendingPathComponent("data.json")
        self.backupsURL = base.appendingPathComponent("Backups", isDirectory: true)
    }

    public var storagePath: String { fileURL.path }

    // MARK: - Load / save

    public func load() -> DatabaseLoadOutcome {
        createDirectoriesIfNeeded()
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return .fresh(AppDatabase())
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let database = try decode(data)
            return .loaded(database)
        } catch {
            let corruptURL = moveCorruptFile()
            let detail = corruptURL.map { " A copy was kept at \($0.lastPathComponent)." } ?? ""
            return .recovered(
                AppDatabase(),
                "The database could not be decoded.\(detail)"
            )
        }
    }

    public func save(_ database: AppDatabase) throws {
        createDirectoriesIfNeeded()
        backupIfNeeded()
        var copy = database
        copy.updatedAt = Date()
        let data = try encode(copy)
        try data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Export / import

    public func encode(_ database: AppDatabase) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(database)
    }

    public func decode(_ data: Data) throws -> AppDatabase {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            let database = try decoder.decode(AppDatabase.self, from: data)
            guard database.schemaVersion <= AppDatabase.currentSchemaVersion else {
                throw DatabaseStoreError.unsupportedSchema(database.schemaVersion)
            }
            return database
        } catch let error as DatabaseStoreError {
            throw error
        } catch {
            throw DatabaseStoreError.invalidData(error.localizedDescription)
        }
    }

    // MARK: - Backups

    public func backupIfNeeded(force: Bool = false, now: Date = Date()) {
        createDirectoriesIfNeeded()
        guard fileManager.fileExists(atPath: fileURL.path) else { return }
        if !force, let latest = latestBackupDate(), now.timeIntervalSince(latest) < 86_400 {
            return
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let name = "data-\(formatter.string(from: now)).json"
        let destination = backupsURL.appendingPathComponent(name)
        do {
            try fileManager.copyItem(at: fileURL, to: destination)
            pruneBackups(keeping: 7)
        } catch {
            // A failed backup must not block the save.
        }
    }

    public func pruneBackups(keeping count: Int) {
        guard let files = try? fileManager.contentsOfDirectory(
            at: backupsURL,
            includingPropertiesForKeys: nil
        ) else { return }
        let backups = files
            .filter { $0.lastPathComponent.hasPrefix("data-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for stale in backups.dropFirst(max(0, count)) {
            try? fileManager.removeItem(at: stale)
        }
    }

    private func latestBackupDate() -> Date? {
        guard let files = try? fileManager.contentsOfDirectory(
            at: backupsURL,
            includingPropertiesForKeys: nil
        ) else { return nil }
        return files
            .filter { $0.lastPathComponent.hasPrefix("data-") }
            .compactMap { url -> Date? in
                let name = url.deletingPathExtension().lastPathComponent
                let stamp = name.replacingOccurrences(of: "data-", with: "")
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "yyyyMMdd-HHmmss"
                return formatter.date(from: stamp)
            }
            .max()
    }

    private func moveCorruptFile() -> URL? {
        guard fileManager.fileExists(atPath: fileURL.path) else { return nil }
        createDirectoriesIfNeeded()
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let destination = backupsURL.appendingPathComponent(
            "corrupt-\(formatter.string(from: Date())).json"
        )
        do {
            try fileManager.moveItem(at: fileURL, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    private func createDirectoriesIfNeeded() {
        try? fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: backupsURL, withIntermediateDirectories: true)
    }
}
