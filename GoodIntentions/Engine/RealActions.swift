// Doing it for real, for the live demo only. Reminders go into the phone's
// Reminders app, in a list of their own. Notes are kept in this app, since
// Apple gives apps no way to write into the Notes app. Messages are written
// down and never sent.
//
// The measured tests never come through here: they always use the pretend
// desk, so a thousand runs cannot fill someone's phone with reminders.

import EventKit
import Foundation
import Observation

struct RealReminder: Codable, Identifiable {
    let id: UUID
    var what: String
    var time: String                     // "HH:mm", or empty for no time
    let itemID: String?                  // the reminder in the Reminders app, if it was added
    let problem: String?                 // why it could not be added, if it could not
    let date: Date
}

struct RealNote: Codable, Identifiable {
    let id: UUID
    var title: String
    var body: String
    let date: Date
}

struct RealMessage: Codable, Identifiable {
    let id: UUID
    var to: String
    var body: String
    var time: String                     // "HH:mm", or empty for no time
    let date: Date
}

@Observable
final class RealActions {
    static let shared = RealActions()
    static let listName = "Good Intentions"

    private(set) var reminders: [RealReminder] = []
    private(set) var notes: [RealNote] = []
    private(set) var messages: [RealMessage] = []

    private let store = EKEventStore()

    var count: Int { reminders.count + notes.count + messages.count }

    private init() { load() }

    // MARK: Doing

