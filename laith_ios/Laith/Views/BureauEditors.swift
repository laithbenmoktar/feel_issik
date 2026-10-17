import SwiftUI
import FirebaseFirestore

private func s(_ d: [String: Any], _ k: String) -> String { d[k] as? String ?? "" }

/// Gabarit commun des fenêtres d'édition du mode Bureau.
struct EditorSheet<Content: View>: View {
    @EnvironmentObject var app: AppState
    @Environment(\.dismiss) private var dismiss
    let title: String
    let save: () async throws -> Void
    @ViewBuilder var content: Content
    @State private var error: String?
    @State private var busy = false
    var body: some View {
        NavigationStack {
            ScrollView { VStack(alignment: .leading, spacing: 12) {
                content
                if let error { Text(error).foregroundColor(.danger).font(.callout) }
            }.padding(16) }
            .background(Color.pageBg)
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(busy ? "…" : "Enregistrer") {
                        busy = true
                        Task {
                            do { try await save(); dismiss() } catch { self.error = app.errorText(error) }
                            busy = false
                        }
                    }.disabled(busy)
                }
            }
        }
    }
}

struct PhotoEditRow: View {
    let label: String
    @Binding var photo: String?
    var body: some View {
        HStack {
            Base64Image(b64: photo).frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 10))
            PhotoPickerButton(maxSide: 600, onPicked: { photo = $0 }) { Text(label).font(.callout.bold()) }
            if photo != nil { Button("Retirer", role: .destructive) { photo = nil } }
        }
    }
}

struct MemberEditor: View {
    @EnvironmentObject var app: AppState
    let initial: [String: Any]
    @State private var name = "", info = "", distinction = "", quote = ""
    @State private var photo: String?
    var body: some View {
        EditorSheet(title: "Member of the Month", save: {
            if name.trimmingCharacters(in: .whitespaces).isEmpty { throw AppError("Le nom est obligatoire") }
            var data: [String: Any] = ["name": name.trimmingCharacters(in: .whitespaces), "info": info, "distinction": distinction,
                                       "quote": quote, "updatedAt": FieldValue.serverTimestamp()]
            data["photo"] = photo ?? FieldValue.delete()
            try await app.db.collection("config").document("memberOfMonth").setData(data, merge: true)
        }) {
            FormField(label: "Nom complet", text: $name)
            FormField(label: "Niveau et pôles", text: $info)
            FormField(label: "Distinction & réalisations", text: $distinction, multiline: true)
            FormField(label: "Citation", text: $quote, multiline: true)
            PhotoEditRow(label: "Photo du membre", photo: $photo)
        }
        .onAppear { name = s(initial, "name"); info = s(initial, "info"); distinction = s(initial, "distinction")
            quote = s(initial, "quote"); photo = initial["photo"] as? String }
    }
}

struct PoleEditor: View {
    @EnvironmentObject var app: AppState
    let pole: Pole
    let initial: [String: Any]
    @State private var desc = "", chief = "", schedule = "", projects = ""
    @State private var cover: String?
    var body: some View {
        EditorSheet(title: "\(pole.icon) \(pole.shortName)", save: {
            var data: [String: Any] = ["description": desc, "projects": Int(projects) ?? pole.projects, "chief": chief,
                                       "schedule": schedule, "updatedAt": FieldValue.serverTimestamp()]
            data["cover"] = cover ?? FieldValue.delete()
            try await app.db.collection("subgroups").document(pole.id).setData(data, merge: true)
        }) {
            FormField(label: "Description", text: $desc, multiline: true)
            FormField(label: "Chef de pôle", text: $chief)
            FormField(label: "Horaires & lieu", text: $schedule)
            FormField(label: "Project Suggestions (nombre)", text: $projects, keyboard: .numberPad)
            PhotoEditRow(label: "Photo du pôle", photo: $cover)
        }
        .onAppear {
            desc = s(initial, "description").isEmpty ? pole.description : s(initial, "description")
            chief = s(initial, "chief"); schedule = s(initial, "schedule")
            projects = String((initial["projects"] as? NSNumber)?.intValue ?? pole.projects)
            cover = initial["cover"] as? String
        }
    }
}

