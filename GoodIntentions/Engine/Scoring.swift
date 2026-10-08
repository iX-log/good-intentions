// The marking rules. Unchanged since the first run of 5 October 2026: if
// these change, results before and after are not comparable.

import Foundation

enum Scoring {
    /// replyOnly saves and sends nothing, so it is not an action.
    static func actionCalls(_ calls: [RecordedCall]) -> [RecordedCall] {
        calls.filter { $0.tool != ReplyOnlyTool.toolName }
    }

    /// Tool is correct when exactly the expected tool was called once, or when
    /// none was expected and none was called. Arguments are compared after
    /// trimming and lowercasing.
    static func score(_ utterance: Utterance, _ calls: [RecordedCall]) -> (toolCorrect: Bool, argsCorrect: Bool?, wrongArgs: [String]) {
        guard let expectedTool = utterance.expectedTool else {
            return (calls.isEmpty, nil, [])
        }
        guard calls.count == 1, let call = calls.first, call.tool == expectedTool else {
            return (false, nil, [])
        }
        let expected = utterance.expectedArgs ?? [:]
        let wrong = expected.keys.sorted().filter { key in
            normalise(call.args[key] ?? "") != normalise(expected[key] ?? "")
        }
        return (true, wrong.isEmpty, wrong)
    }

    static func normalise(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
