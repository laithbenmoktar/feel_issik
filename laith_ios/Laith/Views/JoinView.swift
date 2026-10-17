import SwiftUI
import FirebaseFirestore

struct JoinView: View {
    @EnvironmentObject var app: AppState
    let done: () -> Void

    private enum Phase { case loading, form, joined(String, String) }
    @State private var phase: Phase = .loading
    @State private var first = "", last = "", email = "", phone = "", motivation = ""
    @State private var level = studyLevels[1]
    @State private var lockedLevel = false
    @State private var selectedPoles = Set<String>()
    @State private var selectedPassions = Set<String>()
    @State private var photo: String?
    @State private var consent = false
    @State private var busy = false
    @State private var error: String?
    @State private var lockedIdentity = Set<String>()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                switch phase {
                case .loading: ProgressView().frame(maxWidth: .infinity).padding(40)
                case .joined(let t, let b):
                    CardBox { Text(t).font(.headline); if !b.isEmpty { Text(b).foregroundColor(.textGray) } }
                case .form: form
                }
            }.padding(16)
        }
        .background(Color.pageBg)
        .task { await applyAccountState() }
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 12) {
            if app.isLoggedIn {
                Text("Vos informations sont reprises de votre compte (modifiables dans Profil → Mes informations).")
                    .font(.caption).foregroundColor(.textBlue)
            }
            FormField(label: "Prénom *", text: $first, disabled: lockedIdentity.contains("first"))
            FormField(label: "Nom de famille *", text: $last, disabled: lockedIdentity.contains("last"))
            FormField(label: "Adresse Email *", text: $email, disabled: lockedIdentity.contains("email"), keyboard: .emailAddress)
            FormField(label: "Téléphone", text: $phone, keyboard: .phonePad)
            VStack(alignment: .leading, spacing: 4) {
                Text("Niveau d'études à l'ISSIK *").font(.caption.bold()).foregroundColor(.textBlue)
                Picker("Niveau", selection: $level) { ForEach(studyLevels, id: \.self) { Text($0).tag($0) } }
                    .pickerStyle(.menu).disabled(lockedLevel)
            }
            HStack {
                AvatarView(b64: photo, initials: "📷", size: 56)
                PhotoPickerButton(maxSide: 500, onPicked: { photo = $0 }) { Text("Importer une photo").font(.callout.bold()) }
            }
            HStack { Text("Pôles d'activité *").font(.headline); Spacer(); Text("\(selectedPoles.count) sélectionné(s)").font(.caption) }
            ForEach(Poles.all) { p in
                Button { toggle(&selectedPoles, p.title) } label: {
                    HStack {
                        Image(systemName: selectedPoles.contains(p.title) ? "checkmark.circle.fill" : "circle").foregroundColor(.primaryBlue)
                        VStack(alignment: .leading) {
                            Text("\(p.icon) \(p.title)").font(.callout.bold()).foregroundColor(.textDark)
                            Text(p.description).font(.caption).foregroundColor(.textGray).lineLimit(2)
                        }
                        Spacer()
                    }.padding(10).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            Text("Passions").font(.headline)
            FlowChips(items: passionChoices, selected: $selectedPassions)
            FormField(label: "Motivation", text: $motivation, multiline: true)
            Toggle("Je confirme que ces informations sont exactes", isOn: $consent)
            if let error { Text(error).foregroundColor(.danger).font(.callout) }
            PrimaryButton(title: busy ? "Envoi…" : "Envoyer ma demande", disabled: busy) { Task { await submit() } }
        }
    }

    private func toggle(_ set: inout Set<String>, _ v: String) { if set.contains(v) { set.remove(v) } else { set.insert(v) } }

    // Visiteur : formulaire libre ; bureau : pas de formulaire ; demande déjà envoyée : son statut.
    private func applyAccountState() async {
        guard let uid = app.myUid else { phase = .form; return }
        let p = await app.loadProfile()
        if p?.isBureau == true {
            phase = .joined("👑 Vous faites déjà partie du club", "Les membres du bureau n'ont pas de formulaire d'adhésion à remplir.")
            return
        }
        if let d = try? await app.db.collection("joinRequests").document(uid).getDocument(), d.exists {
            let st = d.data()?["status"] as? String ?? "nouveau"
            phase = .joined("✅ Votre demande est déjà enregistrée",
                            "Statut : \(joinStatusLabel(st))\n\nLe formulaire n'est plus disponible : vos informations sont liées à votre profil.")
            return
        }
        if let p {
            if !p.firstName.isEmpty { first = p.firstName; lockedIdentity.insert("first") }
            if !p.lastName.isEmpty { last = p.lastName; lockedIdentity.insert("last") }
            let mail = p.email.isEmpty ? (app.user?.email ?? "") : p.email
            if !mail.isEmpty { email = mail; lockedIdentity.insert("email") }
            phone = p.phone
            if studyLevels.contains(p.level) { level = p.level; lockedLevel = true }
        }
        phase = .form
    }

    private func submit() async {
        error = nil
        let f = first.trimmingCharacters(in: .whitespaces), l = last.trimmingCharacters(in: .whitespaces)
        let m = email.trimmingCharacters(in: .whitespaces)
        if f.isEmpty || l.isEmpty { error = "Champ obligatoire : prénom et nom"; return }
        if !m.contains("@") || !m.contains(".") { error = "Adresse email invalide"; return }
        if selectedPoles.isEmpty { error = "Choisissez au moins un pôle d'activité"; return }
        if !consent { error = "Veuillez accepter la confirmation pour continuer"; return }
        busy = true; defer { busy = false }

        let poles = Poles.all.map { $0.title }.filter { selectedPoles.contains($0) }
        let passions = passionChoices.filter { selectedPassions.contains($0) }
        var req: [String: Any] = ["firstName": f, "lastName": l, "email": m,
            "phone": phone.trimmingCharacters(in: .whitespaces), "level": level, "poles": poles, "passions": passions,
            "motivation": motivation.trimmingCharacters(in: .whitespaces), "status": "nouveau",
            "createdAt": FieldValue.serverTimestamp()]
        if let photo { req["photo"] = photo }
        do {
            if let uid = app.myUid {
                req["uid"] = uid
                // Membre connecté : joinRequests/<uid> → une seule demande (garanti par les règles)
                try await app.db.collection("joinRequests").document(uid).setData(req)
                let mirror: [String: Any] = ["firstName": f, "lastName": l, "level": level, "phone": req["phone"]!,
                    "poles": poles, "passions": passions, "motivation": req["motivation"]!,
                    "joinStatus": "nouveau", "joinedAt": FieldValue.serverTimestamp()]
                try? await app.db.collection("users").document(uid).setData(mirror, merge: true)
                await app.loadProfile()
            } else {
                try await app.db.collection("joinRequests").addDocument(data: req)
            }
            phase = .joined("✅ Demande envoyée au responsable ✔", "")
        } catch { self.error = "Erreur d'envoi : \(app.errorText(error))" }
    }
}

/// Puces à choix multiples qui passent à la ligne.
struct FlowChips: View {
    let items: [String]
    @Binding var selected: Set<String>
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { it in
                let on = selected.contains(it)
                Button { if on { selected.remove(it) } else { selected.insert(it) } } label: {
                    Text(it).font(.caption).lineLimit(1).padding(.horizontal, 10).padding(.vertical, 7).frame(maxWidth: .infinity)
                        .background(on ? Color.primaryBlue : Color.white).foregroundColor(on ? .white : .textDark)
                        .overlay(Capsule().stroke(Color.cardBorder)).clipShape(Capsule())
                }
            }
        }
    }
}
