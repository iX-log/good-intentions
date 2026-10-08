// The third tab: everything the phone really saved while "Do it for real"
// was on. Three tiles, one per kind, each opening its list. Every item can
// be copied, and one button takes all of it back.

import SwiftUI

enum SavedKind: String, Identifiable {
    case reminders, notes, messages
    var id: String { rawValue }

    var title: String {
        switch self {
        case .reminders: return "Reminders"
        case .notes: return "Notes"
        case .messages: return "Messages"
        }
    }

    var symbol: String {
        switch self {
        case .reminders: return "bell.fill"
        case .notes: return "book.closed.fill"
        case .messages: return "envelope.fill"
        }
    }

    var caption: String {
        switch self {
        case .reminders: return "In the Reminders app."
        case .notes: return "Kept in this app."
        case .messages: return "Written, never sent."
        }
    }

    /// The kind of thing an action saves.
    static func of(tool: String) -> SavedKind {
        switch tool {
        case "scheduleMessage": return .messages
        case "createNote": return .notes
        default: return .reminders
        }
    }
}

struct SavedView: View {
    @State private var real = RealActions.shared
    @State private var confirmingUndo = false
    @State private var showingInfo = false
    @AppStorage("reallyDoIt") private var live = false

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if !live && real.count == 0 {
                        Text("Nothing is saved until you switch on \u{201C}Do it for real\u{201D} on Try it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                    LazyVGrid(columns: columns, spacing: 12) {
                        tile(.reminders, real.reminders.count)
                        tile(.notes, real.notes.count)
                        tile(.messages, real.messages.count)
                    }
                    if real.count > 0 {
                        Button(role: .destructive) {
                            confirmingUndo = true
                        } label: {
                            Text("Undo everything")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
                        }
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.desk.ignoresSafeArea())
            .disabled(real.isUndoing)
            .overlay {
                if real.isUndoing {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Undoing").font(.headline)
                    }
                    .padding(28)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .navigationTitle("Saved")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingInfo = true } label: {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel("What is real here?")
                }
            }
            .sheet(isPresented: $showingInfo) { RealInfoView() }
            .alert("Take it all back?", isPresented: $confirmingUndo) {
                Button("Undo everything", role: .destructive) {
                    Task { await real.undoEverything() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Removes the list from the Reminders app, and the notes and messages kept here.")
            }
        }
    }

