import SwiftUI
import FirebaseFirestore

/// Tableau de bord des rejoignants + liste des participants (Participants.kt / RejoignantsActivity.kt).
struct RejoignantsView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var users = LiveCollection()
    @StateObject private var requests = LiveCollection()
    @State private var search = ""
    @State private var poleFilter = "Tous les pôles"
    @State private var statusFilter = "Tous"
    @State private var detail: Participant?
    @State private var deciding = false
    @State private var toast: String?
    @State private var error: ErrorMessage?

    private let statuses = ["Tous", "En attente", "Accepté", "Refusé", "Bureau", "Sans demande"]
    private var all: [Participant] { Participant.build(users: users.docs, requests: requests.docs) }

    private var filtered: [Participant] {
        all.filter { p in
            if poleFilter != "Tous les pôles" && !p.poles.contains(poleFilter) { return false }
            switch statusFilter {
            case "En attente": if p.kind != .pending { return false }
            case "Accepté": if p.kind != .member { return false }
            case "Refusé": if p.kind != .refused { return false }
            case "Bureau": if p.kind != .bureau { return false }
            case "Sans demande": if p.kind != .noRequest { return false }
            default: break
            }
            let q = search.trimmingCharacters(in: .whitespaces).lowercased()
            return q.isEmpty || "\(p.fullName) \(p.email) \(p.phone) \(p.level)".lowercased().contains(q)
        }
    }

    var body: some View {
        let list = all
        func count(_ k: Participant.Kind) -> Int { list.filter { $0.kind == k }.count }
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let err = users.error ?? requests.error {
                    Text(app.errorText(err)).foregroundColor(.danger).font(.callout)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    stat("Participants", list.count); stat("Acceptés", count(.member)); stat("En attente", count(.pending))
                    stat("Bureau", count(.bureau)); stat("Refusés", count(.refused)); stat("Sans demande", count(.noRequest))
                }
                CardBox {
                    Text("Inscrits par pôle").font(.headline)
                    ForEach(Poles.all) { p in
                        let inPole = list.filter { $0.kind != .refused && $0.poles.contains(p.title) }
                        let acc = inPole.filter { $0.kind == .member }.count
                        VStack(alignment: .leading, spacing: 2) {
                            HStack { Text("\(p.icon) \(p.shortName)").font(.callout); Spacer(); Text("\(inPole.count) (\(acc) acceptés)").font(.caption) }
                            ProgressView(value: list.isEmpty ? 0 : Double(inPole.count), total: Double(max(list.count, 1)))
                        }
                    }
                }
                CardBox {
                    Text("Par niveau d'études").font(.headline)
                    ForEach(studyLevels, id: \.self) { l in
                        let n = list.filter { $0.level == l }.count
                        if n > 0 { HStack { Text(l).font(.callout); Spacer(); Text("\(n)").bold() } }
                    }
                }

                TextField("Rechercher (nom, e-mail, téléphone…)", text: $search)
                    .padding(10).background(Color.white).overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.cardBorder))
                HStack {
                    Picker("Pôle", selection: $poleFilter) {
                        Text("Tous les pôles").tag("Tous les pôles")
                        ForEach(Poles.all) { Text($0.shortName).tag($0.title) }
                    }.pickerStyle(.menu)
                    Picker("Statut", selection: $statusFilter) { ForEach(statuses, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
                    Spacer()
                    ShareLink(item: Participant.csv(filtered)) { Label("CSV", systemImage: "square.and.arrow.up") }
                }
                Text("\(filtered.count) participant(s)").font(.caption).foregroundColor(.textGray)
                if let toast { Text(toast).font(.caption.bold()).foregroundColor(.okGreen) }

                ForEach(filtered) { p in row(p) }
            }.padding(16)
        }
        .background(Color.pageBg)
        .onAppear {
            users.start(app.db.collection("users").limit(to: 500))
            requests.start(app.db.collection("joinRequests").limit(to: 500))
        }
        .onDisappear { users.stop(); requests.stop() }
        .sheet(item: $detail) { p in ParticipantDetail(p: p, decide: { s in Task { await decide(p, s) } }) }
        .alert(item: $error) { Alert(title: Text($0.title), message: Text($0.body)) }
    }

    private func stat(_ label: String, _ n: Int) -> some View {
        VStack { Text("\(n)").font(.title2.bold()).foregroundColor(.primaryBlue); Text(label).font(.caption2).foregroundColor(.textGray) }
            .frame(maxWidth: .infinity).padding(10).background(Color.white).clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func row(_ p: Participant) -> some View {
        CardBox {
            Text(p.fullName).font(.headline)
            Text("\(p.kind.icon) \(p.kind.label)" + (p.hasAccount ? "" : " · sans compte")).font(.caption.bold()).foregroundColor(.textBlue)
            let contact = [p.email, p.phone].filter { !$0.isEmpty }.joined(separator: "  ·  ")
            if !contact.isEmpty { Text(contact).font(.caption).foregroundColor(.textGray) }
            if !p.level.isEmpty { Text(p.level).font(.caption).foregroundColor(.textGray) }
            if !p.poles.isEmpty { Text("🎨 " + p.poles.joined(separator: " · ")).font(.caption) }
            if p.kind == .pending && p.isRequestDoc {
                HStack {
                    Button("✅ Accepter") { Task { await decide(p, "accepté") } }.buttonStyle(.borderedProminent).tint(.okGreen)
                    Button("⛔ Refuser") { Task { await decide(p, "refusé") } }.buttonStyle(.borderedProminent).tint(.danger)
                }
            }
        }.onTapGesture { detail = p }
    }

    /// Une seule écriture groupée : demande + profil du membre (tout ou rien).
    private func decide(_ p: Participant, _ status: String) async {
        if p.status == status { toast = "Déjà : \(joinStatusLabel(status))"; return }
        guard p.isRequestDoc else { error = ErrorMessage(title: "Impossible", body: "Ce compte n'a pas envoyé de demande d'adhésion."); return }
        if deciding { toast = "Enregistrement en cours…"; return }
        deciding = true; toast = "Enregistrement…"
        defer { deciding = false }
        let batch = app.db.batch()
        batch.updateData(["status": status, "decidedAt": FieldValue.serverTimestamp(), "decidedBy": app.myUid ?? ""], forDocument: p.ref)
        if p.hasAccount && !p.uid.isEmpty {
            batch.updateData(["joinStatus": status], forDocument: app.db.collection("users").document(p.uid))
        }
        do { try await batch.commit(); toast = "\(p.fullName) : \(status) ✔"; detail = nil }
        catch {
            toast = nil
            let code = (error as NSError).code
            error_(ErrorMessage(title: "Décision non enregistrée", body: "\(app.errorText(error))\n\n(code : \(code))"))
        }
    }
    private func error_(_ e: ErrorMessage) { self.error = e }
}

struct ParticipantDetail: View {
    @Environment(\.dismiss) private var dismiss
    let p: Participant
    let decide: (String) -> Void
    var body: some View {
        NavigationStack {
            List {
                Section { Text(p.fullName).font(.headline); Text("\(p.kind.icon) \(p.kind.label)") }
                Section("Contact") { Text(p.email); if !p.phone.isEmpty { Text(p.phone) }; if !p.level.isEmpty { Text(p.level) } }
                if !p.poles.isEmpty { Section("Pôles") { Text(p.poles.joined(separator: "\n")) } }
                if !p.passions.isEmpty { Section("Passions") { Text(p.passions.joined(separator: " · ")) } }
                if !p.motivation.isEmpty { Section("Motivation") { Text(p.motivation) } }
                if p.isRequestDoc {
                    Section("Changer le statut") {
                        ForEach(["nouveau", "contacté", "accepté", "refusé"], id: \.self) { s in
                            Button(s.capitalized + (p.status == s ? "  ✓" : "")) { decide(s) }
                        }
                    }
                }
            }
            .navigationTitle("Participant").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Fermer") { dismiss() } } }
        }
    }
}
