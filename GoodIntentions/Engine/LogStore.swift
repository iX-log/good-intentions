// Where the tests live: Documents/logs, one JSON file per test.
// The Results tab shows whichever test is open here.

import Foundation
import Observation

@Observable
final class LogStore {
    private(set) var files: [URL] = []          // newest first
    private var titles: [URL: String] = [:]
    private(set) var current: RunFile?
    private(set) var currentURL: URL?
    private(set) var loadError: String?

    static var folder: URL {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("logs", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    init() {
        refresh()
        // Open the newest run that this build can read.
        for url in files {
            if let file = Self.read(url) {
                current = file
                currentURL = url
                break
            }
        }
    }

    func refresh() {
        let urls = (try? FileManager.default.contentsOfDirectory(
            at: Self.folder, includingPropertiesForKeys: [.creationDateKey])) ?? []
        files = urls.filter { $0.pathExtension == "json" }
            .sorted { Self.created($0) > Self.created($1) }
        titles = [:]
        for url in files { titles[url] = makeTitle(for: url) }
    }

    private static func created(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
    }

    /// Tests are numbered in the order they were run: test-1.json, test-2.json.
    private func nextName() -> String {
        let used = files.compactMap { url -> Int? in
            let name = url.deletingPathExtension().lastPathComponent
            guard name.hasPrefix("test-") else { return nil }
            return Int(name.dropFirst(5))
        }
        return "test-\((used.max() ?? 0) + 1).json"
    }

    func open(_ url: URL) {
        if let file = Self.read(url) {
            current = file
            currentURL = url
            loadError = nil
        } else {
            loadError = "\(url.lastPathComponent) is in an older format and cannot be shown here. It can still be shared."
        }
    }

    /// Writes a run to disk and shows it. Returns the file name, or nil if
    /// the write failed. Called after every pass, so the same file is
    /// rewritten as the examination goes on.
    @discardableResult
    func save(_ file: RunFile) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]          // compact: there are hundreds of records
        encoder.dateEncodingStrategy = .iso8601
        // The same test keeps its file while it runs; a new test gets the next number.
        let url: URL
        if let currentURL, current?.startedAt == file.startedAt {
            url = currentURL
        } else {
            url = Self.folder.appendingPathComponent(nextName())
        }
        let name = url.lastPathComponent
        do {
            try encoder.encode(file).write(to: url, options: .atomic)
            current = file
            currentURL = url
            loadError = nil
            refresh()
            return name
        } catch {
            return nil
        }
    }

    func deleteAll() {
        for url in files { try? FileManager.default.removeItem(at: url) }
        current = nil
        currentURL = nil
        loadError = nil
        refresh()
    }

    /// A saved test's name for the screen, worked out once when the list is read.
    func title(for url: URL) -> String {
        titles[url] ?? url.deletingPathExtension().lastPathComponent
    }

    /// "Test Charlie, the main 44". Every saved test is named by age, oldest
    /// first, whatever its file is called. No date on purpose: the screens
    /// name a test, they do not date it. The start time stays inside the file.
    private func makeTitle(for url: URL) -> String {
        let number = (files.reversed().firstIndex(of: url) ?? 0) + 1
        guard let file = Self.read(url) else { return "Test \(Self.codeName(number))" }
        return "Test \(Self.codeName(number)), \(file.sentenceSetTitle.lowercasedFirst)"
    }

    /// The short name of the test on screen, "Test Charlie", without the sentences.
    func shortTitle(for url: URL) -> String {
        let number = (files.reversed().firstIndex(of: url) ?? 0) + 1
        return "Test \(Self.codeName(number))"
    }

    /// 1 is Alpha, 2 is Bravo, through Zulu; then Alpha 2, Bravo 2, and on.
    static func codeName(_ number: Int) -> String {
        let names = ["Alpha", "Bravo", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel",
                     "India", "Juliett", "Kilo", "Lima", "Mike", "November", "Oscar", "Papa",
                     "Quebec", "Romeo", "Sierra", "Tango", "Uniform", "Victor", "Whiskey",
                     "X-ray", "Yankee", "Zulu"]
        guard number > 0 else { return "\(number)" }
        let name = names[(number - 1) % names.count]
        let round = (number - 1) / names.count + 1
        return round == 1 ? name : "\(name) \(round)"
    }

    private static func read(_ url: URL) -> RunFile? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(RunFile.self, from: data)
    }
}

private extension String {
    /// "The main 44" becomes "the main 44", to sit after a comma.
    var lowercasedFirst: String {
        guard let first else { return self }
        return first.lowercased() + dropFirst()
    }
}
