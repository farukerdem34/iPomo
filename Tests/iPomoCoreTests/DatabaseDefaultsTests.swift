import Testing
@testable import iPomoCore

@Suite struct DatabaseDefaultsTests {
    @Test func databaseDefaults() {
        let database = AppDatabase()
        #expect(database.schemaVersion == AppDatabase.currentSchemaVersion)
        #expect(database.tasks.isEmpty)
        #expect(database.settings.timer.focusMinutes == 25)
    }
}