    func addReminder(what: String, time: String) async {
        var itemID: String?
        var problem: String?
        do {
            guard try await store.requestFullAccessToReminders() else {
                throw Failure("Reminders access is switched off for this app. Switch it on in Settings.")
            }
            // Straight after access is given, the store still sees nothing
            // until it is told to look again.
            store.reset()
            let reminder = EKReminder(eventStore: store)
            reminder.title = what
            reminder.calendar = try list()
            if let due = Self.dueDate(from: time) {
                reminder.dueDateComponents = Calendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute], from: due)
                reminder.addAlarm(EKAlarm(absoluteDate: due))
            }
            try store.save(reminder, commit: true)
            itemID = reminder.calendarItemIdentifier
        } catch {
            problem = error.localizedDescription
        }
        reminders.insert(RealReminder(
            id: UUID(), what: what, time: time, itemID: itemID, problem: problem, date: Date()
        ), at: 0)
        persist()
    }

    func addNote(title: String, body: String) async {
        notes.insert(RealNote(id: UUID(), title: title, body: body, date: Date()), at: 0)
        persist()
    }

    /// Written down, never sent. An app cannot send a message without you
    /// pressing send, and this one should not try.
    func writeMessage(to: String, body: String, time: String) async {
        messages.insert(RealMessage(id: UUID(), to: to, body: body, time: time, date: Date()), at: 0)
        persist()
    }

    // MARK: Editing

    func update(note id: UUID, _ change: (inout RealNote) -> Void) {
        guard let row = notes.firstIndex(where: { $0.id == id }) else { return }
        change(&notes[row])
        persist()
    }

    func update(message id: UUID, _ change: (inout RealMessage) -> Void) {
        guard let row = messages.firstIndex(where: { $0.id == id }) else { return }
        change(&messages[row])
        persist()
    }

    /// Changes the copy kept here. `syncReminder` then carries it over to
    /// the Reminders app, once, when the editing is over.
    func update(reminder id: UUID, _ change: (inout RealReminder) -> Void) {
        guard let row = reminders.firstIndex(where: { $0.id == id }) else { return }
        change(&reminders[row])
        persist()
    }

    /// Makes the reminder in the Reminders app match the one kept here.
    func syncReminder(_ id: UUID) {
        guard let kept = reminders.first(where: { $0.id == id }), let itemID = kept.itemID,
              let item = store.calendarItem(withIdentifier: itemID) as? EKReminder else { return }
        item.title = kept.what
        for alarm in item.alarms ?? [] { item.removeAlarm(alarm) }
        if let due = Self.dueDate(from: kept.time) {
            item.dueDateComponents = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute], from: due)
            item.addAlarm(EKAlarm(absoluteDate: due))
        } else {
            item.dueDateComponents = nil
        }
        try? store.save(item, commit: true)
    }

    /// True when the person's own words mention a time. The AI is made to
    /// fill in a time for every message and reminder, and invents one when
    /// none was said; an invented time is not kept.
    static func mentionsTime(_ sentence: String) -> Bool {
        let text = sentence.lowercased()
        if text.contains(where: \.isNumber) { return true }
        let words = ["noon", "midnight", "morning", "afternoon", "evening", "tonight",
                     "tomorrow", "o'clock", "oclock", "later", "hour", "minute"]
        return words.contains(where: { text.contains($0) })
    }

    /// Does one thing the AI suggested, after the person allowed it.
    func perform(_ call: RecordedCall) async {
        switch call.tool {
        case "scheduleMessage":
            // The name from the address book when the AI's wording matched
            // exactly one person, otherwise the AI's own wording.
            let known = ContactEntity.all.first(where: { $0.id == call.args["recipientID"] })?.name
            await writeMessage(to: known ?? call.args["recipient"] ?? "", body: call.args["body"] ?? "", time: call.args["time"] ?? "")
        case "createNote":
            await addNote(title: call.args["title"] ?? "", body: call.args["body"] ?? "")
        case "setReminder":
            await addReminder(what: call.args["what"] ?? "", time: call.args["time"] ?? "")
        default:
            break
        }
    }

    /// True while everything is being taken back, so the screen can say so.
    private(set) var isUndoing = false

    /// Takes back everything: removes the app's lists from the Reminders app
    /// with the reminders in them, and empties the notes and messages kept
    /// here. Removing a list can take seconds when it lives in an online
    /// account, so that part runs away from the screen.
    func undoEverything() async {
        guard !isUndoing else { return }
        isUndoing = true
        await Self.removeLists(named: Self.listName)
        store.reset()
        UserDefaults.standard.removeObject(forKey: Self.listKey)
        reminders = []
        notes = []
        messages = []
        persist()
        isUndoing = false
    }

    /// Runs off the main thread, with a store of its own.
    @concurrent
    nonisolated private static func removeLists(named name: String) async {
        let store = EKEventStore()
        for calendar in store.calendars(for: .reminder) where calendar.title == name {
            try? store.removeCalendar(calendar, commit: true)
        }
    }

    // MARK: Reminders plumbing


    /// Every list with the app's name. There should be one, but an earlier
    /// version could leave one per account.
    private var lists: [EKCalendar] {
        store.calendars(for: .reminder).filter { $0.title == Self.listName }
    }

    private static let listKey = "realRemindersListID"

    /// The app's own list in the Reminders app, made on first use and then
    /// remembered, so it is always the same one.
    private func list() throws -> EKCalendar {
        let remembered = UserDefaults.standard.string(forKey: Self.listKey)
        if let known = lists.first(where: { $0.calendarIdentifier == remembered }) {
            return known
        }
        // Not remembered: take an existing one, a personal account before a work one.
        if let existing = lists.first(where: { $0.source.sourceType != .exchange }) ?? lists.first {
            UserDefaults.standard.set(existing.calendarIdentifier, forKey: Self.listKey)
            return existing
        }
        // None yet. It goes into a personal account (iCloud, or the phone
        // itself) before a work one, so a demo does not sync to an employer.
        let sources = store.sources.filter { !$0.calendars(for: .reminder).isEmpty }
        let source = sources.first(where: { $0.sourceType == .calDAV })
            ?? sources.first(where: { $0.sourceType == .local })
            ?? store.defaultCalendarForNewReminders()?.source
            ?? store.sources.first(where: { $0.sourceType == .local })
        guard let source else {
            throw Failure("This phone has no place to keep reminders.")
        }
        let calendar = EKCalendar(for: .reminder, eventStore: store)
        calendar.title = Self.listName
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        UserDefaults.standard.set(calendar.calendarIdentifier, forKey: Self.listKey)
        return calendar
    }

    /// "14:30" becomes the next 14:30. Anything else gets no due time.
    static func dueDate(from time: String) -> Date? {
        let parts = time.trimmingCharacters(in: .whitespaces).split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]),
              (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        let now = Date()
        guard let today = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: now) else {
            return nil
        }
        return today > now ? today : Calendar.current.date(byAdding: .day, value: 1, to: today)
    }

    private struct Failure: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }

    // MARK: Keeping

    private struct Saved: Codable {
        var reminders: [RealReminder]
        var notes: [RealNote]
        var messages: [RealMessage]
    }

    private static var file: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("real-actions.json")
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.file),
              let saved = try? JSONDecoder().decode(Saved.self, from: data) else { return }
        reminders = saved.reminders
        notes = saved.notes
        messages = saved.messages
    }

    private func persist() {
        let saved = Saved(reminders: reminders, notes: notes, messages: messages)
        try? JSONEncoder().encode(saved).write(to: Self.file, options: .atomic)
    }
}
