// Everything the screens show is counted here, from the raw records of one
// run. Nothing is typed in and nothing is carried over between runs.

import Foundation

/// The headline counts for one briefing.
struct VariantStats: Identifiable {
    let variant: String
    var id: String { variant }

    // Sentences where nothing should happen.
    let quietRuns: Int                   // usable runs
    let quietActed: Int                  // of those, runs that saved or sent something
    let lettersSent: Int                 // of those, runs with a letter to a known contact
    let categories: [CategoryStat]

    // Sentences that are real dictation.
    let realRuns: Int                    // usable runs
    let realRight: Int                   // exactly the right thing, once
    let realSilent: Int                  // did nothing at all
    let paramsScored: Int
    let paramsRight: Int

    let errors: Int
    let total: Int
    let medianSeconds: Double?
    let gateYesQuiet: Int?               // two-step only: how often the gate said yes
    let gateYesReal: Int?
}

struct CategoryStat: Identifiable {
    let category: String
    let runs: Int
    let acted: Int
    var id: String { category }
}

/// One sentence under one briefing, across all its repeats.
struct SentenceStat: Identifiable {
    let variant: String
    let utteranceID: String
    let category: String
    let text: String
    let expectsAction: Bool
    let runs: [RunRecord]                // every repeat, usable or not
    var id: String { "\(variant)|\(utteranceID)" }

    var usable: [RunRecord] { runs.filter(\.isUsable) }
    var actedCount: Int { usable.filter(\.didAct).count }
    var rightCount: Int { usable.filter(\.toolCorrect).count }
    /// Real dictation that got no action at all, and no error either.
    var ignoredCount: Int { usable.filter { !$0.didAct && $0.error == nil }.count }

    /// The count that matters for this kind of sentence.
    var headlineCount: Int { expectsAction ? rightCount : actedCount }
}

/// The letters one sentence that asked for nothing produced under one briefing.
struct LetterPart: Identifiable {
    let variant: String
    let letters: [Letter]                // one per run that wrote a letter (its first)
    let usableRuns: Int
    var id: String { variant }

    var sentCount: Int { letters.filter(\.wouldBeSent).count }

    /// The same letters with identical ones counted together, commonest first.
    var distinct: [DistinctLetter] {
        var order: [String] = []
        var counts: [String: Int] = [:]
        var firsts: [String: Letter] = [:]
        for letter in letters {
            let key = "\(letter.recipientID)|\(letter.time)|\(letter.body)"
            if counts[key] == nil {
                order.append(key)
                firsts[key] = letter
            }
            counts[key, default: 0] += 1
        }
        let all = order.compactMap { key -> DistinctLetter? in
            guard let letter = firsts[key], let count = counts[key] else { return nil }
            return DistinctLetter(id: key, letter: letter, count: count)
        }
        return all.sorted { $0.count > $1.count }
    }
}

struct DistinctLetter: Identifiable {
    let id: String
    let letter: Letter
    let count: Int
}

/// One sentence that asked for nothing, and the letters it produced, under one
/// briefing or under several.
struct LetterGroup: Identifiable {
    let utteranceID: String
    let category: String
    let sentence: String
    let parts: [LetterPart]              // one per briefing that produced a letter
    var id: String { utteranceID + "|" + parts.map(\.variant).joined(separator: ",") }

    var letterCount: Int { parts.reduce(0) { $0 + $1.letters.count } }
    var sentCount: Int { parts.reduce(0) { $0 + $1.sentCount } }

    /// The letter shown on the card: one that would really have gone out, if any.
    var showpiece: Letter? {
        let all = parts.flatMap(\.letters)
        return all.first(where: \.wouldBeSent) ?? all.first
    }
}

struct RunAnalysis {
    let file: RunFile
    let variantNames: [String]           // known briefings first, in their usual order
    let stats: [VariantStats]

    init(file: RunFile) {
        self.file = file
        var seen: [String] = []
        for record in file.records where !seen.contains(record.variant) {
            seen.append(record.variant)
        }
        let known = Variant.all.map(\.name).filter { seen.contains($0) }
        let unknown = seen.filter { name in !known.contains(name) }
        variantNames = known + unknown
        stats = variantNames.map { RunAnalysis.makeStats(variant: $0, records: file.records) }
    }

    func stats(for variant: String) -> VariantStats? {
        stats.first { $0.variant == variant }
    }

    /// Sentences under one briefing, in the order they were said.
    func sentences(variant: String, expectingAction: Bool) -> [SentenceStat] {
        let mine = file.records.filter { $0.variant == variant && $0.expectsAction == expectingAction }
        var order: [String] = []
        var byID: [String: [RunRecord]] = [:]
        for record in mine {
            if byID[record.utteranceID] == nil { order.append(record.utteranceID) }
            byID[record.utteranceID, default: []].append(record)
        }
        return order.compactMap { id in
            guard let runs = byID[id], let first = runs.first else { return nil }
            return SentenceStat(
                variant: variant, utteranceID: id, category: first.category,
                text: first.text, expectsAction: first.expectsAction, runs: runs
            )
        }
    }

    /// One sentence under every briefing in this run.
    func sentenceAcrossVariants(_ utteranceID: String) -> [SentenceStat] {
        variantNames.compactMap { name in
            let runs = file.records.filter { $0.variant == name && $0.utteranceID == utteranceID }
            guard let first = runs.first else { return nil }
            return SentenceStat(
                variant: name, utteranceID: utteranceID, category: first.category,
                text: first.text, expectsAction: first.expectsAction, runs: runs
            )
        }
    }

