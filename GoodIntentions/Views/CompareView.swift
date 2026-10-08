// The problem and the fix, side by side. Say something that is not a request
// and see what the phone's AI does straight away; then, one tap to see it
// again with the check in front. Always pretend: nothing here is saved
// anywhere, and nothing is written into the results.

import SwiftUI

/// One answer to one sentence. `outcome` is nil while the model is thinking.
private struct Reply: Identifiable {
    let id = UUID()
    let variant: Variant
    var outcome: Outcome?
}

private struct DictationEntry: Identifiable {
    let id = UUID()
    let sentence: String
    let isRequest: Bool?                 // known for the examples, nil for your own sentence
    var replies: [Reply]
}

/// A ready-made sentence, with whether it really asks for something.
private struct Example: Identifiable {
    let text: String
    let isRequest: Bool
    var id: String { text }
}

struct CompareView: View {
    @State private var sentence = ""
    @State private var firstName = Variant.baseline.name
    @State private var secondName = Variant.twoStep.name
    @State private var askBothAtOnce = false
    @State private var entries: [DictationEntry] = []
    @State private var isListening = false
    @State private var stampsLanded = 0
    @State private var showingSetup = false
    @State private var showingExplainer = false
    @State private var dictation = Dictation()
    @FocusState private var fieldFocused: Bool

    private let examples = [
        Example(text: "Don't text Josephine about the weekend", isRequest: false),
        Example(text: "What is 18 times 12?", isRequest: false),
        Example(text: "Remind me to call the dentist at 14:30", isRequest: true),
    ]

    private var trimmed: String {
        sentence.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var ready: Bool { !isListening && Secretary.isAvailable }

    var body: some View {
            List {
                if !Secretary.isAvailable {
                    Section {
                        Label("The phone's AI is not available on this device.", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline)
                    }
                }

                Section {
                    ForEach(examples) { example in
                        Button {
                            dictate(example.text, isRequest: example.isRequest)
                        } label: {
                            HStack(spacing: 12) {
                                Text(example.text)
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
                                dictate(trimmed)
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
                    if entries.isEmpty {
                        // The pitch sits in the header, so it lines up with
                        // the sentences below it and is never clipped.
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Say something that is not a request.")
                                .font(.title2.weight(.bold))
                                .fontDesign(.serif)
                                .foregroundStyle(Theme.ink)
                            Text("See what the phone's AI does anyway.")
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

                ForEach(entries) { entry in
                    Section {
                        SaidView(sentence: entry.sentence)
                        ForEach(entry.replies) { reply in
                            ReplyRow(
                                reply: reply, label: label(for: reply.variant),
                                // What you picked yourself is not right or wrong.
                                isRequest: reply.variant.name == Variant.youChose.name ? nil : entry.isRequest
                            )
                        }
                        if needsAsking(entry) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("It did nothing. Did you want one of these?")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Theme.ink)
                                HStack(spacing: 8) {
                                    choice("Message", "envelope.fill", "scheduleMessage", entry)
                                    choice("Note", "book.closed.fill", "createNote", entry)
                                    choice("Reminder", "bell.fill", "setReminder", entry)
                                }
                            }
                            .padding(.vertical, 4)
                            .disabled(!ready)
                        }
                        if let fix = pendingFix(for: entry) {
                            Button {
                                ask(fix, about: entry.id)
                            } label: {
                                VStack(spacing: 2) {
                                    Text("Try again, but ask first")
                                        .font(.headline)
                                    Text("\u{201C}Is this a request?\u{201D}")
                                        .font(.subheadline)
                                        .fontDesign(.serif)
                                        .italic()
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .foregroundStyle(.white)
                            .listRowBackground(Theme.laurel.opacity(ready ? 1 : 0.4))
                            .disabled(!ready)
                        }
                    }
                }
            }
            .onDesk()
            .navigationTitle("Watch it go wrong")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSetup = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityLabel("Setup")
                    .disabled(isListening)
                }
                if !entries.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Clear") {
                            withAnimation { entries = [] }
                        }
                        .disabled(isListening)
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
                    dictate(heard)
                }
            }
    }

    // MARK: Words

    /// How a setup is named on this screen, for someone seeing it cold.
    private func label(for variant: Variant) -> String {
        variant.title
    }

    /// The fix still to try for this sentence, if it has not been tried yet.
    private func pendingFix(for entry: DictationEntry) -> Variant? {
        guard let fix = Variant.named(secondName),
              entry.replies.allSatisfy({ $0.outcome != nil }),
              !entry.replies.contains(where: { $0.variant.name == fix.name })
        else { return nil }
        return fix
    }

    /// The check said "not a request" and did nothing. That is where a real
    /// request can get lost, so the app asks instead of staying silent.
    private func needsAsking(_ entry: DictationEntry) -> Bool {
        // For an example known not to be a request, doing nothing was right.
        entry.isRequest != false
            && entry.replies.allSatisfy({ $0.outcome != nil })
            && entry.replies.contains(where: { $0.outcome?.gate == false })
            && !entry.replies.contains(where: { $0.variant.name == Variant.youChose.name })
    }

    private func choice(_ title: String, _ icon: String, _ tool: String, _ entry: DictationEntry) -> some View {
        Button {
            ask(Variant.youChose, about: entry.id, only: tool)
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

    // MARK: Asking

    private func dictate(_ text: String, isRequest: Bool? = nil) {
        guard !text.isEmpty, ready else { return }
        let first = Variant.named(firstName) ?? Variant.baseline
        fieldFocused = false
        sentence = ""
        let entry = DictationEntry(sentence: text, isRequest: isRequest, replies: [])
        withAnimation { entries.insert(entry, at: 0) }
        ask(first, about: entry.id, thenAlso: askBothAtOnce ? Variant.named(secondName) : nil)
    }

    /// Puts the entry's sentence to one setup, and optionally to a second
    /// straight after. One at a time, so each stamp lands on its own.
    private func ask(_ variant: Variant, about entryID: UUID, thenAlso next: Variant? = nil, only: String? = nil) {
        guard !isListening, let row = entries.firstIndex(where: { $0.id == entryID }) else { return }
        let text = entries[row].sentence
        var queue = [variant]
        if let next, next.name != variant.name { queue.append(next) }
        isListening = true

        Task {
            for item in queue {
                let reply = Reply(variant: item, outcome: nil)
                if let row = entries.firstIndex(where: { $0.id == entryID }) {
                    withAnimation { entries[row].replies.append(reply) }
                }
                // Always pretend on this page: nothing is ever saved.
                let outcome = await Secretary.hear(text, variant: item, only: only)
                if let row = entries.firstIndex(where: { $0.id == entryID }),
                   let slot = entries[row].replies.firstIndex(where: { $0.id == reply.id }) {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.5)) {
                        entries[row].replies[slot].outcome = outcome
                    }
                    stampsLanded += 1
                }
            }
            isListening = false
        }
    }

    // MARK: Setup

    /// The settings most people never need, kept off the first screen.
    private var setupSheet: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("First answer", selection: $firstName) {
                        ForEach(Variant.all) { variant in
                            Text(variant.title).tag(variant.name)
                        }
                    }
                    Picker("The fix to try", selection: $secondName) {
                        ForEach(Variant.all) { variant in
                            Text(variant.title).tag(variant.name)
                        }
                    }
                    Toggle("Show both answers straight away", isOn: $askBothAtOnce)
                }
                Section {
                    Button("What do these mean?") { showingExplainer = true }
                }
            }
            .sheet(isPresented: $showingExplainer) {
                ExplainerView(names: Variant.all.map(\.name))
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
        .presentationDetents([.medium, .large])
        .tint(Theme.seal)
    }
}

