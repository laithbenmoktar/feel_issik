import SwiftUI
import FirebaseFirestore

struct HomeView: View {
    @EnvironmentObject var app: AppState
    @Binding var pendingPole: String?
    @StateObject private var member = LiveDocument()
    @StateObject private var subgroups = LiveCollection()
    @State private var filter = "all"
    @State private var details: Pole?
    @State private var editMember = false
    @State private var editPole: Pole?

    private var overrides: [String: [String: Any]] {
        Dictionary(uniqueKeysWithValues: subgroups.docs.map { ($0.documentID, $0.data()) })
    }
    private func str(_ d: [String: Any]?, _ k: String) -> String? {
        guard let v = d?[k] as? String, !v.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return v
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if app.bureauActive { BureauBanner() }
                hero
                memberCard
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        chip("Tous (\(Poles.all.count))", "all")
                        ForEach(Poles.all) { chip($0.shortName, $0.id) }
                    }
                }
                ForEach(Poles.all.filter { filter == "all" || $0.id == filter }) { poleCard($0) }
            }.padding(16)
        }
        .background(Color.pageBg)
        .onAppear {
            member.start(app.db.collection("config").document("memberOfMonth"))
            subgroups.start(app.db.collection("subgroups"))
            if let p = pendingPole { filter = p; pendingPole = nil }
        }
        .onDisappear { member.stop(); subgroups.stop() }
        .alert(item: Binding(get: { details.map { Wrapper(pole: $0) } }, set: { _ in details = nil })) { w in
            let d = overrides[w.pole.id]
            var msg = str(d, "description") ?? w.pole.description
            if let c = str(d, "chief") { msg += "\n\n👤 Chef de pôle : \(c)" }
            if let s = str(d, "schedule") { msg += "\n🕒 \(s)" }
            msg += "\n\n💡 Project Suggestions : \((d?["projects"] as? NSNumber)?.intValue ?? w.pole.projects)"
            return Alert(title: Text("\(w.pole.icon)  \(w.pole.title)"), message: Text(msg),
                         primaryButton: .default(Text("Rejoindre")) { app.go = .join }, secondaryButton: .cancel(Text("Fermer")))
        }
        .sheet(isPresented: $editMember) { MemberEditor(initial: member.data ?? [:]) }
        .sheet(item: $editPole) { p in PoleEditor(pole: p, initial: overrides[p.id] ?? [:]) }
    }

    private struct Wrapper: Identifiable { let pole: Pole; var id: String { pole.id } }

    private var hero: some View {
        VStack(spacing: 10) {
            ClubLogo(size: 72)
            Text("FEEL ISSIK").font(.largeTitle.bold()).foregroundColor(.white)
            Text("Le club de l'ISSIK Kef : arts, sport et vie étudiante").foregroundColor(.white.opacity(0.9)).multilineTextAlignment(.center)
            HStack {
                Button("Rejoindre") { app.go = .join }.buttonStyle(.borderedProminent).tint(.orange)
                Button("Agenda") { app.go = .events }.buttonStyle(.bordered).tint(.white)
            }
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [.primaryBlue, Color(hex: 0x6366F1)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var memberCard: some View {
        let d = member.data
        return CardBox {
            HStack {
                Text("🏅 Member of the Month").font(.headline).foregroundColor(.textBlue)
                Spacer()
                if app.bureauActive { Button("✏") { editMember = true } }
            }
            HStack(spacing: 12) {
                Base64Image(b64: d?["photo"] as? String).frame(width: 64, height: 64).clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(str(d, "name") ?? "Nour Elhouda Khelifi").font(.headline)
                    if let i = str(d, "info") { Text(i).font(.caption).foregroundColor(.textGray) }
                    if let x = str(d, "distinction") { Text(x).font(.caption).foregroundColor(.orange) }
                }
            }
            if let q = str(d, "quote") { Text("❝ « \(q) »").italic().font(.callout).foregroundColor(.textGray) }
            Button { app.go = .movies } label: { Text("🎬 Movie Suggestion").font(.callout.bold()) }
        }
    }

    private func chip(_ label: String, _ id: String) -> some View {
        Button { filter = id } label: {
            Text(label).font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 7)
                .background(filter == id ? Color.primaryBlue : Color.white)
                .foregroundColor(filter == id ? .white : .textDark)
                .overlay(Capsule().stroke(Color.cardBorder)).clipShape(Capsule())
        }
    }

    private func poleCard(_ p: Pole) -> some View {
        let d = overrides[p.id]
        return CardBox {
            if let cover = d?["cover"] as? String, ImageUtil.decode(cover) != nil {
                Base64Image(b64: cover).frame(height: 120).frame(maxWidth: .infinity).clipped().clipShape(RoundedRectangle(cornerRadius: 12))
            }
            HStack {
                Text("\(p.icon) \(p.title)").font(.headline)
                Spacer()
                if app.bureauActive { Button("✏") { editPole = p } }
            }
            Text(str(d, "description") ?? p.description).font(.callout).foregroundColor(.textGray)
            Text("💡 Project Suggestions (\((d?["projects"] as? NSNumber)?.intValue ?? p.projects))").font(.caption.bold()).foregroundColor(.orange)
            HStack {
                Button("Détails") { details = p }.buttonStyle(.bordered)
                if p.id == "cinema" { Button("🎬 Films") { app.go = .movies }.buttonStyle(.bordered) }
                Button("Rejoindre") { app.go = .join }.buttonStyle(.borderedProminent)
            }
        }
    }
}
