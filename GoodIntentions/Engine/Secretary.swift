// The secretary: Apple's on-device model, sitting at a desk with three things
// on it. `hear` says one sentence to a fresh secretary and reports what was
// done. The measured tests and the Try it tab both go through here, so the
// demo asks the model exactly what the tests asked it.

import Foundation
import FoundationModels

/// What happened after one sentence.
struct Outcome: Sendable {
    let calls: [RecordedCall]
    let gate: Bool?                      // the yes or no decision, two-step only
    let reply: String?
    let error: String?
    let seconds: Double

    var actionCalls: [RecordedCall] { Scoring.actionCalls(calls) }
    var acted: Bool { !actionCalls.isEmpty }
}

enum Secretary {
    /// What the system says about the model, as text for logs and screens.
    static var availabilityText: String {
        String(describing: SystemLanguageModel.default.availability)
    }

    static var isAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    /// Says one sentence to a fresh secretary under the given briefing.
    /// Fresh sessions every time, so no sentence sees an earlier one.
    ///
    /// `live` makes the actions real, and is only ever set by the live demo.
    /// What the AI is shown and told is identical either way.
    ///
    /// `only` leaves a single tool on the desk and skips the yes or no step.
    /// The live demo uses it when the person has said which kind of thing
    /// they wanted. The measured tests never set it.
    static func hear(_ sentence: String, variant: Variant, live: Bool = false, only: String? = nil) async -> Outcome {
        let recorder = CallRecorder()
        var tools: [any Tool] = [
            ScheduleMessageTool(recorder: recorder, live: live),
            CreateNoteTool(recorder: recorder, live: live),
            SetReminderTool(recorder: recorder, live: live),
        ]
        if variant.replyTool { tools.append(ReplyOnlyTool(recorder: recorder)) }
        if let only { tools = tools.filter { $0.name == only } }

        var reply: String?
        var errorText: String?
        var gate: Bool?
        await recorder.restart()
        let clock = ContinuousClock()
        let begin = clock.now
        do {
            if variant.gate && only == nil {
                // Step one: decide, with nothing on the desk.
                let gateSession = LanguageModelSession(instructions: Variant.gateInstructions)
                gate = try await gateSession.respond(to: sentence, generating: Gate.self).content.isRequest
            }
            if gate != false {
                let session: LanguageModelSession
                if let text = variant.instructions {
                    session = LanguageModelSession(tools: tools, instructions: text)
                } else {
                    session = LanguageModelSession(tools: tools)
                }
                reply = try await session.respond(to: sentence).content
            }
        } catch {
            errorText = String(describing: error)
        }
        let elapsed = clock.now - begin
        let seconds = Double(elapsed.components.seconds)
            + Double(elapsed.components.attoseconds) / 1e18

        return Outcome(
            calls: await recorder.calls,
            gate: gate, reply: reply, error: errorText, seconds: seconds
        )
    }
}
