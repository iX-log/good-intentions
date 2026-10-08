// The sentences in one list, grouped by kind, so anyone can read exactly
// what the test says to the AI and what should happen each time.

import SwiftUI

struct SentenceListView: View {
    let set: SentenceSet

    var body: some View {
        let sentences = set.load() ?? []
        let requests = sentences.filter { $0.expectedTool != nil }
        // Kinds in the order they first appear in the file.
        let kinds = sentences.reduce(into: [String]()) { list, sentence in
            if !list.contains(sentence.category) { list.append(sentence.category) }
        }

        List {
            Section {
                Text("\(requests.count) are real requests. The other \(sentences.count - requests.count) are not, and the AI should do nothing.")
                    .font(.subheadline)
            }

            ForEach(kinds, id: \.self) { kind in
                Section {
                    ForEach(sentences.filter { $0.category == kind }) { sentence in
                        Text(sentence.text)
                            .font(.body)
                            .fontDesign(.serif)
                            .foregroundStyle(Theme.ink)
                    }
                } header: {
                    Text(SentenceKind.title(for: kind))
                }
            }
        }
        .onDesk()
        .navigationTitle(set.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The made-up address book the test uses.
struct ContactsView: View {
    var body: some View {
        List {
            Section {
                ForEach(ContactEntity.all, id: \.id) { contact in
                    Label(contact.name, systemImage: "person.fill")
                        .foregroundStyle(Theme.ink)
                }
            } footer: {
                Text("Invented people. A message only counts as sent if it is addressed to exactly one of them. Two are called Theo on purpose.")
            }
        }
        .onDesk()
        .navigationTitle("The address book")
        .navigationBarTitleDisplayMode(.inline)
    }
}
