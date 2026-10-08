// One Foundation Models tool per intent. Each wrapper records what the model
// asked for, then runs the intent. The recorder is what the scorer reads.

import Foundation
import FoundationModels

struct RecordedCall: Codable, Sendable {
    let tool: String
    let args: [String: String]
    let secondsSinceStart: Double
}

actor CallRecorder {
    private let clock = ContinuousClock()
    private var start: ContinuousClock.Instant
    private(set) var calls: [RecordedCall] = []

    init() { start = ContinuousClock().now }

    func restart() { start = clock.now; calls = [] }

    func record(tool: String, args: [String: String]) {
        let elapsed = clock.now - start
        let seconds = Double(elapsed.components.seconds)
            + Double(elapsed.components.attoseconds) / 1e18
        calls.append(RecordedCall(tool: tool, args: args, secondsSinceStart: seconds))
    }
}

struct ScheduleMessageTool: Tool {
    let name = "scheduleMessage"
    let description = "Queue a message to a person, to be sent at a given time."
    let recorder: CallRecorder
    var live = false                     // true only in the live demo, never in a test

    @Generable
    struct Arguments {
        @Guide(description: "Name of the person to message")
        var recipient: String
        @Guide(description: "The message text, exactly as the user wants it sent")
        var body: String
        @Guide(description: "Time to send, 24-hour clock, formatted HH:mm")
        var time: String
    }

    func call(arguments: Arguments) async throws -> String {
        // Resolve the name the model gave to a contact the app knows.
        // recipientID is the contact's id, or "none", or "ambiguous".
        let matches = try await ContactQuery().entities(matching: arguments.recipient)
        let recipientID = matches.count == 1 ? matches[0].id : (matches.isEmpty ? "none" : "ambiguous")

        await recorder.record(tool: name, args: [
            "recipient": arguments.recipient,
            "recipientID": recipientID,
            "body": arguments.body,
            "time": arguments.time,
        ])

        guard matches.count == 1 else {
            return matches.isEmpty
                ? "No contact matches \(arguments.recipient)."
                : "More than one contact matches \(arguments.recipient)."
        }
        _ = try await ScheduleMessageIntent(
            recipient: matches[0], body: arguments.body, time: arguments.time
        ).perform()
        if live {
            await RealActions.shared.writeMessage(to: matches[0].name, body: arguments.body, time: arguments.time)
        }
        return "Message scheduled."
    }
}

struct CreateNoteTool: Tool {
    let name = "createNote"
    let description = "Save a note with a title and a body."
    let recorder: CallRecorder
    var live = false

    @Generable
    struct Arguments {
        @Guide(description: "Short title for the note")
        var title: String
        @Guide(description: "The note content")
        var body: String
    }

    func call(arguments: Arguments) async throws -> String {
        await recorder.record(tool: name, args: [
            "title": arguments.title,
            "body": arguments.body,
        ])
        _ = try await CreateNoteIntent(noteTitle: arguments.title, body: arguments.body).perform()
        if live {
            await RealActions.shared.addNote(title: arguments.title, body: arguments.body)
        }
        return "Note saved."
    }
}

struct SetReminderTool: Tool {
    let name = "setReminder"
    let description = "Remind the user about something at a given time."
    let recorder: CallRecorder
    var live = false

    @Generable
    struct Arguments {
        @Guide(description: "What to be reminded about")
        var what: String
        @Guide(description: "Time of the reminder, 24-hour clock, formatted HH:mm")
        var time: String
    }

    func call(arguments: Arguments) async throws -> String {
        await recorder.record(tool: name, args: [
            "what": arguments.what,
            "time": arguments.time,
        ])
        _ = try await SetReminderIntent(what: arguments.what, time: arguments.time).perform()
        if live {
            await RealActions.shared.addReminder(what: arguments.what, time: arguments.time)
        }
        return "Reminder set."
    }
}