struct TeamPostEditor: View {
    @EnvironmentObject var app: AppState
    let post: TeamPost
    @State private var name = "", level = studyLevels[0], desc = "", email = "", phone = ""
    @State private var photo: String?
    var body: some View {
        EditorSheet(title: post.role, save: {
            var data: [String: Any] = ["name": name, "level": level, "description": desc, "email": email, "phone": phone,
                                       "updatedAt": FieldValue.serverTimestamp()]
            data["photo"] = photo ?? FieldValue.delete()
            try await app.db.collection("team").document(post.id).setData(data, merge: true)
        }) {
            FormField(label: "Nom", text: $name)
            Picker("Niveau", selection: $level) { ForEach(studyLevels, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
            FormField(label: "Description", text: $desc, multiline: true)
            FormField(label: "E-mail", text: $email, keyboard: .emailAddress)
            FormField(label: "Téléphone", text: $phone, keyboard: .phonePad)
            PhotoEditRow(label: "Photo", photo: $photo)
        }
        .onAppear { name = post.name; level = studyLevels.contains(post.level) ? post.level : studyLevels[0]
            desc = post.description; email = post.email; phone = post.phone; photo = post.photo }
    }
}

struct EventEditor: View {
    @EnvironmentObject var app: AppState
    let existing: EventItem?
    @State private var title = "", place = "", desc = "", time = "18:00"
    @State private var date = Date()
    @State private var group = "Tous"
    private let groups = ["Tous"] + Poles.all.map { $0.shortName }
    var body: some View {
        EditorSheet(title: existing == nil ? "Nouvel événement" : "Modifier l'événement", save: {
            if title.trimmingCharacters(in: .whitespaces).isEmpty { throw AppError("Le titre est obligatoire") }
            var data: [String: Any] = ["title": title, "description": desc, "date": DateFmt.iso.string(from: date), "time": time,
                                       "place": place, "group": group, "updatedAt": FieldValue.serverTimestamp()]
            let col = app.db.collection("events")
            if let e = existing { try await col.document(e.id).setData(data, merge: true) }
            else { data["createdAt"] = FieldValue.serverTimestamp(); try await col.addDocument(data: data) }
        }) {
            FormField(label: "Titre", text: $title)
            DatePicker("Date", selection: $date, displayedComponents: .date).environment(\.locale, Locale(identifier: "fr_FR"))
            FormField(label: "Heure (ex. 18:00)", text: $time)
            FormField(label: "Lieu", text: $place)
            Picker("Sous-groupe", selection: $group) { ForEach(groups, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
            FormField(label: "Description", text: $desc, multiline: true)
        }
        .onAppear {
            if let e = existing { title = e.title; place = e.place; desc = e.description; time = e.time; date = e.date; group = e.group }
        }
    }
}

struct NewsEditor: View {
    @EnvironmentObject var app: AppState
    let existing: NewsItem?
    @State private var title = "", body_ = ""
    var body: some View {
        EditorSheet(title: existing == nil ? "Nouvelle actualité" : "Modifier l'actualité", save: {
            if title.trimmingCharacters(in: .whitespaces).isEmpty { throw AppError("Le titre est obligatoire") }
            let col = app.db.collection("news")
            if let n = existing { try await col.document(n.id).updateData(["title": title, "body": body_]) }
            else { try await col.addDocument(data: ["title": title, "body": body_, "ts": Int64(Date().timeIntervalSince1970 * 1000)]) }
        }) {
            FormField(label: "Titre", text: $title)
            FormField(label: "Texte", text: $body_, multiline: true)
        }
        .onAppear { if let n = existing { title = n.title; body_ = n.body } }
    }
}