    private func tile(_ kind: SavedKind, _ count: Int) -> some View {
        NavigationLink {
            SavedListView(kind: kind)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text("\(count)")
                        .font(.system(size: 44, weight: .bold, design: .serif))
                        .monospacedDigit()
                        .foregroundStyle(Theme.ink)
                    Spacer(minLength: 4)
                    Image(systemName: kind.symbol)
                        .font(.title3)
                        .foregroundStyle(Theme.seal)
                }
                Text(kind.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text(kind.caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .multilineTextAlignment(.leading)
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }
}

/// One kind of saved thing, as a list. One row per item; a tap opens it.
struct SavedListView: View {
    let kind: SavedKind
    @State private var real = RealActions.shared

    var body: some View {
        List {
            switch kind {
            case .reminders:
                if real.reminders.isEmpty { empty }
                ForEach(real.reminders) { reminder in
                    row(reminder.id, reminder.what,
                        reminder.problem == nil ? reminder.time : "Not added")
                }
            case .notes:
                if real.notes.isEmpty { empty }
                ForEach(real.notes) { note in
                    row(note.id, note.title, note.body)
                }
            case .messages:
                if real.messages.isEmpty { empty }
                ForEach(real.messages) { message in
                    row(message.id, "To \(message.to)", message.body)
                }
            }
        }
        .onDesk()
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func row(_ id: UUID, _ title: String, _ preview: String) -> some View {
        NavigationLink {
            SavedDetailView(kind: kind, id: id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: kind.symbol)
                    .foregroundStyle(Theme.seal)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .fontDesign(.serif)
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    if !preview.isEmpty {
                        Text(preview)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var empty: some View {
        Text("Nothing yet.")
            .foregroundStyle(.secondary)
    }
}

/// One saved thing in full. Every part can be changed and copied.
struct SavedDetailView: View {
    let kind: SavedKind
    let id: UUID
    @State private var real = RealActions.shared

    var body: some View {
        List {
            switch kind {
            case .reminders:
                if let reminder = real.reminders.first(where: { $0.id == id }) {
                    Section {
                        EditRow(label: "Reminder", text: Binding(
                            get: { reminder.what },
                            set: { new in real.update(reminder: id) { $0.what = new } }
                        ))
                        TimeRow(time: Binding(
                            get: { reminder.time },
                            set: { new in real.update(reminder: id) { $0.time = new } }
                        ))
                        if let problem = reminder.problem {
                            Text("Not added: \(problem)")
                                .font(.footnote)
                                .foregroundStyle(Theme.seal)
                        }
                    }
                    if reminder.problem == nil {
                        Section {
                            Button {
                                real.syncReminder(id)
                                if let url = URL(string: "x-apple-reminderkit://") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Label("Open the Reminders app", systemImage: "arrow.up.forward.app")
                            }
                        } footer: {
                            Text("It is in the list called \(RealActions.listName).")
                        }
                    }
                }

            case .notes:
                if let note = real.notes.first(where: { $0.id == id }) {
                    Section {
                        EditRow(label: "Title", text: Binding(
                            get: { note.title },
                            set: { new in real.update(note: id) { $0.title = new } }
                        ))
                        EditRow(label: "Note", text: Binding(
                            get: { note.body },
                            set: { new in real.update(note: id) { $0.body = new } }
                        ))
                    }
                }

            case .messages:
                if let message = real.messages.first(where: { $0.id == id }) {
                    Section {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Eyebrow(text: "To")
                                // Who it is for, from the address book.
                                Menu {
                                    ForEach(ContactEntity.all, id: \.id) { contact in
                                        Button {
                                            real.update(message: id) { $0.to = contact.name }
                                        } label: {
                                            if contact.name == message.to {
                                                Label(contact.name, systemImage: "checkmark")
                                            } else {
                                                Text(contact.name)
                                            }
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Text(message.to.isEmpty ? "Choose" : message.to)
                                            .fontDesign(.serif)
                                            .foregroundStyle(Theme.ink)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            Spacer(minLength: 8)
                            CopyButton(label: "To", text: message.to)
                        }
                        TimeRow(time: Binding(
                            get: { message.time },
                            set: { new in real.update(message: id) { $0.time = new } }
                        ))
                        EditRow(label: "Message", text: Binding(
                            get: { message.body },
                            set: { new in real.update(message: id) { $0.body = new } }
                        ))
                    } footer: {
                        Text("Written down, never sent.")
                    }
                }
            }
        }
        .onDesk()
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        // Changes to a reminder reach the Reminders app when you leave.
        .onDisappear {
            if kind == .reminders { real.syncReminder(id) }
        }
    }

    private var title: String {
        switch kind {
        case .reminders: return "Reminder"
        case .notes: return "Note"
        case .messages: return "Message"
        }
    }
}

/// A piece of text you can change, with a small label above it and a copy
/// button beside it.
private struct EditRow: View {
    let label: String
    @Binding var text: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Eyebrow(text: label)
                TextField(label, text: $text, axis: .vertical)
                    .font(.body)
                    .fontDesign(.serif)
                    .foregroundStyle(Theme.ink)
            }
            Spacer(minLength: 8)
            CopyButton(label: label, text: text)
        }
    }
}

/// A time that may be missing. No time shows "Add a time"; a set time can
/// be changed or taken away again.
private struct TimeRow: View {
    @Binding var time: String            // "HH:mm", or empty

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Eyebrow(text: "Time")
                if time.isEmpty {
                    Button("Add a time") { time = Self.text(from: Date()) }
                        .buttonStyle(.borderless)
                } else {
                    DatePicker("Time", selection: Binding(
                        get: { Self.date(from: time) },
                        set: { time = Self.text(from: $0) }
                    ), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                }
            }
            Spacer(minLength: 8)
            if !time.isEmpty {
                Button {
                    time = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Remove the time")
                CopyButton(label: "Time", text: time)
            }
        }
    }

    private static func date(from time: String) -> Date {
        let parts = time.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 2 else { return Date() }
        return Calendar.current.date(bySettingHour: parts[0], minute: parts[1], second: 0, of: Date()) ?? Date()
    }

    private static func text(from date: Date) -> String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }
}

/// Copies a piece of text, and shows a tick for a moment.
private struct CopyButton: View {
    let label: String
    let text: String
    @State private var copied = false

    var body: some View {
        Button {
            UIPasteboard.general.string = text
            copied = true
        } label: {
            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                .foregroundStyle(copied ? Theme.laurel : Theme.seal)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Copy \(label)")
        .sensoryFeedback(.success, trigger: copied) { _, now in now }
        .task(id: copied) {
            guard copied else { return }
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }
}

/// What "for real" means for each of the three things the phone can do.
private struct RealInfoView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                row("bell.fill", "Reminders are real",
                    "They go into the Reminders app, in a list called \(RealActions.listName).")
                row("book.closed.fill", "Notes stay in this app",
                    "Apple gives apps no way to write into the Notes app, so they are kept here.")
                row("envelope.fill", "Messages are never sent",
                    "They are only written down. Nobody receives anything.")
            }
            .onDesk()
            .navigationTitle("What is real here?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .tint(Theme.seal)
    }

    private func row(_ icon: String, _ title: String, _ text: String) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).foregroundStyle(Theme.ink)
                Text(text).font(.footnote).foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: icon).foregroundStyle(Theme.seal)
        }
    }
}
