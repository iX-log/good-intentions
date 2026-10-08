// Running a measured test, and choosing which saved test the Results screen
// shows. Reached from Results, since it is only needed for new data.

import SwiftUI

struct ExaminationView: View {
    @Environment(LogStore.self) private var store
    @Environment(Examination.self) private var examination
    @State private var confirmingDelete = false
    @State private var showingExplainer = false

    private var sentenceCount: Int {
        SentenceSet.named(examination.sentenceSetName).load()?.count ?? 0
    }

    private var plannedRuns: Int {
        sentenceCount * examination.repeats * examination.chosenVariants.count
    }

    var body: some View {
        @Bindable var examination = examination

        List {
            Section {
                Picker("Sentences", selection: $examination.sentenceSetName) {
                    ForEach(SentenceSet.runnable) { set in
                        Text(set.title).tag(set.name)
                    }
                }
                NavigationLink {
                    SentenceListView(set: SentenceSet.named(examination.sentenceSetName))
                } label: {
                    Label("See the \(sentenceCount) sentences", systemImage: "text.quote")
                }
                NavigationLink {
                    ContactsView()
                } label: {
                    Label("See the \(ContactEntity.all.count) contacts", systemImage: "person.2")
                }
                Stepper("Say each one \(examination.repeats) times", value: $examination.repeats, in: 1...20)
            } header: {
                Text("What to test")
            }
            .disabled(examination.isRunning)

            Section {
                ForEach(Variant.all) { variant in
                    Toggle(variant.title, isOn: binding(for: variant.name))
                }
            } header: {
                HStack {
                    Text("Ways of preparing the AI")
                    Spacer()
                    Button {
                        showingExplainer = true
                    } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("What do these mean?")
                }
            }
            .disabled(examination.isRunning)

            Section {
                if examination.isRunning {
                    ProgressView(value: Double(examination.done), total: Double(max(examination.total, 1)))
                    Button("Stop", role: .destructive) {
                        examination.cancel()
                    }
                } else {
                    Button {
                        Task { await examination.run(store: store) }
                    } label: {
                        Label("Run the test", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .foregroundStyle(.white)
                    .listRowBackground(Theme.seal.opacity(examination.chosenVariants.isEmpty ? 0.35 : 1))
                    .disabled(examination.chosenVariants.isEmpty)
                }
                if !examination.status.isEmpty {
                    Text(examination.status)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text(examination.isRunning
                    ? "Keep the app open until it finishes."
                    : "About \(max(1, plannedRuns * 2 / 60)) minutes. Keep the app open while it runs.")
            }

            Section {
                if store.files.isEmpty {
                    Text("No tests saved yet.").foregroundStyle(.secondary)
                }
                ForEach(store.files, id: \.self) { url in
                    HStack {
                        Button {
                            store.open(url)
                        } label: {
                            Label(
                                store.title(for: url),
                                systemImage: url == store.currentURL ? "checkmark.circle.fill" : "circle"
                            )
                        }
                        .buttonStyle(.borderless)
                        Spacer()
                        ShareLink(item: url) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        .buttonStyle(.borderless)
                    }
                }
                if let problem = store.loadError {
                    Text(problem).font(.footnote).foregroundStyle(.secondary)
                }
                if !store.files.isEmpty {
                    Button("Delete every saved test", role: .destructive) {
                        confirmingDelete = true
                    }
                    .disabled(examination.isRunning)
                }
            } header: {
                Text("Saved tests")
            } footer: {
                Text("The ticked test is the one shown in Results.")
            }
        }
        .onDesk()
        .navigationTitle("Run a test")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingExplainer) {
            ExplainerView(names: Variant.all.map(\.name))
        }
        .confirmationDialog(
            "Delete every saved test from this phone?",
            isPresented: $confirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete \(store.files.count) tests", role: .destructive) {
                store.deleteAll()
            }
        } message: {
            Text("The raw logs are the evidence. Share them off the phone first.")
        }
    }

    private func binding(for name: String) -> Binding<Bool> {
        Binding(
            get: { examination.selected.contains(name) },
            set: { isOn in
                if isOn {
                    examination.selected.insert(name)
                } else {
                    examination.selected.remove(name)
                }
            }
        )
    }
}
