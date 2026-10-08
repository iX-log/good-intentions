// The briefings: every way the secretary has been instructed so far.
//
// The instruction texts are the measured ones. They are generated from the
// committed log and the original runner, so they match byte for byte. Do not
// reword them: a reworded briefing is a new variant and needs a new name.

import Foundation

struct Variant: Sendable, Identifiable, Hashable {
    let name: String                     // the key used in the logs
    let title: String                    // what the screens call it
    let story: String                    // the same thing, in secretary terms
    let instructions: String?            // nil means the session gets no instructions
    var replyTool = false                // offer the "replyOnly" tool as well
    var gate = false                     // ask for a yes or no decision first, with no tools

    var id: String { name }
}

extension Variant {
    static let baselineInstructions = "You turn the user's request into exactly one tool call when a tool fits. If no tool fits the request, call no tool and say so in one sentence. Do not ask follow-up questions."

    static let strictInstructions = "Only call a tool when the user is directly asking you, right now, to do that thing. Statements, questions, things that already happened, and things the user tells you not to do are not requests. When in doubt, call no tool and reply in one sentence. When the user does ask, make exactly one tool call. Do not ask follow-up questions."

    static let gateInstructions = "Decide whether the user's sentence is a direct request to do one of these now: schedule a message, save a note, set a reminder. Statements, questions, things that already happened, and things the user says not to do are not requests."

    static let baseline = Variant(
        name: "baseline",
        title: "Acts straight away",
        story: "The normal way: told to act when asked, and otherwise do nothing.",
        instructions: baselineInstructions
    )

    static let strict = Variant(
        name: "strict",
        title: "Told to be careful",
        story: "Given a longer warning about what is not a request.",
        instructions: strictInstructions
    )

    static let noInstructions = Variant(
        name: "no-instructions",
        title: "Told nothing",
        story: "Given no instructions at all.",
        instructions: nil
    )

    static let replyTool = Variant(
        name: "reply-tool",
        title: "Given a way out",
        story: "Also offered an option that does nothing.",
        instructions: baselineInstructions,
        replyTool: true
    )

    static let twoStep = Variant(
        name: "two-step",
        title: "Asked first",
        story: "First asked: is this really a request? Only then allowed to act.",
        instructions: baselineInstructions,
        gate: true
    )

    /// Every briefing, in the order the screens and the examination use.
    /// Not a measured setup, and never in a log. The live demo uses it when
    /// the check said no and the person then says which kind they wanted.
    static let youChose = Variant(
        name: "you-chose",
        title: "After you chose",
        story: "The person said which kind of thing they wanted.",
        instructions: baselineInstructions
    )

    static let all: [Variant] = [baseline, strict, noInstructions, replyTool, twoStep]

    static func named(_ name: String) -> Variant? {
        all.first { $0.name == name }
    }

    /// The title for a name found in a log, including names this build does not know.
    static func title(for name: String) -> String {
        named(name)?.title ?? name
    }

    /// The longer explanation, for someone who has never seen this before.
    var explanation: String {
        switch name {
        case "baseline":
            return "The normal way an app would do it. The AI is given three things it can do (write a message, save a note, set a reminder) and one short instruction: do what is asked, otherwise do nothing."
        case "strict":
            return "The same, with a longer warning. The AI is told that statements, questions, things that already happened and \"don't\" are not requests."
        case "no-instructions":
            return "The AI gets the three things it can do and no instruction at all. This shows whether the instruction was the problem."
        case "reply-tool":
            return "The same as acting straight away, plus a fourth option that does nothing. The idea: maybe it acts because acting is all it was offered."
        case "two-step":
            return "Two steps. First the AI is asked one question, before it can do anything: is this really a request? Only if it answers yes is it allowed to act."
        default:
            return story
        }
    }

    /// What this briefing changes, as stored in the log file.
    var logDescription: String {
        var parts = ["instructions: \(instructions ?? "(none)")"]
        if replyTool { parts.append("extra tool: \(ReplyOnlyTool.toolName)") }
        if gate { parts.append("gate first, instructions: \(Variant.gateInstructions)") }
        return parts.joined(separator: " | ")
    }
}
