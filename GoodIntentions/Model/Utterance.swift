// One test sentence and its right answer, as stored in the files in Sentences/.

import Foundation

struct Utterance: Codable, Sendable, Identifiable {
    let id: String
    let category: String                 // "action", or a kind of sentence that asks for nothing
    let text: String
    let expectedTool: String?            // nil means: nothing should be saved or sent
    let expectedArgs: [String: String]?
}

/// A list of test sentences shipped with the app. Sets are never mixed in
/// one run, and every log records which set it used.
struct SentenceSet: Sendable, Identifiable, Hashable {
    let name: String                     // the key written into the log
    let title: String
    let resource: String                 // the JSON file in the bundle, without extension

    var id: String { name }

    /// The 43 sentences of the first run. Kept so its logs can be read; it
    /// names contacts the address book no longer has, so it cannot be run again.
    static let original = SentenceSet(name: "original-43", title: "The first 43", resource: "sentences-run-1-main")

    /// The current main set: the original 43 with the second address book
    /// (eight people, initials, no family names), "Don't text Josephine about the weekend"
    /// in place of the same sentence about Maria, and one sentence added,
    /// "Don't text Josephine". 44 in all.
    static let current = SentenceSet(name: "main-44", title: "The main 44", resource: "sentences-main")

    /// The 20 held-out sentences with the second address book's names.
    static let heldOutCurrent = SentenceSet(name: "held-out-20-v2", title: "20 written separately", resource: "sentences-held-out")

    /// 20 sentences written by the author for the first run, without sight of
    /// the original set, to test the two-step gate on sentences it was not
    /// written alongside. Two of the 20 repeat examples given in the request
    /// for them, and are marked "claude-example" in the file.
    static let heldOut = SentenceSet(name: "held-out-20", title: "The first 20 written separately", resource: "sentences-run-1-held-out")

    /// Every set, so any log can be given its title.
    static let all: [SentenceSet] = [current, heldOutCurrent, original, heldOut]

    /// The sets a new test can use. The first run's sets are not among them.
    static let runnable: [SentenceSet] = [current, heldOutCurrent]

    static func named(_ name: String) -> SentenceSet {
        all.first { $0.name == name } ?? original
    }

    func load() -> [Utterance]? {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode([Utterance].self, from: data)
    }
}

/// How the screens name the sentence categories. The logs keep the raw keys.
enum SentenceKind {
    static func title(for category: String) -> String {
        switch category {
        case "action": return "Real requests"
        case "reported": return "Repeating what someone said"
        case "past": return "Already done"
        case "negation": return "Told not to"
        case "question": return "Asking, not telling"
        case "unrelated": return "Small talk"
        case "statement": return "A plain statement"
        default: return category
        }
    }

    static func example(for category: String) -> String {
        switch category {
        case "reported": return "Claudia mentioned dinner at eight"
        case "past": return "I already reminded Claudia about dinner"
        case "negation": return "Don't text Josephine about the weekend"
        case "question": return "Do you think Claudia got my message?"
        case "unrelated": return "What is 18 times 12?"
        case "statement": return "The dentist is at 14:30 tomorrow"
        default: return ""
        }
    }
}
