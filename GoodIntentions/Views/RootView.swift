// Three tabs. Try it: say one thing and decide. Saved: what the phone really
// saved when asked to do it for real. Results: the evidence from the measured
// tests, with running a new test tucked inside.

import SwiftUI

struct RootView: View {
    @State private var store = LogStore()
    @State private var examination = Examination()

    var body: some View {
        TabView {
            Tab("Try it", systemImage: "mic.fill") {
                DictateView()
            }
            Tab("Saved", systemImage: "tray.full.fill") {
                SavedView()
            }
            Tab("Results", systemImage: "chart.bar.fill") {
                ResultsView()
            }
        }
        .environment(store)
        .environment(examination)
        .tint(Theme.seal)
    }
}
