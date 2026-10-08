// The first screen. You say what you want, the phone's AI suggests one thing,
// and you allow it or not. When it does not sound like a request, the app
// asks which kind of thing you meant instead of guessing.
//
// Behind every sentence the AI is first asked "is this a request?", the fix
// from the tests. A live demonstration: nothing here is written into the
// results. The problem itself is shown on the "Watch it go wrong" page.

import SwiftUI

/// Where one sentence stands.
private enum Stage {
    case thinking
    case suggested                       // waiting for Allow or Don't
    case unclear                         // did not sound like a request: ask which kind
    case done                            // allowed, or chosen, and carried out
    case refused                         // the person said no
    case nothing                         // the person wanted nothing done
    case failed                          // the AI stopped with an error
    case noDetails                       // a kind was chosen, but the AI produced nothing
}

private struct Turn: Identifiable {
    let id = UUID()
    let sentence: String
    var stage = Stage.thinking
    var calls: [RecordedCall] = []       // what the AI suggested
    var saved = false                    // really saved, with "Do it for real" on
}

struct DictateView: View {
    @State private var sentence = ""
    @State private var turns: [Turn] = []
    @State private var busy = false
    @State private var stampsLanded = 0
    @State private var showingSetup = false
    @State private var showingHistory = false
    @AppStorage("reallyDoIt") private var live = false
    @State private var dictation = Dictation()
    @FocusState private var fieldFocused: Bool

    private let examples = [
        "Remind me to call the dentist at 14:30",
        "Make a note that the garage code is 4471",
        "Don't text Josephine about the weekend",
    ]

