// The three App Intents under test. They do nothing real: the benchmark only
// cares whether the model picks the right one with the right parameters.
// Add this file to the app target. They also show up in Shortcuts, which is
// Monday's check that the intents themselves work.

import AppIntents

struct ScheduleMessageIntent: AppIntent {
    static let title: LocalizedStringResource = "Schedule Message"
    static let description = IntentDescription("Queue a message to a person, to be sent at a given time.")

    @Parameter(title: "Recipient") var recipient: ContactEntity
    @Parameter(title: "Message") var body: String
    @Parameter(title: "Time (HH:mm)") var time: String

    init() {}
    init(recipient: ContactEntity, body: String, time: String) {
        self.recipient = recipient
        self.body = body
        self.time = time
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Queued for \(recipient.name) at \(time).")
    }
}

struct CreateNoteIntent: AppIntent {
    static let title: LocalizedStringResource = "Create Note"
    static let description = IntentDescription("Save a note with a title and a body.")

    @Parameter(title: "Title") var noteTitle: String
    @Parameter(title: "Body") var body: String

    init() {}
    init(noteTitle: String, body: String) {
        self.noteTitle = noteTitle
        self.body = body
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Saved note \(noteTitle).")
    }
}

struct SetReminderIntent: AppIntent {
    static let title: LocalizedStringResource = "Set Reminder"
    static let description = IntentDescription("Remind the user about something at a given time.")

    @Parameter(title: "What") var what: String
    @Parameter(title: "Time (HH:mm)") var time: String

    init() {}
    init(what: String, time: String) {
        self.what = what
        self.time = time
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "Reminder set for \(time).")
    }
}
