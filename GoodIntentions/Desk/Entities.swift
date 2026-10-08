// App Entity: the recipient stops being a loose string and becomes a contact
// the app actually knows. The model still says a name; the app has to resolve
// that name to exactly one contact. That resolution step is scored.
//
// App Shortcuts: the same three intents with fixed spoken phrases, so Siri and
// Spotlight can run them with no model involved. This is the rigid baseline
// to show next to the model's free-form handling.

import AppIntents

struct ContactEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Contact"
    static let defaultQuery = ContactQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    // A fixed address book of invented people, first name and an initial,
    // no family names. Two near-misses are deliberate: Maria and Mario
    // differ by one letter, and there are two people called Theo.
    //
    // This is the second address book. The sessions of 5 October 2026 ran
    // with six contacts with family names (Maria Keller, Mario Conti, Alex D,
    // Alex Brandt, Elena Rossi, Mum); their logs keep those names.
    static let all: [ContactEntity] = [
        ContactEntity(id: "josephine-b", name: "Josephine B"),
        ContactEntity(id: "alex-d", name: "Alex D"),
        ContactEntity(id: "theo-d", name: "Theo D"),
        ContactEntity(id: "theo-r", name: "Theo R"),
        ContactEntity(id: "claudia-d", name: "Claudia D"),
        ContactEntity(id: "john-d", name: "John D"),
        ContactEntity(id: "maria-f", name: "Maria F"),
        ContactEntity(id: "mario-t", name: "Mario T"),
    ]
}

struct ContactQuery: EntityStringQuery {
    func entities(for identifiers: [String]) async throws -> [ContactEntity] {
        ContactEntity.all.filter { identifiers.contains($0.id) }
    }

    func entities(matching string: String) async throws -> [ContactEntity] {
        let needle = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        return ContactEntity.all.filter { $0.name.localizedCaseInsensitiveContains(needle) }
    }

    func suggestedEntities() async throws -> [ContactEntity] {
        ContactEntity.all
    }
}

struct GoodIntentionsShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScheduleMessageIntent(),
            phrases: [
                "Schedule a message with \(.applicationName)",
                "Schedule a message to \(\.$recipient) with \(.applicationName)",
            ],
            shortTitle: "Schedule Message",
            systemImageName: "clock"
        )
        AppShortcut(
            intent: CreateNoteIntent(),
            phrases: ["Create a note with \(.applicationName)"],
            shortTitle: "Create Note",
            systemImageName: "note.text"
        )
        AppShortcut(
            intent: SetReminderIntent(),
            phrases: ["Set a reminder with \(.applicationName)"],
            shortTitle: "Set Reminder",
            systemImageName: "bell"
        )
    }
}
