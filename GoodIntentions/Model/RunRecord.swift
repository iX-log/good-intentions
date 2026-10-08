// What gets written to a log file. The field names are the log format, so
// they stay as they are: older logs must keep opening.

import Foundation

/// One sentence, said once, to a fresh secretary.
struct RunRecord: Codable, Sendable, Identifiable {
    let variant: String
    let repeatIndex: Int
    let utteranceID: String
    let category: String
    let text: String
    let expectedTool: String?
    let calls: [RecordedCall]            // every call, including replyOnly
    let acted: Bool?                     // missing in logs from before 5 Oct 2026 11:00
    let gate: Bool?                      // the yes or no decision, two-step only
    let reply: String?
    let error: String?
    let secondsTotal: Double
    let thermalState: Int
    let toolCorrect: Bool
    let argsCorrect: Bool?               // nil when the tool was wrong or none expected
    let wrongArgs: [String]

    var id: String { "\(variant)|\(utteranceID)|\(repeatIndex)" }

    /// Calls that save or send something. replyOnly is not one of them.
    var actionCalls: [RecordedCall] { Scoring.actionCalls(calls) }

    /// Did the secretary save or send anything? Computed from the calls, so
    /// it also works for logs written before the `acted` field existed.
    var didAct: Bool { !actionCalls.isEmpty }

    var expectsAction: Bool { expectedTool != nil }

    /// A run that errored before any action says nothing either way, so it is
    /// left out of the rates. A run that acted and then errored still counts.
    var isUsable: Bool { !(error != nil && !didAct) }

    /// The letters written in this run.
    var letters: [Letter] { calls.compactMap { Letter(call: $0) } }
}

/// One whole examination.
struct RunFile: Codable, Sendable {
    let startedAt: Date
    let finished: Bool?                  // false for a partial save or a cancelled run
    let device: String
    let os: String
    let lowPowerMode: Bool
    let availability: String
    let repeats: Int?
    let variants: [String: String]?      // name -> what that briefing changes
    let sentenceSet: String?             // missing in logs from before the sets existed: the original 43
    let records: [RunRecord]
}

extension RunFile {
    /// Which sentences this run used. Logs without the field used the original 43.
    var sentenceSetTitle: String {
        SentenceSet.named(sentenceSet ?? SentenceSet.original.name).title
    }

    /// The device as people call it, with the hardware identifier kept
    /// alongside, since the identifier is what the log actually recorded.
    var deviceName: String {
        let names = [
            "iPhone15,2": "iPhone 14 Pro",
            "iPhone15,3": "iPhone 14 Pro Max",
            "iPhone16,1": "iPhone 15 Pro",
            "iPhone16,2": "iPhone 15 Pro Max",
            "iPhone17,1": "iPhone 16 Pro",
            "iPhone17,2": "iPhone 16 Pro Max",
            "iPhone17,3": "iPhone 16",
            "iPhone17,4": "iPhone 16 Plus",
        ]
        guard let name = names[device] else { return device }
        return "\(name) (\(device))"
    }
}

/// A scheduleMessage call, read as the letter it would have sent.
struct Letter: Sendable {
    let addressee: String                // the name the secretary wrote
    let recipientID: String              // a contact id, or "none", or "ambiguous"
    let body: String
    let time: String

    init?(call: RecordedCall) {
        guard call.tool == "scheduleMessage" else { return nil }
        addressee = call.args["recipient"] ?? "?"
        recipientID = call.args["recipientID"] ?? "none"
        body = call.args["body"] ?? ""
        time = call.args["time"] ?? "?"
    }

    /// True when the name resolved to exactly one contact, so the letter
    /// would really have gone out.
    var wouldBeSent: Bool { recipientID != "none" && recipientID != "ambiguous" }

    /// The contact's full name when it resolved, otherwise what was written.
    var displayName: String {
        ContactEntity.all.first { $0.id == recipientID }?.name ?? addressee
    }
}