/// One answer: a stamp and the one thing that matters. The rest is a tap away.
private struct ReplyRow: View {
    let reply: Reply
    let label: String
    let isRequest: Bool?                 // nil when nobody knows the right answer
    @State private var showingDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center) {
                Eyebrow(text: label)
                Spacer(minLength: 8)
                if let outcome = reply.outcome {
                    Stamp(text: verdict(outcome), color: tint(outcome))
                        .transition(.scale(scale: 2.4).combined(with: .opacity))
                }
            }

            if let outcome = reply.outcome {
                if showingDetails {
                    DeedsView(
                        calls: outcome.calls, gate: outcome.gate,
                        reply: outcome.reply, error: outcome.error,
                        seconds: outcome.seconds
                    )
                } else {
                    summary(outcome)
                }
                Button(showingDetails ? "Less" : "Details") {
                    withAnimation { showingDetails.toggle() }
                }
                .font(.caption)
                .buttonStyle(.borderless)
            } else {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Thinking").font(.subheadline).foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// The single most important thing that happened.
    @ViewBuilder
    private func summary(_ outcome: Outcome) -> some View {
        if let action = outcome.actionCalls.first {
            CallLine(call: action)
        } else if outcome.error != nil && outcome.gate != false {
            Text("No answer. The model stopped with an error.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            Text(isRequest == true ? "Did nothing, though this was a real request." : "Did nothing.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint(outcome))
        }
    }

    private func failed(_ outcome: Outcome) -> Bool {
        outcome.error != nil && !outcome.acted && outcome.gate != false
    }

    /// Green for the right move, red for the wrong one. For a sentence of
    /// your own nobody knows which is right, so the stamp stays in plain ink.
    private func tint(_ outcome: Outcome) -> Color {
        if failed(outcome) { return .secondary }
        guard let isRequest else { return Theme.ink }
        return outcome.acted == isRequest ? Theme.laurel : Theme.seal
    }

    /// What the stamp says: what happened. The colour says whether it was right.
    private func verdict(_ outcome: Outcome) -> String {
        if failed(outcome) { return "No answer" }
        guard outcome.acted else { return isRequest == true ? "Ignored it" : "Did nothing" }
        let tools = Set(outcome.actionCalls.map(\.tool))
        if tools.contains("scheduleMessage") { return "Wrote a message" }
        if tools.contains("setReminder") { return "Set a reminder" }
        return "Saved a note"
    }
}
