// The two extra pieces the fix ladder needs. Add this file to the app target.

import Foundation
import FoundationModels

/// Fix 2: a tool the model can pick when nothing should be saved or sent.
/// Calling it is NOT counted as acting.
struct ReplyOnlyTool: Tool {
    static let toolName = "replyOnly"
    let name = ReplyOnlyTool.toolName
    let description = "Use this when the user is not asking for a message to be scheduled, a note to be saved or a reminder to be set. Nothing is saved or sent."
    let recorder: CallRecorder

    @Generable
    struct Arguments {
        @Guide(description: "One short sentence saying why no action is needed")
        var reason: String
    }

    func call(arguments: Arguments) async throws -> String {
        await recorder.record(tool: name, args: ["reason": arguments.reason])
        return "No action taken. Reply to the user directly."
    }
}

/// Fix 3: a yes or no decision made before any tool is on the table.
@Generable
struct Gate {
    @Guide(description: "true only if the user is directly asking, right now, for a message to be scheduled, a note to be saved or a reminder to be set")
    var isRequest: Bool
}