    private var trimmed: String {
        sentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var ready: Bool { !busy && Secretary.isAvailable }

    var body: some View {
        NavigationStack {
            List {
                if !Secretary.isAvailable {
                    Section {
                        Label("The phone's AI is not available on this device.", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                    }
                }

                Section {
                    ForEach(examples, id: \.self) { example in
                        Button {
                            say(example)
                        } label: {
                            HStack(spacing: 12) {
                                Text(example)
                                    .font(.title3)
                                    .fontDesign(.serif)
                                    .foregroundStyle(Theme.ink)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Theme.seal)
                            }
                            .padding(.vertical, 4)
                        }
                    }

                    HStack(spacing: 12) {
                        // Tap the microphone and speak. It sends itself when you stop.
                        Button {
                            fieldFocused = false
                            Task { await dictation.toggle() }
                        } label: {
                            Image(systemName: dictation.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                                .font(.title)
                                .symbolEffect(.pulse, isActive: dictation.isRecording)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(dictation.isRecording ? "Stop listening" : "Dictate")

                        TextField(dictation.isRecording ? "Listening" : "Or say your own", text: $sentence, axis: .vertical)
                            .font(.title3)
                            .fontDesign(.serif)
                            .focused($fieldFocused)

                        if !dictation.isRecording && !trimmed.isEmpty {
                            Button {
                                say(trimmed)
                            } label: {
                                Image(systemName: "arrow.up.circle.fill")
                                    .font(.title2)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Say it")
                        }
                    }
                    if let problem = dictation.problem {
                        Text(problem)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    if turns.isEmpty {
                        // The pitch sits in the header, so it lines up with
                        // the sentences below it and is never clipped.
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Tell the phone what to do.")
                                .font(.title2.weight(.bold))
                                .fontDesign(.serif)
                                .foregroundStyle(Theme.ink)
                            Text("It suggests. You decide.")
                                .font(.title3)
                                .fontDesign(.serif)
                                .foregroundStyle(.secondary)
                            Text("Tap one")
                                .padding(.top, 18)
                        }
                        .textCase(nil)
                        .padding(.bottom, 4)
                    } else {
                        Text("Say another")
                    }
                }
                .disabled(!ready)

                // Only the latest sentence stays in view.
                if let latest = turns.first {
                    Section {
                        SaidView(sentence: latest.sentence)
                        answer(latest)
                    }
                }

                // Everything before it folds away under one row.
                if turns.count > 1 {
                    Section {
                        Button {
                            withAnimation { showingHistory.toggle() }
                        } label: {
                            HStack {
                                Label("History (\(turns.count - 1))", systemImage: "clock.arrow.circlepath")
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Image(systemName: showingHistory ? "chevron.up" : "chevron.down")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if showingHistory {
                        ForEach(turns.dropFirst()) { turn in
                            Section {
                                SaidView(sentence: turn.sentence)
                                answer(turn)
                            }
                        }
                    }
                }
            }
            .onDesk()
            .navigationTitle("Try it")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSetup = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Setup")
                }
                if !turns.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Clear") {
                            withAnimation { turns = [] }
                        }
                        .disabled(busy)
                    }
                }
            }
            .sheet(isPresented: $showingSetup) {
                setupSheet
            }
            .sensoryFeedback(.impact(weight: .heavy), trigger: stampsLanded)
            // Show the words as they are heard.
            .onChange(of: dictation.transcript) { _, heard in
                if !heard.isEmpty { sentence = heard }
            }
            // A pause of a second and a half means the sentence is over.
            .task(id: dictation.transcript) {
                guard dictation.isRecording, !dictation.transcript.isEmpty else { return }
                try? await Task.sleep(for: .seconds(1.5))
                if !Task.isCancelled && dictation.isRecording {
                    dictation.stop()
                }
            }
            // When listening ends with something heard, send it.
            .onChange(of: dictation.isRecording) { _, recording in
                if !recording && !dictation.transcript.isEmpty {
                    let heard = dictation.transcript
                    dictation.clear()
                    say(heard)
                }
            }
        }
    }

    // MARK: One answer

    @ViewBuilder
    private func answer(_ turn: Turn) -> some View {
        switch turn.stage {
        case .thinking:
            HStack(spacing: 8) {
                ProgressView()
                Text("Thinking").font(.subheadline).foregroundStyle(.secondary)
            }

        case .suggested:
            VStack(alignment: .leading, spacing: 12) {
                Eyebrow(text: "It suggests")
                ForEach(Array(turn.calls.enumerated()), id: \.offset) { _, call in
                    SuggestionLine(call: call)
                }
                HStack(spacing: 8) {
                    Button {
                        decide(true, turn.id)
                    } label: {
                        Text("Allow").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.laurel)
                    Button {
                        decide(false, turn.id)
                    } label: {
                        Text("Don't").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.seal)
                }
                .font(.headline)
            }
            .padding(.vertical, 4)

        case .unclear:
            VStack(alignment: .leading, spacing: 12) {
                Text("That did not sound like a request. Did you want one of these?")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                HStack(spacing: 8) {
                    choice("Message", "envelope.fill", "scheduleMessage", turn)
                    choice("Note", "book.closed.fill", "createNote", turn)
                    choice("Reminder", "bell.fill", "setReminder", turn)
                }
                Button("No, nothing") { settle(turn.id, .nothing) }
                    .font(.subheadline)
                    .buttonStyle(.borderless)
            }
            .padding(.vertical, 4)
            .disabled(busy)

        case .done:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Eyebrow(text: "You allowed it")
                    Spacer(minLength: 8)
                    Stamp(text: "Done", color: Theme.laurel)
                        .transition(.scale(scale: 2.4).combined(with: .opacity))
                }
                ForEach(Array(turn.calls.enumerated()), id: \.offset) { _, call in
                    CallLine(call: call)
                }
            }
            .padding(.vertical, 4)
            if turn.saved {
                NavigationLink {
                    SavedListView(kind: SavedKind.of(tool: turn.calls.first?.tool ?? ""))
                } label: {
                    Label("See what it really saved", systemImage: "tray.full.fill")
                }
            }

        case .refused:
            closed("You said no", "Nothing was done.")

        case .nothing:
            closed("Did nothing", "Nothing was done.")

        case .failed:
            Text("No answer. The phone's AI stopped with an error.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

        case .noDetails:
            Text("It could not work that out from what you said. Try saying it another way.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func closed(_ stamp: String, _ text: String) -> some View {
        HStack {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Stamp(text: stamp, color: Theme.ink)
                .transition(.scale(scale: 2.4).combined(with: .opacity))
        }
        .padding(.vertical, 4)
    }

    private func choice(_ title: String, _ icon: String, _ tool: String, _ turn: Turn) -> some View {
        Button {
            choose(tool, turn.id)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(Theme.seal)
    }

    // MARK: Doing

    private func update(_ id: UUID, _ change: (inout Turn) -> Void) {
        guard let row = turns.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) {
            change(&turns[row])
        }
    }

    private func settle(_ id: UUID, _ stage: Stage) {
        update(id) { $0.stage = stage }
        stampsLanded += 1
    }

    /// A new sentence. The AI is asked first whether it is a request; if so,
    /// what it would do becomes a suggestion. Nothing is done yet.
    private func say(_ text: String) {
        guard !text.isEmpty, ready else { return }
        fieldFocused = false
        sentence = ""
        let turn = Turn(sentence: text)
        withAnimation { turns.insert(turn, at: 0) }
        busy = true
        Task {
            let outcome = await Secretary.hear(text, variant: .twoStep)
            update(turn.id) {
                if outcome.acted {
                    $0.calls = timed(Array(outcome.actionCalls.prefix(1)), for: text)
                    $0.stage = .suggested
                } else if outcome.error != nil && outcome.gate != false {
                    $0.stage = .failed
                } else {
                    $0.stage = .unclear
                }
            }
            busy = false
        }
    }

    /// Leaves the time out when the person never said one. The AI has to
    /// give a time for every message and reminder, so it makes one up.
    private func timed(_ calls: [RecordedCall], for sentence: String) -> [RecordedCall] {
        guard !RealActions.mentionsTime(sentence) else { return calls }
        return calls.map { call in
            var args = call.args
            if args["time"] != nil { args["time"] = "" }
            return RecordedCall(tool: call.tool, args: args, secondsSinceStart: call.secondsSinceStart)
        }
    }

    /// The person's yes or no. On yes, the suggestion is carried out exactly
    /// as shown, for real when "Do it for real" is on.
    private func decide(_ yes: Bool, _ id: UUID) {
        guard let turn = turns.first(where: { $0.id == id }), turn.stage == .suggested else { return }
        guard yes else {
            settle(id, .refused)
            return
        }
        let calls = turn.calls
        let reallyDo = live
        update(id) {
            $0.stage = .done
            $0.saved = reallyDo
        }
        stampsLanded += 1
        if reallyDo {
            Task {
                for call in calls { await RealActions.shared.perform(call) }
            }
        }
    }

    /// The person said which kind of thing they meant. The AI fills in the
    /// details with only that one kind available, and it is done straight
    /// away: they have already said what they want.
    private func choose(_ tool: String, _ id: UUID) {
        guard !busy, let turn = turns.first(where: { $0.id == id }) else { return }
        let text = turn.sentence
        let reallyDo = live
        update(id) { $0.stage = .thinking }
        busy = true
        Task {
            let outcome = await Secretary.hear(text, variant: .youChose, only: tool)
            let calls = timed(Array(outcome.actionCalls.prefix(1)), for: text)
            if reallyDo {
                for call in calls { await RealActions.shared.perform(call) }
            }
            update(id) {
                if calls.isEmpty {
                    $0.stage = .noDetails
                } else {
                    $0.calls = calls
                    $0.stage = .done
                    $0.saved = reallyDo
                }
            }
            stampsLanded += 1
            busy = false
        }
    }

    // MARK: Setup

    private var setupSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Do it for real", isOn: $live)
                } footer: {
                    Text("Reminders go into the Reminders app, in a list called Good Intentions. Notes are kept in this app. Messages are written down and never sent.")
                }
            }
            .onDesk()
            .navigationTitle("Setup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showingSetup = false }
                }
            }
        }
        .presentationDetents([.medium])
        .tint(Theme.seal)
    }
}

/// What the AI wants to do, worded as a question.
private struct SuggestionLine: View {
    let call: RecordedCall

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: call.symbol)
                .foregroundStyle(Theme.seal)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(question).font(.subheadline.weight(.semibold))
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

    private var question: String {
        switch call.tool {
        case "scheduleMessage":
            let to = call.args["recipient"] ?? "?"
            guard let time = call.args["time"], !time.isEmpty else { return "Write a message to \(to)?" }
            return "Write a message to \(to), to send at \(time)?"
        case "createNote":
            return "Save a note: \(call.args["title"] ?? "?")?"
        case "setReminder":
            guard let time = call.args["time"], !time.isEmpty else { return "Set a reminder?" }
            return "Set a reminder for \(time)?"
        default:
            return call.tool
        }
    }
}
