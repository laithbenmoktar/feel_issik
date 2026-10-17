import SwiftUI
import FirebaseFirestore

/// Base de données & accès (bureau) : test d'accès + explorateur simple des documents.
struct DatabaseView: View {
    @EnvironmentObject var app: AppState
    private let collections = ["users", "joinRequests", "team", "events", "news", "movies", "subgroups", "config"]
    @State private var report = ""
    @State private var running = false
    @State private var collection = "users"
    @StateObject private var live = LiveCollection()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PrimaryButton(title: running ? "Test en cours…" : "🩺 Tester l'accès", disabled: running) {
                    running = true
                    Task { report = await app.diagnose(); running = false }
                }
                if !report.isEmpty { CardBox { Text(report).font(.system(.caption, design: .monospaced)) } }
                Text("Règles Firestore : publiez le fichier firestore.rules du projet (Firebase → Firestore → Règles → Publier).")
                    .font(.caption).foregroundColor(.textGray)

                Picker("Collection", selection: $collection) { ForEach(collections, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu)
                ForEach(live.docs, id: \.documentID) { d in
                    CardBox {
                        Text(d.documentID).font(.caption.bold()).foregroundColor(.textBlue)
                        // Les champs Base64 (photos) sont masqués pour rester lisible.
                        Text(d.data().sorted { $0.key < $1.key }.map { "\($0.key): \(summary($0.value))" }.joined(separator: "\n"))
                            .font(.system(.caption2, design: .monospaced))
                    }
                }
            }.padding(16)
        }
        .background(Color.pageBg)
        .onAppear { live.start(app.db.collection(collection).limit(to: 100)) }
        .onChange(of: collection) { c in live.start(app.db.collection(c).limit(to: 100)) }
        .onDisappear { live.stop() }
    }

    private func summary(_ v: Any) -> String {
        let s = "\(v)"
        return s.count > 120 ? "(\(s.count) caractères)" : s
    }
}
