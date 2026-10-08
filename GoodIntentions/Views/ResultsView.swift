// The evidence, as tiles. Each tile shows one figure and opens the screen
// behind it: the charts, the messages nobody asked for, what a fix costs,
// every sentence, the test's details, and running a new test.

import SwiftUI

struct ResultsView: View {
    @Environment(LogStore.self) private var store
    @State private var showingExplainer = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let file = store.current {
                        // Which test this is, and the way to another one.
                        NavigationLink {
                            ExaminationView()
                        } label: {
                            (Text("Showing: \(showing(file)). ")
                                .foregroundStyle(.secondary)
                             + Text("Change")
                                .foregroundStyle(Theme.seal)
                                .fontWeight(.semibold))
                                .font(.footnote)
                                .multilineTextAlignment(.leading)
                                .padding(.horizontal, 4)
                        }
                        .buttonStyle(.plain)

                        tiles(RunAnalysis(file: file))
                    } else {
                        NoRunView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    }
                    NavigationLink {
                        CompareView()
                    } label: {
                        Tile(
                            symbol: "eye.fill",
                            label: "Watch it go wrong",
                            caption: "The AI acting straight away, then asked first.",
                            color: Theme.ink,
                            compact: true
                        )
                    }
                    .buttonStyle(.plain)
                    NavigationLink {
                        ExaminationView()
                    } label: {
                        Tile(
                            symbol: "play.fill",
                            label: "Run a test",
                            caption: "Or open a saved one.",
                            color: Theme.ink,
                            compact: true
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.desk.ignoresSafeArea())
            .navigationTitle("Results")
            .sheet(isPresented: $showingExplainer) {
                ExplainerView(names: store.current.map { RunAnalysis(file: $0).variantNames } ?? [])
            }
        }
    }

    @ViewBuilder
    private func tiles(_ analysis: RunAnalysis) -> some View {
        // The usual setup leads, if this test has it.
        let lead = analysis.variantNames.contains(Variant.baseline.name)
            ? Variant.baseline.name
            : (analysis.variantNames.first ?? "")
        let leadStats = analysis.stats(for: lead)
        // "The fix" is whichever setup acted least when it should not have.
        let fix = analysis.stats.min { rate($0) < rate($1) }
        let sentenceCount = Set(analysis.file.records.map(\.utteranceID)).count

        // The headline tile carries the chart itself.
        NavigationLink {
            ChartsView(analysis: analysis)
        } label: {
            VStack(alignment: .leading, spacing: 14) {
                Text("How often it did something nobody asked for")
                    .font(.headline)
                    .fontDesign(.serif)
                    .foregroundStyle(Theme.ink)
                    .padding(.trailing, 36)          // room for the info button
                ForEach(analysis.stats) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(Variant.title(for: item.variant))
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                            Spacer(minLength: 8)
                            Text("\(RunAnalysis.percent(item.quietActed, item.quietRuns))%")
                                .font(.subheadline.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(Theme.seal)
                        }
                        RateBar(part: item.quietActed, whole: item.quietRuns, color: Theme.seal)
                    }
                }
                HStack(spacing: 4) {
                    Text("See both charts")
                    Image(systemName: "chevron.right")
                }
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.seal)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        // The info button sits on top of the tile, so it gets its own tap.
        .overlay(alignment: .topTrailing) {
            Button {
                showingExplainer = true
            } label: {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .padding(14)
            }
            .accessibilityLabel("What do these mean?")
        }

        LazyVGrid(columns: columns, spacing: 12) {
            NavigationLink {
                MessagesView(analysis: analysis, startVariant: lead)
            } label: {
                Tile(
                    number: "\(leadStats?.lettersSent ?? 0)",
                    label: "Messages nobody asked for",
                    caption: "Written to real people in the address book.",
                    color: Theme.seal
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                CostView(analysis: analysis)
            } label: {
                Tile(
                    number: "\(fix?.realSilent ?? 0)",
                    label: "Real requests ignored",
                    caption: "The price of the best fix: \(Variant.title(for: fix?.variant ?? lead).lowercased()).",
                    color: Theme.seal
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                SentencesView(analysis: analysis)
            } label: {
                Tile(
                    number: "\(sentenceCount)",
                    label: "Sentences",
                    caption: "See each one, and what happened every time.",
                    color: Theme.ink
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                AboutTestView(analysis: analysis)
            } label: {
                Tile(
                    number: "\(analysis.file.records.count)",
                    label: "Tries in this test",
                    caption: "Which phone, and how it was set up.",
                    color: Theme.ink
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func showing(_ file: RunFile) -> String {
        let device = file.deviceName.components(separatedBy: " (").first ?? file.deviceName
        guard let url = store.currentURL else { return "\(file.sentenceSetTitle), \(device)" }
        return "\(store.title(for: url)), \(device)"
    }

    private func rate(_ item: VariantStats) -> Double {
        item.quietRuns > 0 ? Double(item.quietActed) / Double(item.quietRuns) : 1
    }
}

/// One tile on the Results screen: a big figure or symbol, and what it means.
private struct Tile: View {
    var number: String? = nil
    var symbol: String? = nil
    let label: String
    let caption: String
    let color: Color
    var compact = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                if let number {
                    Text(number)
                        .font(.system(size: 44, weight: .bold, design: .serif))
                        .monospacedDigit()
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .foregroundStyle(color)
                }
                if let symbol {
                    Image(systemName: symbol)
                        .font(.title2)
                        .foregroundStyle(Theme.seal)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text(caption)
                .font(.caption)
                .foregroundStyle(.secondary)
            if !compact { Spacer(minLength: 0) }
        }
        .multilineTextAlignment(.leading)
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: compact ? nil : 170, alignment: .topLeading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: What the names mean

/// A short, plain explanation of each way the AI was prepared.
struct ExplainerView: View {
    let names: [String]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("The sentence is the same every time. What changes is how the AI was prepared before it heard it.")
                        .font(.subheadline)
                    Text("The percentage is how often it then did something nobody asked for. 100% means every single time.")
                        .font(.subheadline)
                }
                ForEach(names, id: \.self) { name in
                    Section {
                        Text(Variant.named(name)?.explanation ?? "")
                            .font(.subheadline)
                    } header: {
                        Text(Variant.title(for: name))
                    }
                }
            }
            .onDesk()
            .navigationTitle("What these mean")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .tint(Theme.seal)
    }
}

// MARK: The two charts

/// Both charts in full, with the picture and summary to share.
struct ChartsView: View {
    let analysis: RunAnalysis
    @State private var chartURL: URL?
    @State private var showingExplainer = false

    var body: some View {
        List {
            Section {
                ForEach(analysis.stats) { item in
                    LadderRow(
                        title: Variant.title(for: item.variant),
                        caption: nil,
                        part: item.quietActed, whole: item.quietRuns,
                        color: Theme.seal
                    )
                }
            } header: {
                Text("How often it did something nobody asked for")
            } footer: {
                Text("Shorter is better.")
            }

            Section {
                ForEach(analysis.stats) { item in
                    LadderRow(
                        title: Variant.title(for: item.variant),
                        caption: item.realSilent == 0 ? nil : "Ignored a real request \(item.realSilent) times.",
                        part: item.realRight, whole: item.realRuns,
                        color: Theme.laurel
                    )
                }
            } header: {
                Text("How often it did what you really asked")
            } footer: {
                Text("Longer is better.")
            }

            Section {
                if let chartURL {
                    ShareLink(item: chartURL) {
                        Label("Share the chart as a picture", systemImage: "photo")
                    }
                } else {
                    Button {
                        chartURL = ChartPicture.render(analysis)
                    } label: {
                        Label("Make a picture of the first chart", systemImage: "photo")
                    }
                }
            }
        }
        .onDesk()
        .navigationTitle("How often")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingExplainer = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("What do these mean?")
            }
        }
        .sheet(isPresented: $showingExplainer) {
            ExplainerView(names: analysis.variantNames)
        }
    }
}

// MARK: What a fix costs

/// The real requests each setup ignored.
struct CostView: View {
    let analysis: RunAnalysis

    var body: some View {
        List {
            Section {
                ForEach(analysis.stats) { item in
                    LadderRow(
                        title: Variant.title(for: item.variant),
                        caption: item.realSilent == 0 ? nil : "Ignored a real request \(item.realSilent) times.",
                        part: item.realRight, whole: item.realRuns,
                        color: Theme.laurel
                    )
                }
            } header: {
                Text("How often it did what you really asked")
            } footer: {
                Text("Longer is better. Below: the real requests that got ignored.")
            }

            ForEach(analysis.variantNames, id: \.self) { name in
                let ignored = analysis.sentences(variant: name, expectingAction: true)
                    .filter { $0.ignoredCount > 0 }
                    .sorted { $0.ignoredCount > $1.ignoredCount }
                if !ignored.isEmpty {
                    Section {
                        ForEach(ignored) { sentence in
                            NavigationLink {
                                SentenceView(analysis: analysis, utteranceID: sentence.utteranceID, startVariant: name)
                            } label: {
                                CountRow(count: "\(sentence.ignoredCount)/\(sentence.usable.count)", text: sentence.text, color: Theme.seal)
                            }
                        }
                    } header: {
                        Text("\(Variant.title(for: name)): it ignored these")
                    }
                }
            }
        }
        .onDesk()
        .navigationTitle("What a fix costs")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: About this test

struct AboutTestView: View {
    let analysis: RunAnalysis
    @Environment(LogStore.self) private var store

    var body: some View {
        List {
            Section("This test") {
                ConditionsView(file: analysis.file)
            }
            Section {
                ShareLink(item: analysis.textSummary) {
                    Label("Share a summary", systemImage: "square.and.arrow.up")
                }
                if let url = store.currentURL {
                    ShareLink(item: url) {
                        Label("Share the raw data", systemImage: "doc")
                    }
                }
            }
        }
        .onDesk()
        .navigationTitle("This test")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: All the messages

/// Every message written after a sentence that was not a request.
struct MessagesView: View {
    let analysis: RunAnalysis
    let startVariant: String
    @State private var picked: String?

    private static let everySetup = "*"

    var body: some View {
        let chosen = picked ?? startVariant
        let variant: String? = chosen == MessagesView.everySetup ? nil : chosen
        let groups = analysis.letterGroups(variant: variant)

        List {
            if analysis.variantNames.count > 1 {
                Section {
                    Picker("The AI", selection: Binding(get: { chosen }, set: { picked = $0 })) {
                        ForEach(analysis.variantNames, id: \.self) { name in
                            Text(Variant.title(for: name)).tag(name)
                        }
                        Text("All of them").tag(MessagesView.everySetup)
                    }
                } header: {
                    Text("None of these sentences asked for a message. The phone's AI wrote one anyway.")
                        .textCase(nil)
                }
            }

            if groups.isEmpty {
                Section {
                    Label("Nothing here. Not one message was written that nobody asked for.", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(Theme.laurel)
                }
            }

            ForEach(groups) { group in
                Section {
                    NavigationLink {
                        LetterGroupView(group: group)
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            SaidView(sentence: group.sentence)
                            if let letter = group.showpiece {
                                LetterCard(letter: letter, stamp: "Not asked for")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(group.parts) { part in
                            Text(group.parts.count > 1
                                ? "\(Variant.title(for: part.variant)): \(part.letters.count) times out of \(part.usableRuns)."
                                : "It did this \(part.letters.count) times out of \(part.usableRuns).")
                        }
                    }
                }
            }
        }
        .onDesk()
        .navigationTitle("Not asked for")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Every message one sentence produced, identical ones counted together.
struct LetterGroupView: View {
    let group: LetterGroup

    var body: some View {
        List {
            Section {
                SaidView(sentence: group.sentence)
            } footer: {
                Text("It should have done nothing.")
            }
            ForEach(group.parts) { part in
                Section {
                    ForEach(part.distinct) { item in
                        LetterCard(
                            letter: item.letter,
                            note: item.count == 1 ? "Written this way once." : "Written this way \(item.count) times."
                        )
                        .listRowSeparator(.hidden)
                    }
                } header: {
                    Text(Variant.title(for: part.variant))
                } footer: {
                    Text("It wrote a message \(part.letters.count) times out of \(part.usableRuns).")
                }
            }
        }
        .onDesk()
        .navigationTitle("What it wrote")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Every sentence

/// One setup up close: its counts, what it ignored, and every sentence.
struct SentencesView: View {
    let analysis: RunAnalysis
    @State private var variantName = ""
    @State private var showingExplainer = false

    var body: some View {
        let chosen = analysis.variantNames.contains(variantName) ? variantName : (analysis.variantNames.first ?? "")
        let quiet = analysis.sentences(variant: chosen, expectingAction: false)
        let real = analysis.sentences(variant: chosen, expectingAction: true)
        let categories = analysis.stats(for: chosen)?.categories ?? []
        let ignored = real.filter { $0.ignoredCount > 0 }.sorted { $0.ignoredCount > $1.ignoredCount }

        List {
            Section {
                Picker("The AI", selection: Binding(get: { chosen }, set: { variantName = $0 })) {
                    ForEach(analysis.variantNames, id: \.self) { name in
                        Text(Variant.title(for: name)).tag(name)
                    }
                }
                if let item = analysis.stats(for: chosen) {
                  DisclosureGroup("More numbers") {
                    DetailRow(label: "Messages nobody asked for", value: "\(item.lettersSent)")
                    DetailRow(label: "Got the details right", value: RunAnalysis.rate(item.paramsRight, item.paramsScored))
                    if let quietYes = item.gateYesQuiet, let realYes = item.gateYesReal {
                        DetailRow(label: "The first question said yes", value: "\(quietYes) wrongly, \(realYes) rightly")
                    }
                    DetailRow(label: "Tries that failed", value: "\(item.errors) of \(item.total)")
                    if let median = item.medianSeconds {
                        DetailRow(label: "Typical time per sentence", value: String(format: "%.2f s", median))
                    }
                  }
                }
            }

            Section {
                if ignored.isEmpty {
                    Label("It never ignored a real request.", systemImage: "checkmark.seal.fill")
                        .font(.subheadline)
                        .foregroundStyle(Theme.laurel)
                }
                ForEach(ignored) { sentence in
                    NavigationLink {
                        SentenceView(analysis: analysis, utteranceID: sentence.utteranceID, startVariant: chosen)
                    } label: {
                        CountRow(count: "\(sentence.ignoredCount)/\(sentence.usable.count)", text: sentence.text, color: Theme.seal)
                    }
                }
            } header: {
                Text("Real requests it ignored")
            } footer: {
                Text("You asked, and nothing happened.")
            }

            ForEach(categories) { category in
                Section {
                    ForEach(quiet.filter { $0.category == category.category }) { sentence in
                        NavigationLink {
                            SentenceView(analysis: analysis, utteranceID: sentence.utteranceID, startVariant: chosen)
                        } label: {
                            SentenceRow(sentence: sentence)
                        }
                    }
                } header: {
                    Text(SentenceKind.title(for: category.category))
                } footer: {
                    Text("Did something anyway: \(RunAnalysis.rate(category.acted, category.runs)).")
                }
            }

            if !real.isEmpty {
                Section {
                    ForEach(real) { sentence in
                        NavigationLink {
                            SentenceView(analysis: analysis, utteranceID: sentence.utteranceID, startVariant: chosen)
                        } label: {
                            SentenceRow(sentence: sentence)
                        }
                    }
                } header: {
                    Text(SentenceKind.title(for: "action"))
                } footer: {
                    Text("The number is how often it got it right.")
                }
            }
        }
        .onDesk()
        .navigationTitle("Every sentence")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingExplainer = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .accessibilityLabel("What do these mean?")
            }
        }
        .sheet(isPresented: $showingExplainer) {
            ExplainerView(names: analysis.variantNames)
        }
    }
}

/// One sentence under every setup, then each attempt.
struct SentenceView: View {
    /// The log's field names, in everyday words.
    private static func plain(_ field: String) -> String {
        switch field {
        case "body": return "the wording"
        case "title": return "the title"
        case "time": return "the time"
        case "recipientID": return "the person"
        case "what": return "what to remember"
        default: return field
        }
    }

    let analysis: RunAnalysis
    let utteranceID: String
    let startVariant: String
    @State private var picked: String?

    var body: some View {
        let across = analysis.sentenceAcrossVariants(utteranceID)
        let chosenName = picked ?? startVariant
        let chosen = across.first { $0.variant == chosenName } ?? across.first

        List {
            if let first = across.first {
                Section {
                    SaidView(sentence: first.text)
                } footer: {
                    Text(first.expectsAction
                        ? "A real request. It should do exactly one thing."
                        : "This is not a request. It should do nothing.")
                }

                Section(first.expectsAction ? "How often it got this right" : "How often it did something anyway") {
                    ForEach(across) { item in
                        LadderRow(
                            title: Variant.title(for: item.variant), caption: nil,
                            part: item.headlineCount, whole: item.usable.count,
                            color: first.expectsAction ? Theme.laurel : Theme.seal
                        )
                    }
                }
            }

            if across.count > 1 {
                Section {
                    Picker("Show each try for", selection: Binding(get: { chosenName }, set: { picked = $0 })) {
                        ForEach(across) { item in
                            Text(Variant.title(for: item.variant)).tag(item.variant)
                        }
                    }
                }
            }

            if let chosen {
                ForEach(chosen.runs) { run in
                    Section("Try \(run.repeatIndex)") {
                        DeedsView(
                            calls: run.calls, gate: run.gate, reply: run.reply,
                            error: run.error, seconds: run.secondsTotal
                        )
                        if !run.wrongArgs.isEmpty {
                            Text("Got wrong: \(run.wrongArgs.map(Self.plain).joined(separator: ", ")).")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .onDesk()
        .navigationTitle("Every try")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: Rows

private struct ConditionsView: View {
    let file: RunFile

    var body: some View {
        DetailRow(label: "Sentences", value: file.sentenceSetTitle)
        DetailRow(label: "Device", value: file.deviceName)
        DetailRow(label: "System", value: file.os)
        DetailRow(label: "Times each sentence was said", value: file.repeats.map { "\($0)" } ?? "not recorded")
        DetailRow(label: "Low Power Mode", value: file.lowPowerMode ? "on" : "off")
        if file.finished == false {
            Label("This test was stopped early or is still going.", systemImage: "hourglass")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
            Spacer(minLength: 12)
            Text(value)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }
}

private struct LadderRow: View {
    let title: String
    let caption: String?
    let part: Int
    let whole: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer(minLength: 12)
                Text("\(part) of \(whole)")
                    .font(.subheadline)
                    .monospacedDigit()
                Text("\(RunAnalysis.percent(part, whole))%")
                    .font(.subheadline.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(color)
                    .frame(minWidth: 44, alignment: .trailing)
            }
            RateBar(part: part, whole: whole, color: color)
            if let caption {
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct CountRow: View {
    let count: String
    let text: String
    let color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(count)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(color)
                .frame(minWidth: 44, alignment: .leading)
            Text(text)
                .font(.subheadline)
                .fontDesign(.serif)
        }
    }
}

private struct SentenceRow: View {
    let sentence: SentenceStat

    var body: some View {
        CountRow(
            count: "\(sentence.headlineCount)/\(sentence.usable.count)",
            text: sentence.text,
            color: tint
        )
    }

    /// Red when the count is bad news, green when it is good news.
    private var tint: Color {
        let count = sentence.headlineCount
        if sentence.expectsAction {
            return count == sentence.usable.count ? Theme.laurel : Theme.seal
        }
        return count == 0 ? Theme.laurel : Theme.seal
    }
}

// MARK: The chart as a picture

/// The first chart, laid out for a slide: 1080 by 1350, always on light paper.
struct ChartPicture: View {
    let analysis: RunAnalysis

    private let barWidth: CGFloat = 952

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("It did something nobody asked for")
                .font(.system(size: 58, weight: .bold, design: .serif))
            Text("How often the phone's own AI wrote a message, saved a note or set a reminder after a sentence that was not a request.")
                .font(.system(size: 28))
                .opacity(0.7)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 44) {
                ForEach(analysis.stats) { item in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(Variant.title(for: item.variant))
                                .font(.system(size: 36, weight: .semibold))
                            Spacer(minLength: 16)
                            Text("\(item.quietActed) of \(item.quietRuns)")
                                .font(.system(size: 30))
                                .monospacedDigit()
                                .opacity(0.7)
                            Text("\(RunAnalysis.percent(item.quietActed, item.quietRuns))%")
                                .font(.system(size: 44, weight: .bold, design: .serif))
                                .monospacedDigit()
                                .foregroundStyle(Self.wax)
                                .frame(minWidth: 130, alignment: .trailing)
                        }
                        ZStack(alignment: .leading) {
                            Capsule().fill(Self.ink.opacity(0.12))
                                .frame(width: barWidth, height: 24)
                            Capsule().fill(Self.wax)
                                .frame(width: fill(item), height: 24)
                        }
                        if let story = Variant.named(item.variant)?.story {
                            Text(story)
                                .font(.system(size: 24))
                                .opacity(0.7)
                        }
                    }
                }
            }
            .padding(.top, 56)

            Spacer(minLength: 0)

            Text(caption)
                .font(.system(size: 24))
                .opacity(0.7)
            Text("Good Intentions")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(Self.wax)
                .padding(.top, 10)
        }
        .foregroundStyle(Self.ink)
        .padding(64)
        .frame(width: 1080, height: 1350, alignment: .topLeading)
        .background(Self.sheet)
    }

    // Fixed colours: a picture for a slide should not change with dark mode.
    private static let sheet = Color(red: 0.98, green: 0.96, blue: 0.91)
    private static let ink = Color(red: 0.14, green: 0.13, blue: 0.17)
    private static let wax = Color(red: 0.66, green: 0.13, blue: 0.15)

    private var caption: String {
        let file = analysis.file
        let attempts = file.repeats.map { "\($0)" } ?? "?"
        return "\(file.sentenceSetTitle), \(attempts) attempts per sentence. \(file.deviceName), \(file.os)."
    }

    private func fill(_ item: VariantStats) -> CGFloat {
        guard item.quietRuns > 0, item.quietActed > 0 else { return 0 }
        return max(24, barWidth * CGFloat(item.quietActed) / CGFloat(item.quietRuns))
    }

    /// Draws the picture and saves it as a PNG. Returns nil if drawing failed.
    static func render(_ analysis: RunAnalysis) -> URL? {
        let renderer = ImageRenderer(content: ChartPicture(analysis: analysis))
        renderer.scale = 2
        guard let data = renderer.uiImage?.pngData() else { return nil }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("good-intentions-chart.png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}
