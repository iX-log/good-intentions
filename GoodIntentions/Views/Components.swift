// The pieces the four screens share.

import SwiftUI

// MARK: What a call means on the desk

extension RecordedCall {
    var symbol: String {
        switch tool {
        case "scheduleMessage": return "envelope.fill"
        case "createNote": return "book.closed.fill"
        case "setReminder": return "bell.fill"
        case "replyOnly": return "tray.fill"
        default: return "questionmark.circle"
        }
    }

    var headline: String {
        switch tool {
        case "scheduleMessage":
            let to = args["recipient"] ?? "?"
            // The live screen leaves the time empty when none was said.
            guard let time = args["time"], !time.isEmpty else { return "Wrote a message to \(to)" }
            return "Wrote a message to \(to), to send at \(time)"
        case "createNote":
            return "Saved a note: \(args["title"] ?? "?")"
        case "setReminder":
            guard let time = args["time"], !time.isEmpty else { return "Set a reminder" }
            return "Set a reminder for \(time)"
        case "replyOnly":
            return "Chose to do nothing"
        default:
            return tool
        }
    }

    var detail: String {
        switch tool {
        case "scheduleMessage", "createNote": return args["body"] ?? ""
        case "setReminder": return args["what"] ?? ""
        case "replyOnly": return args["reason"] ?? ""
        default: return ""
        }
    }

    /// A note about the addressee, when the letter could not have gone out.
    var caveat: String? {
        guard tool == "scheduleMessage" else { return nil }
        switch args["recipientID"] {
        case "none": return "Nobody by that name in the address book, so it would not have been sent."
        case "ambiguous": return "More than one person by that name, so it would not have been sent."
        default: return nil
        }
    }

    var isAction: Bool { tool != ReplyOnlyTool.toolName }
}

// MARK: Small pieces

/// An ink stamp, slightly crooked.
struct Stamp: View {
    let text: String
    var color: Color = Theme.seal

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.heavy))
            .tracking(1.2)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(color, lineWidth: 1.5))
            .rotationEffect(.degrees(-6))
            .accessibilityLabel(text)
    }
}

/// A small uppercase label above a block.
struct Eyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.semibold))
            .tracking(1)
            .foregroundStyle(.secondary)
    }
}

/// A horizontal bar showing part of a whole.
struct RateBar: View {
    let part: Int
    let whole: Int
    var color: Color = Theme.seal

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.18))
                Capsule().fill(color)
                    .frame(width: whole > 0 ? proxy.size.width * CGFloat(part) / CGFloat(whole) : 0)
            }
        }
        .frame(height: 8)
        .accessibilityLabel("\(part) of \(whole)")
    }
}

/// One thing the secretary did.
struct CallLine: View {
    let call: RecordedCall

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: call.symbol)
                .foregroundStyle(call.isAction ? Theme.seal : Theme.laurel)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(call.headline).font(.subheadline.weight(.semibold))
                if !call.detail.isEmpty {
                    Text("\u{201C}\(call.detail)\u{201D}")
                        .font(.subheadline)
                        .fontDesign(.serif)
                        .italic()
                        .textSelection(.enabled)
                }
                if let caveat = call.caveat {
                    Text(caveat).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// What the secretary did after one sentence. The sentence itself is shown
/// by the caller, so this can sit under a heading or in a list of attempts.
struct DeedsView: View {
    let calls: [RecordedCall]
    let gate: Bool?
    let reply: String?
    let error: String?
    let seconds: Double

    private let shown = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if error != nil && calls.isEmpty && gate != false {
                // An error is not good behaviour. Say so, and nothing more.
                Label("No answer. The model stopped with an error.", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if gate == false {
                Label("Decided this was not a request, and did nothing.", systemImage: "hand.raised.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.laurel)
            } else if calls.isEmpty {
                Label("Did nothing.", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Theme.laurel)
            }

            ForEach(Array(calls.prefix(shown).enumerated()), id: \.offset) { _, call in
                CallLine(call: call)
            }
            if calls.count > shown {
                Text("Then did the same kind of thing \(calls.count - shown) more times.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let reply, !reply.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Eyebrow(text: "Then told you")
                    Text(reply).font(.subheadline)
                }
            }
            if error != nil {
                if !calls.isEmpty {
                    // With nothing done, the line above already says it failed.
                    Text("Then it stopped with an error.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(String(format: "%.1f seconds", seconds))
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(.tertiary)
        }
    }
}

/// A sentence, set the way it was said.
struct SaidView: View {
    let sentence: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Eyebrow(text: "You said")
            Text(sentence)
                .font(.title3)
                .fontDesign(.serif)
                .foregroundStyle(Theme.ink)
        }
    }
}

/// A letter on paper.
struct LetterCard: View {
    let letter: Letter
    var stamp: String? = nil
    var note: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("To \(letter.displayName)")
                        .font(.headline)
                        .fontDesign(.serif)
                    Text("To send at \(letter.time)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                if let stamp { Stamp(text: stamp) }
            }
            Text(letter.body.isEmpty ? "(no text)" : letter.body)
                .font(.body)
                .fontDesign(.serif)
                .foregroundStyle(Theme.ink)
            if !letter.wouldBeSent {
                Text("Nobody by that name in the address book, so this one would not have been sent.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.ink.opacity(0.12)))
    }
}

/// Shown when there is no run to read.
struct NoRunView: View {
    var body: some View {
        ContentUnavailableView(
            "Nothing to read yet",
            systemImage: "book.closed",
            description: Text("Run a test first. The results show up here.")
        )
    }
}
