// The examination: every sentence, said `repeats` times to a fresh secretary,
// under each chosen briefing. Raw records go to the log after every pass.

import Foundation
import Observation
import UIKit

@Observable
final class Examination {
    /// Which briefings the next examination covers, by log name.
    var selected: Set<String> = Set(Variant.all.map(\.name))
    /// How many times each sentence is said under each briefing.
    var repeats = 10
    /// Which list of sentences the next examination uses, by log name.
    var sentenceSetName = SentenceSet.current.name

    private(set) var isRunning = false
    private(set) var status = ""
    private(set) var done = 0
    private(set) var total = 0
    private var cancelRequested = false

    var chosenVariants: [Variant] {
        Variant.all.filter { selected.contains($0.name) }
    }

    func cancel() { cancelRequested = true }

    func run(store: LogStore) async {
        guard !isRunning else { return }
        let availability = Secretary.availabilityText
        guard Secretary.isAvailable else {
            status = "The model is not available: \(availability)"
            return
        }
        let sentenceSet = SentenceSet.named(sentenceSetName)
        guard let utterances = sentenceSet.load() else {
            status = "Could not load \(sentenceSet.resource).json from the bundle"
            return
        }
        let variants = chosenVariants
        guard !variants.isEmpty else {
            status = "Pick at least one way of preparing the AI"
            return
        }

        isRunning = true
        cancelRequested = false
        done = 0
        total = variants.count * repeats * utterances.count
        UIApplication.shared.isIdleTimerDisabled = true   // keep the screen on
        let startedAt = Date()
        let passes = variants.count * repeats
        var records: [RunRecord] = []
        var pass = 0

        func file(finished: Bool) -> RunFile {
            RunFile(
                startedAt: startedAt,
                finished: finished,
                device: Self.machineIdentifier(),
                os: ProcessInfo.processInfo.operatingSystemVersionString,
                lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled,
                availability: availability,
                repeats: repeats,
                variants: Dictionary(uniqueKeysWithValues: variants.map { ($0.name, $0.logDescription) }),
                sentenceSet: sentenceSet.name,
                records: records
            )
        }

        outer: for variant in variants {
            for repeatIndex in 1...repeats {
                pass += 1
                for (index, utterance) in utterances.enumerated() {
                    if cancelRequested { break outer }
                    status = "Pass \(pass) of \(passes): \(variant.title), attempt \(repeatIndex), sentence \(index + 1) of \(utterances.count)"
                    records.append(await Self.examine(utterance, variant: variant, repeatIndex: repeatIndex))
                    done += 1
                }
                // Save after every pass, so a crash or a dead battery loses little.
                store.save(file(finished: false))
                print("pass \(pass)/\(passes) done: \(variant.name) \(repeatIndex), thermal \(ProcessInfo.processInfo.thermalState.rawValue)")
            }
        }

        let finished = file(finished: !cancelRequested)
        let name = store.save(finished)
        print("===== GOODINTENTIONS SUMMARY START \(name ?? "unsaved") =====")
        print(RunAnalysis(file: finished).textSummary)
        print("===== GOODINTENTIONS SUMMARY END =====")
        status = (cancelRequested ? "Cancelled. " : "Done. ")
            + (name != nil ? store.currentURL.map { "Saved as \(store.shortTitle(for: $0))." } ?? "Saved." : "Saving failed")
        UIApplication.shared.isIdleTimerDisabled = false
        isRunning = false
    }

    /// Says one sentence and marks the result.
    private static func examine(_ utterance: Utterance, variant: Variant, repeatIndex: Int) async -> RunRecord {
        let outcome = await Secretary.hear(utterance.text, variant: variant)
        // A failed call is never a pass, even when nothing was expected.
        let marks: (toolCorrect: Bool, argsCorrect: Bool?, wrongArgs: [String]) = outcome.error == nil
            ? Scoring.score(utterance, outcome.actionCalls)
            : (false, nil, [])

        return RunRecord(
            variant: variant.name, repeatIndex: repeatIndex,
            utteranceID: utterance.id, category: utterance.category, text: utterance.text,
            expectedTool: utterance.expectedTool,
            calls: outcome.calls, acted: outcome.acted, gate: outcome.gate,
            reply: outcome.reply, error: outcome.error, secondsTotal: outcome.seconds,
            thermalState: ProcessInfo.processInfo.thermalState.rawValue,
            toolCorrect: marks.toolCorrect, argsCorrect: marks.argsCorrect, wrongArgs: marks.wrongArgs
        )
    }

    static func machineIdentifier() -> String {
        var info = utsname()
        uname(&info)
        return withUnsafeBytes(of: &info.machine) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
    }
}