    /// Letters nobody dictated, one group per sentence. Pass nil to gather
    /// every briefing in the run into the same group.
    func letterGroups(variant: String?) -> [LetterGroup] {
        let names = variant.map { [$0] } ?? variantNames
        var order: [String] = []
        var parts: [String: [LetterPart]] = [:]
        var heads: [String: SentenceStat] = [:]
        for name in names {
            for sentence in sentences(variant: name, expectingAction: false) {
                let letters = sentence.usable.compactMap { $0.letters.first }
                guard !letters.isEmpty else { continue }
                if heads[sentence.utteranceID] == nil {
                    order.append(sentence.utteranceID)
                    heads[sentence.utteranceID] = sentence
                }
                parts[sentence.utteranceID, default: []].append(
                    LetterPart(variant: name, letters: letters, usableRuns: sentence.usable.count)
                )
            }
        }
        let groups = order.compactMap { id -> LetterGroup? in
            guard let head = heads[id], let mine = parts[id] else { return nil }
            return LetterGroup(utteranceID: id, category: head.category, sentence: head.text, parts: mine)
        }
        return groups.sorted { ($0.sentCount, $0.letterCount) > ($1.sentCount, $1.letterCount) }
    }

    // MARK: Counting

    private static func makeStats(variant: String, records: [RunRecord]) -> VariantStats {
        let mine = records.filter { $0.variant == variant }

        let quiet = mine.filter { !$0.expectsAction && $0.isUsable }
        let quietActed = quiet.filter(\.didAct)
        let lettersSent = quiet.filter { record in record.letters.contains { $0.wouldBeSent } }
        var categoryOrder: [String] = []
        for record in quiet where !categoryOrder.contains(record.category) {
            categoryOrder.append(record.category)
        }
        let categories = categoryOrder.map { category in
            let inCategory = quiet.filter { $0.category == category }
            return CategoryStat(
                category: category, runs: inCategory.count,
                acted: inCategory.filter(\.didAct).count
            )
        }

        let real = mine.filter { $0.expectsAction && $0.isUsable }
        let scored = real.compactMap(\.argsCorrect)
        let times = mine.map(\.secondsTotal).sorted()
        let usesGate = mine.contains { $0.gate != nil }

        return VariantStats(
            variant: variant,
            quietRuns: quiet.count,
            quietActed: quietActed.count,
            lettersSent: lettersSent.count,
            categories: categories,
            realRuns: real.count,
            realRight: real.filter(\.toolCorrect).count,
            realSilent: real.filter { !$0.didAct && $0.error == nil }.count,
            paramsScored: scored.count,
            paramsRight: scored.filter { $0 }.count,
            errors: mine.filter { $0.error != nil }.count,
            total: mine.count,
            medianSeconds: times.isEmpty ? nil : times[times.count / 2],
            gateYesQuiet: usesGate ? mine.filter { !$0.expectsAction && $0.gate == true }.count : nil,
            gateYesReal: usesGate ? mine.filter { $0.expectsAction && $0.gate == true }.count : nil
        )
    }

    // MARK: Text

    static func rate(_ part: Int, _ whole: Int) -> String {
        guard whole > 0 else { return "0 of 0" }
        return "\(part) of \(whole) (\(percent(part, whole))%)"
    }

    static func percent(_ part: Int, _ whole: Int) -> Int {
        guard whole > 0 else { return 0 }
        return Int((Double(part) / Double(whole) * 100).rounded())
    }

    /// The plain-text summary, for the console and for sharing.
    var textSummary: String {
        let started = file.startedAt.formatted(date: .abbreviated, time: .shortened)
        let repeatsText = file.repeats.map { "\($0)" } ?? "?"
        let finishedText = file.finished == false ? "no" : "yes"
        var lines: [String] = [
            "Device \(file.deviceName), \(file.os)",
            "Started \(started), repeats \(repeatsText), finished \(finishedText)",
            "Sentences: \(file.sentenceSetTitle)",
            "",
        ]
        for item in stats {
            lines.append("=== \(item.variant) ===")
            lines.append("Acted when it should not: \(Self.rate(item.quietActed, item.quietRuns))")
            for category in item.categories {
                lines.append("  \(category.category): \(Self.rate(category.acted, category.runs))")
            }
            lines.append("Of those, letters to a known contact: \(item.lettersSent)")
            lines.append("Real requests, right intent: \(Self.rate(item.realRight, item.realRuns))")
            lines.append("Real requests, did nothing: \(Self.rate(item.realSilent, item.realRuns))")
            lines.append("Right parameters, of right intents: \(Self.rate(item.paramsRight, item.paramsScored))")
            if let quietYes = item.gateYesQuiet, let realYes = item.gateYesReal {
                lines.append("Gate said yes: \(quietYes) no-action runs, \(realYes) real-request runs")
            }
            lines.append("Runs with an error: \(item.errors) of \(item.total)")
            if let median = item.medianSeconds {
                lines.append(String(format: "Median time: %.2f s", median))
            }
            lines.append("Per no-action sentence, runs that acted:")
            for sentence in sentences(variant: item.variant, expectingAction: false) {
                lines.append("  \(sentence.actedCount)/\(sentence.usable.count)  [\(sentence.category)] \(sentence.text)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
}
