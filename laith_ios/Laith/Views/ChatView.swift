import SwiftUI
import PhotosUI
import FirebaseFirestore

struct ChatView: View {
    @EnvironmentObject var app: AppState
    struct Channel: Identifiable { let id: String, name: String, desc: String }
    static let announce = "annonces"
    private let channels = [
        Channel(id: "general", name: "Général ISSIK", desc: "Le salon principal pour échanger, rigoler et se retrouver"),
        Channel(id: "ecriture", name: "Atelier Écriture & Plume", desc: "Partagez vos textes, poèmes et inspirations"),
        Channel(id: "musique", name: "Atelier Musique", desc: "Instruments, chant et bonnes ondes"),
        Channel(id: "cinema", name: "Cinéma & Planches", desc: "Scénarios, tournages et répétitions"),
        Channel(id: "peinture", name: "Peinture & Toiles", desc: "Couleurs, pinceaux et expositions"),
        Channel(id: "crochet", name: "Crochet & DIY", desc: "Mailles, créations faites-main et DIY"),
        Channel(id: "football", name: "Football Club", desc: "Matchs, entraînements et esprit d'équipe"),
        Channel(id: ChatView.announce, name: "Annonces Officielles", desc: "Les informations officielles du bureau"),
    ]

    @StateObject private var live = LiveCollection()
    @State private var current = "general"
    @State private var memories = false
    @State private var text = ""
    @State private var error: String?
    @State private var item: PhotosPickerItem?

    private var channel: Channel { channels.first { $0.id == current }! }
    private var canPost: Bool { current != Self.announce || app.bureauActive }
    private var messages: [ChatMessage] {
        live.docs.compactMap { ChatMessage(id: $0.documentID, $0.data()) }.sorted { $0.ts < $1.ts }
    }
    private var shown: [ChatMessage] { memories ? messages.filter { $0.image != nil } : messages }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Menu {
                    ForEach(channels) { c in Button("# \(c.name)") { current = c.id } }
                } label: { Label("# \(channel.name)", systemImage: "chevron.down").font(.headline) }
                Spacer()
                Picker("", selection: $memories) { Text("💬 Discussion").tag(false); Text("📷 Memories (\(messages.filter { $0.image != nil }.count))").tag(true) }
                    .pickerStyle(.segmented).frame(maxWidth: 230)
            }.padding(10).background(Color.white)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        if !memories { Text("Bienvenue sur #\(channel.name)\n\(channel.desc)").font(.caption).foregroundColor(.textGray).padding(.vertical, 8) }
                        ForEach(shown) { m in bubble(m).id(m.id) }
                    }.padding(12)
                }
                .onChange(of: shown.count) { _ in if let last = shown.last { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
            if let error { Text(error).font(.caption).foregroundColor(.danger).padding(.horizontal) }
            HStack(spacing: 8) {
                PhotosPicker(selection: $item, matching: .images) { Image(systemName: "photo").font(.title3) }.disabled(!canPost)
                TextField(canPost ? "Écrire dans #\(channel.name)…" : "Salon réservé au bureau", text: $text)
                    .padding(10).background(Color.white).clipShape(Capsule()).overlay(Capsule().stroke(Color.cardBorder)).disabled(!canPost)
                    .submitLabel(.send).onSubmit { send(text: text, image: nil) }
                Button { send(text: text, image: nil) } label: { Image(systemName: "paperplane.fill").font(.title3) }
                    .disabled(!canPost || text.trimmingCharacters(in: .whitespaces).isEmpty)
            }.padding(10).background(Color.pageBg)
        }
        .background(Color.pageBg)
        .onAppear { listen() }
        .onDisappear { live.stop() }
        .onChange(of: current) { _ in listen() }
        .onChange(of: item) { newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self), let ui = UIImage(data: data),
                   let b64 = ImageUtil.encode(ui, maxSide: 800) { send(text: "", image: b64) }
                else { error = "Image illisible, essayez une autre photo" }
                item = nil
            }
        }
    }

    private func listen() {
        live.start(app.db.collection("channels").document(current).collection("messages")
            .order(by: "ts", descending: true).limit(to: 100))
    }

    private func bubble(_ m: ChatMessage) -> some View {
        let mine = m.uid == app.myUid
        return VStack(alignment: mine ? .trailing : .leading, spacing: 2) {
            Text(m.author).font(.caption2).foregroundColor(.textGray)
            VStack(alignment: .leading, spacing: 6) {
                if let ui = ImageUtil.decode(m.image) { Image(uiImage: ui).resizable().scaledToFit().frame(maxWidth: 220).clipShape(RoundedRectangle(cornerRadius: 10)) }
                if !m.text.isEmpty { Text(m.text).foregroundColor(mine ? .white : .textDark) }
            }
            .padding(10).background(mine ? Color.primaryBlue : Color.white).clipShape(RoundedRectangle(cornerRadius: 14))
            .contextMenu {
                if mine || app.bureauActive {
                    Button("Supprimer", role: .destructive) {
                        app.db.collection("channels").document(current).collection("messages").document(m.id).delete { err in
                            if let err { error = app.errorText(err) }
                        }
                    }
                }
            }
        }.frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
    }

    private func send(text: String, image: String?) {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard canPost, !(t.isEmpty && image == nil), let uid = app.myUid else { return }
        var data: [String: Any] = ["uid": uid, "author": app.displayName(), "text": t, "ts": Int64(Date().timeIntervalSince1970 * 1000)]
        if let image { data["image"] = image }
        app.db.collection("channels").document(current).collection("messages").addDocument(data: data) { err in
            if let err { error = app.errorText(err) } else { error = nil }
        }
        if image == nil { self.text = "" }
    }
}
